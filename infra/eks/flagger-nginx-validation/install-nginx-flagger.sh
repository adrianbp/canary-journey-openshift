#!/usr/bin/env bash
set -euo pipefail

INGRESS_NS="${INGRESS_NS:-ingress-nginx}"
TEST_NS="${TEST_NS:-test}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1"; exit 1; }
}

require_cmd kubectl
require_cmd helm

kubectl get nodes >/dev/null

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null
helm repo add flagger https://flagger.app >/dev/null
helm repo update >/dev/null

kubectl create namespace "$INGRESS_NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace "$TEST_NS" --dry-run=client -o yaml | kubectl apply -f -

echo "Installing ingress-nginx controller..."
helm upgrade -i ingress-nginx ingress-nginx/ingress-nginx \
  -n "$INGRESS_NS" \
  --set controller.metrics.enabled=true \
  --set controller.service.type=LoadBalancer \
  --set controller.ingressClassResource.default=true

kubectl -n "$INGRESS_NS" rollout status deployment/ingress-nginx-controller --timeout=10m

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
kubectl -n "$INGRESS_NS" get deploy,svc
kubectl -n "$TEST_NS" get deploy,svc

lb_addr="$(kubectl -n "$INGRESS_NS" get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
if [[ -z "$lb_addr" ]]; then
  lb_addr="$(kubectl -n "$INGRESS_NS" get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
fi

echo "Ingress external address: ${lb_addr:-<pending>}"
