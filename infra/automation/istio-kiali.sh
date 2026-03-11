#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
ENVIRONMENT="${2:-dev}"

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ISTIO_VALUES_DIR="$ROOT_DIR/infra/helm-values/istio"
KIALI_VALUES_DIR="$ROOT_DIR/infra/helm-values/kiali"

if [[ -z "$ACTION" ]]; then
  echo "Usage: $0 <install|status|uninstall> [dev|stg|prod]"
  exit 1
fi

if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "stg" && "$ENVIRONMENT" != "prod" ]]; then
  echo "Invalid environment: $ENVIRONMENT"
  exit 1
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

require_cmd kubectl
require_cmd helm

install() {
  kubectl create ns istio-system --dry-run=client -o yaml | kubectl apply -f -

  helm repo add istio https://istio-release.storage.googleapis.com/charts >/dev/null
  helm repo add kiali https://kiali.org/helm-charts >/dev/null
  helm repo update >/dev/null

  helm upgrade --install istio-base istio/base \
    -n istio-system \
    -f "$ISTIO_VALUES_DIR/common/values-base.yaml"

  helm upgrade --install istiod istio/istiod \
    -n istio-system \
    -f "$ISTIO_VALUES_DIR/common/values-istiod.yaml" \
    -f "$ISTIO_VALUES_DIR/$ENVIRONMENT/values-istiod.yaml"

  helm upgrade --install kiali-server kiali/kiali-server \
    -n istio-system \
    -f "$KIALI_VALUES_DIR/common/values.yaml" \
    -f "$KIALI_VALUES_DIR/$ENVIRONMENT/values.yaml"

  echo "Istio + Kiali installed for environment: $ENVIRONMENT"
}

status() {
  echo "=== Helm Releases ==="
  helm list -n istio-system || true
  echo
  echo "=== Pods (istio-system) ==="
  kubectl get pods -n istio-system || true
}

uninstall() {
  helm uninstall kiali-server -n istio-system || true
  helm uninstall istiod -n istio-system || true
  helm uninstall istio-base -n istio-system || true
  echo "Istio + Kiali releases removed (namespace kept)."
}

case "$ACTION" in
  install)
    install
    ;;
  status)
    status
    ;;
  uninstall)
    uninstall
    ;;
  *)
    echo "Unknown action: $ACTION"
    echo "Usage: $0 <install|status|uninstall> [dev|stg|prod]"
    exit 1
    ;;
esac
