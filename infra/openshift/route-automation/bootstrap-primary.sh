#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-}"
APP_NAME="${2:-}"
MIN_CANARY_REPLICAS="${3:-1}"

if [[ -z "$NAMESPACE" || -z "$APP_NAME" ]]; then
  echo "Usage: $0 <namespace> <app-name> [min-canary-replicas]"
  echo "Example: $0 team-a payments-api 1"
  exit 1
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

require_cmd oc
require_cmd jq

PRIMARY_NAME="${APP_NAME}-primary"
CURRENT_REPLICAS="$(oc -n "$NAMESPACE" get deployment "$APP_NAME" -o jsonpath='{.spec.replicas}')"

if [[ -z "$CURRENT_REPLICAS" ]]; then
  CURRENT_REPLICAS=1
fi

if ! oc -n "$NAMESPACE" get deployment "$APP_NAME" >/dev/null 2>&1; then
  echo "Deployment not found: ${APP_NAME}"
  exit 1
fi

if ! oc -n "$NAMESPACE" get service "$APP_NAME" >/dev/null 2>&1; then
  echo "Service not found: ${APP_NAME}"
  exit 1
fi

echo "[1/5] Creating/Updating deployment ${PRIMARY_NAME} from ${APP_NAME}"
oc -n "$NAMESPACE" get deployment "$APP_NAME" -o json \
  | jq --arg primary "$PRIMARY_NAME" '
      .metadata.name = $primary
      | del(.metadata.uid, .metadata.resourceVersion, .metadata.generation, .metadata.creationTimestamp, .metadata.managedFields, .metadata.annotations["deployment.kubernetes.io/revision"], .status)
      | .spec.selector.matchLabels.app = $primary
      | .spec.template.metadata.labels.app = $primary
    ' \
  | oc apply -f -

echo "[2/5] Creating/Updating service ${PRIMARY_NAME} from ${APP_NAME}"
oc -n "$NAMESPACE" get service "$APP_NAME" -o json \
  | jq --arg primary "$PRIMARY_NAME" '
      .metadata.name = $primary
      | del(.metadata.uid, .metadata.resourceVersion, .metadata.creationTimestamp, .metadata.managedFields, .spec.clusterIP, .spec.clusterIPs, .spec.ipFamilies, .spec.ipFamilyPolicy, .spec.internalTrafficPolicy, .status)
      | .spec.selector.app = $primary
    ' \
  | oc apply -f -

echo "[3/5] Preserving stable capacity and reducing canary baseline"
oc -n "$NAMESPACE" scale deployment "$PRIMARY_NAME" --replicas="$CURRENT_REPLICAS"
oc -n "$NAMESPACE" rollout status deployment "$PRIMARY_NAME" --timeout=300s

oc -n "$NAMESPACE" scale deployment "$APP_NAME" --replicas="$MIN_CANARY_REPLICAS"
oc -n "$NAMESPACE" rollout status deployment "$APP_NAME" --timeout=300s

if oc -n "$NAMESPACE" get route "$APP_NAME" >/dev/null 2>&1; then
  echo "[4/5] Patching route ${APP_NAME} to primary=100, canary=0"
  oc -n "$NAMESPACE" patch route "$APP_NAME" --type=merge -p "$(cat <<JSON
{
  \"spec\": {
    \"to\": {
      \"kind\": \"Service\",
      \"name\": \"${PRIMARY_NAME}\",
      \"weight\": 100
    },
    \"alternateBackends\": [
      {
        \"kind\": \"Service\",
        \"name\": \"${APP_NAME}\",
        \"weight\": 0
      }
    ]
  }
}
JSON
)"
else
  echo "[4/5] Route ${APP_NAME} not found. Skipping route patch."
fi

echo "[5/5] Summary"
echo "Primary deployment/service: ${PRIMARY_NAME}"
echo "Canary deployment/service: ${APP_NAME}"
echo "Stable replicas preserved: ${CURRENT_REPLICAS}"
echo "Canary baseline replicas: ${MIN_CANARY_REPLICAS}"
echo "You can now use rollout-steps.yaml with stable=*primary and canary=*app."
