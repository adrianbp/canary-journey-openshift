#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-}"
APP_NAME="${2:-}"
CANARY_BASELINE_REPLICAS="${3:-0}"

if [[ -z "$NAMESPACE" || -z "$APP_NAME" ]]; then
  echo "Usage: $0 <namespace> <app-name> [canary-baseline-replicas]"
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

if ! oc -n "$NAMESPACE" get deployment "$APP_NAME" >/dev/null 2>&1; then
  echo "Canary deployment not found: ${APP_NAME}"
  exit 1
fi

if ! oc -n "$NAMESPACE" get deployment "$PRIMARY_NAME" >/dev/null 2>&1; then
  echo "Primary deployment not found: ${PRIMARY_NAME}"
  exit 1
fi

if ! oc -n "$NAMESPACE" get service "$PRIMARY_NAME" >/dev/null 2>&1; then
  echo "Primary service not found: ${PRIMARY_NAME}"
  exit 1
fi

PRIMARY_REPLICAS="$(oc -n "$NAMESPACE" get deployment "$PRIMARY_NAME" -o jsonpath='{.spec.replicas}')"
if [[ -z "$PRIMARY_REPLICAS" || "$PRIMARY_REPLICAS" == "0" ]]; then
  PRIMARY_REPLICAS=1
fi

echo "[1/5] Syncing canary spec from ${APP_NAME} to ${PRIMARY_NAME}"
oc -n "$NAMESPACE" get deployment "$APP_NAME" -o json \
  | jq --arg primary "$PRIMARY_NAME" --argjson replicas "$PRIMARY_REPLICAS" '
      .metadata.name = $primary
      | del(.metadata.uid, .metadata.resourceVersion, .metadata.generation, .metadata.creationTimestamp, .metadata.managedFields, .metadata.annotations["deployment.kubernetes.io/revision"], .status)
      | .spec.selector.matchLabels.app = $primary
      | .spec.template.metadata.labels.app = $primary
      | .spec.replicas = $replicas
    ' \
  | oc apply -f -

echo "[2/5] Waiting primary rollout"
oc -n "$NAMESPACE" rollout status deployment "$PRIMARY_NAME" --timeout=300s

if oc -n "$NAMESPACE" get route "$APP_NAME" >/dev/null 2>&1; then
  echo "[3/5] Routing 100% traffic to ${PRIMARY_NAME}"
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
  echo "[3/5] Route ${APP_NAME} not found. Skipping route patch."
fi

echo "[4/5] Scaling canary ${APP_NAME} to baseline replicas=${CANARY_BASELINE_REPLICAS}"
oc -n "$NAMESPACE" scale deployment "$APP_NAME" --replicas="$CANARY_BASELINE_REPLICAS"
oc -n "$NAMESPACE" rollout status deployment "$APP_NAME" --timeout=300s

echo "[5/5] Promotion complete"
echo "Stable now: ${PRIMARY_NAME} (synced from canary)"
echo "Primary replicas preserved: ${PRIMARY_REPLICAS}"
echo "Canary baseline replicas: ${CANARY_BASELINE_REPLICAS}"
