#!/usr/bin/env bash
set -euo pipefail

INGRESS_NS="${INGRESS_NS:-nginx-ingress}"
TEST_NS="${TEST_NS:-test}"
F5_RELEASE="${F5_RELEASE:-nginx-ingress-f5}"
F5_CHART_VERSION="${F5_CHART_VERSION:-2.4.3}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1"; exit 1; }
}

require_cmd kubectl
require_cmd helm

kubectl get nodes >/dev/null

helm repo add flagger https://flagger.app >/dev/null
helm repo update >/dev/null

kubectl create namespace "$INGRESS_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace "$TEST_NS" --dry-run=client -o yaml | kubectl apply -f -

echo "Installing NGINX Ingress Controller (F5 OSS) from OCI chart..."
helm upgrade -i "$F5_RELEASE" oci://ghcr.io/nginx/charts/nginx-ingress \
  --version "$F5_CHART_VERSION" \
  -n "$INGRESS_NS" \
  --set controller.service.type=LoadBalancer

f5_controller_deploy="$(
  kubectl -n "$INGRESS_NS" get deploy \
    -l "app.kubernetes.io/instance=${F5_RELEASE},app.kubernetes.io/name=nginx-ingress" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
)"

if [[ -z "$f5_controller_deploy" ]]; then
  echo "Unable to find F5 controller deployment for release ${F5_RELEASE} in namespace ${INGRESS_NS}"
  kubectl -n "$INGRESS_NS" get deploy
  exit 1
fi

kubectl -n "$INGRESS_NS" rollout status "deployment/${f5_controller_deploy}" --timeout=10m

echo "Installing Flagger with Prometheus..."
helm upgrade -i flagger flagger/flagger \
  -n "$INGRESS_NS" \
  --set prometheus.install=true \
  --set meshProvider=nginx \
  --set metricsServer=http://flagger-prometheus.$INGRESS_NS:9090

kubectl -n "$INGRESS_NS" rollout status deployment/flagger --timeout=10m
kubectl -n "$INGRESS_NS" rollout status deployment/flagger-prometheus --timeout=10m

echo "Installing Flagger loadtester..."
helm upgrade -i flagger-loadtester flagger/loadtester -n "$TEST_NS"
kubectl -n "$TEST_NS" rollout status deployment/flagger-loadtester --timeout=10m

echo "Installed components:"
kubectl -n "$INGRESS_NS" get deploy,svc,ingressclass
kubectl -n "$TEST_NS" get deploy,svc

echo "IngressClass details:"
kubectl get ingressclass -o yaml | sed -n '1,220p'

lb_addr="$(kubectl -n "$INGRESS_NS" get svc -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
if [[ -z "$lb_addr" ]]; then
  lb_addr="$(kubectl -n "$INGRESS_NS" get svc -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
fi

echo "F5 ingress external address: ${lb_addr:-<pending>}"
