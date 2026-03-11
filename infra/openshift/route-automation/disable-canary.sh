#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-}"
APP_NAME="${2:-}"
DELETE_PRIMARY="${3:-false}"
SHIFT_STEP="${4:-25}"
WAIT_SECONDS="${5:-20}"

if [[ -z "$NAMESPACE" || -z "$APP_NAME" ]]; then
  echo "Usage: $0 <namespace> <app-name> [delete-primary:true|false] [shift-step] [wait-seconds]"
  echo "Example: $0 team-a payments-api true 25 20"
  exit 1
fi

if [[ "$DELETE_PRIMARY" != "true" && "$DELETE_PRIMARY" != "false" ]]; then
  echo "delete-primary must be true or false"
  exit 1
fi

if ! [[ "$SHIFT_STEP" =~ ^[0-9]+$ ]] || [[ "$SHIFT_STEP" -le 0 ]] || [[ "$SHIFT_STEP" -gt 100 ]]; then
  echo "shift-step must be an integer between 1 and 100"
  exit 1
fi

if ! [[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]] || [[ "$WAIT_SECONDS" -lt 0 ]]; then
  echo "wait-seconds must be a non-negative integer"
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
  echo "Deployment not found: ${APP_NAME}"
  exit 1
fi

if ! oc -n "$NAMESPACE" get service "$APP_NAME" >/dev/null 2>&1; then
  echo "Service not found: ${APP_NAME}"
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

TARGET_REPLICAS="$(oc -n "$NAMESPACE" get deployment "$PRIMARY_NAME" -o jsonpath='{.spec.replicas}')"
if [[ -z "$TARGET_REPLICAS" || "$TARGET_REPLICAS" == "0" ]]; then
  TARGET_REPLICAS=1
fi

echo "[1/5] Syncing ${PRIMARY_NAME} spec to ${APP_NAME} and preserving app selectors/labels"
oc -n "$NAMESPACE" get deployment "$PRIMARY_NAME" -o json \
  | jq --arg app "$APP_NAME" --argjson replicas "$TARGET_REPLICAS" '
      .metadata.name = $app
      | del(.metadata.uid, .metadata.resourceVersion, .metadata.generation, .metadata.creationTimestamp, .metadata.managedFields, .metadata.annotations["deployment.kubernetes.io/revision"], .status)
      | .spec.selector.matchLabels.app = $app
      | .spec.template.metadata.labels.app = $app
      | .spec.replicas = $replicas
    ' \
  | oc apply -f -

echo "[2/5] Waiting ${APP_NAME} rollout with replicas=${TARGET_REPLICAS}"
oc -n "$NAMESPACE" rollout status deployment "$APP_NAME" --timeout=300s

if oc -n "$NAMESPACE" get route "$APP_NAME" >/dev/null 2>&1; then
  echo "[3/5] Gradually shifting traffic from ${PRIMARY_NAME} to ${APP_NAME}"

  app_weight=0
  while [[ "$app_weight" -lt 100 ]]; do
    app_weight=$((app_weight + SHIFT_STEP))
    if [[ "$app_weight" -gt 100 ]]; then
      app_weight=100
    fi
    primary_weight=$((100 - app_weight))
    echo " - route weights: ${PRIMARY_NAME}=${primary_weight}% ${APP_NAME}=${app_weight}%"
    oc -n "$NAMESPACE" patch route "$APP_NAME" --type=merge -p "$(cat <<JSON
{
  \"spec\": {
    \"to\": {
      \"kind\": \"Service\",
      \"name\": \"${PRIMARY_NAME}\",
      \"weight\": ${primary_weight}
    },
    \"alternateBackends\": [
      {
        \"kind\": \"Service\",
        \"name\": \"${APP_NAME}\",
        \"weight\": ${app_weight}
      }
    ]
  }
}
JSON
)"
    if [[ "$app_weight" -lt 100 && "$WAIT_SECONDS" -gt 0 ]]; then
      sleep "$WAIT_SECONDS"
    fi
  done

  echo " - finalizing route with 100% traffic to ${APP_NAME}"
  oc -n "$NAMESPACE" patch route "$APP_NAME" --type=merge -p "$(cat <<JSON
{
  \"spec\": {
    \"to\": {
      \"kind\": \"Service\",
      \"name\": \"${APP_NAME}\",
      \"weight\": 100
    },
    \"alternateBackends\": []
  }
}
JSON
)"
else
  echo "[3/5] Route ${APP_NAME} not found. Skipping traffic shift."
fi

if [[ "$DELETE_PRIMARY" == "true" ]]; then
  echo "[4/5] Removing primary resources ${PRIMARY_NAME}"
  oc -n "$NAMESPACE" delete deployment "$PRIMARY_NAME" --ignore-not-found
  oc -n "$NAMESPACE" delete service "$PRIMARY_NAME" --ignore-not-found
else
  echo "[4/5] Keeping primary resources ${PRIMARY_NAME} (scaled to 0)"
  oc -n "$NAMESPACE" scale deployment "$PRIMARY_NAME" --replicas=0 >/dev/null 2>&1 || true
fi

echo "[5/5] Summary"
echo "Active deployment/service: ${APP_NAME}"
echo "Target replicas applied: ${TARGET_REPLICAS}"
echo "Traffic shift step: ${SHIFT_STEP}%"
echo "Primary removed: ${DELETE_PRIMARY}"
