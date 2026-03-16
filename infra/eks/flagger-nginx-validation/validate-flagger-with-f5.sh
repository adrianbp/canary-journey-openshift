#!/usr/bin/env bash
set -euo pipefail

TEST_NS="${TEST_NS:-test}"
INGRESS_NS="${INGRESS_NS:-nginx-ingress}"
CANARY_NAME="${CANARY_NAME:-podinfo}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1"; exit 1; }
}

require_cmd kubectl

echo "=== Canary CR status ==="
kubectl -n "$TEST_NS" get canary "$CANARY_NAME" -o wide || true

echo "=== Canary describe ==="
kubectl -n "$TEST_NS" describe canary "$CANARY_NAME" || true

echo "=== Ingress resources created by Flagger ==="
kubectl -n "$TEST_NS" get ingress -o yaml | sed -n '1,260p' || true

echo "=== Looking for ingress-nginx canary annotations (compatibility signal) ==="
kubectl -n "$TEST_NS" get ingress -o yaml | rg -n "nginx.ingress.kubernetes.io/canary|nginx.org/" || true

echo "=== Flagger logs (tail) ==="
kubectl -n "$INGRESS_NS" logs deploy/flagger --tail=200 || true

echo "=== F5 controller logs (tail) ==="
for dep in $(kubectl -n "$INGRESS_NS" get deploy -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | rg "nginx-ingress|f5|nginx"); do
  kubectl -n "$INGRESS_NS" logs "deploy/$dep" --tail=120 || true
done

echo "Validation completed."
