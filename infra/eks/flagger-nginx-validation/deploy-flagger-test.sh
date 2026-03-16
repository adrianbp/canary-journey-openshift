#!/usr/bin/env bash
set -euo pipefail

TEST_NS="${TEST_NS:-test}"
INGRESS_CLASS="${INGRESS_CLASS:-nginx}"
INGRESS_NS="${INGRESS_NS:-nginx-ingress}"
APP_HOST="${APP_HOST:-podinfo.localtest.me}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1"; exit 1; }
}

require_cmd kubectl

kubectl create namespace "$TEST_NS" --dry-run=client -o yaml | kubectl apply -f -

echo "Deploying podinfo baseline..."
kubectl apply -k github.com/stefanprodan/podinfo/kustomize -n "$TEST_NS"

cat <<YAML | kubectl apply -n "$TEST_NS" -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: podinfo
spec:
  ingressClassName: ${INGRESS_CLASS}
  rules:
    - host: ${APP_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: podinfo
                port:
                  number: 9898
YAML

cat <<YAML | kubectl apply -n "$TEST_NS" -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: podinfo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
---
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
spec:
  provider: nginx
  ingressRef:
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    name: podinfo
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  progressDeadlineSeconds: 300
  service:
    port: 9898
    targetPort: 9898
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99
        interval: 1m
      - name: request-duration
        thresholdRange:
          max: 500
        interval: 1m
    webhooks:
      - name: load-test
        url: http://flagger-loadtester.${TEST_NS}/
        timeout: 5s
        metadata:
          cmd: "hey -z 1m -q 10 -c 2 -host ${APP_HOST} http://nginx-ingress-f5-controller.${INGRESS_NS}/"
YAML

echo "Waiting for baseline deployment..."
kubectl -n "$TEST_NS" rollout status deployment/podinfo --timeout=10m

echo "Resources status:"
kubectl -n "$TEST_NS" get deploy,svc,ingress,canary,hpa

echo "Waiting canary to reach Initialized phase..."
for i in {1..40}; do
  phase="$(kubectl -n "$TEST_NS" get canary podinfo -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  if [[ "$phase" == "Initialized" || "$phase" == "Succeeded" ]]; then
    echo "Canary phase is ${phase}"
    break
  fi
  echo "Current canary phase: ${phase:-<empty>} (attempt ${i}/40)"
  sleep 15
done

echo "Trigger canary by updating image..."
kubectl -n "$TEST_NS" set image deployment/podinfo podinfod=ghcr.io/stefanprodan/podinfo:6.5.4

echo "Watching canary events (Ctrl+C to stop):"
kubectl -n "$TEST_NS" describe canary podinfo
