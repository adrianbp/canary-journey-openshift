#!/usr/bin/env bash
set -euo pipefail

PLAN_FILE="${1:-}"
STEP_NAME="${2:-}"

if [[ -z "$PLAN_FILE" || -z "$STEP_NAME" ]]; then
  echo "Usage: $0 <plan-file> <step-name>"
  echo "Example: $0 rollout-steps.yaml step-25"
  exit 1
fi

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "Plan file not found: $PLAN_FILE"
  exit 1
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

require_cmd oc
require_cmd awk
require_cmd tr

extract_top_level() {
  local key="$1"
  awk -v key="$key" '
    $1 == key":" {print $2; exit}
  ' "$PLAN_FILE" | tr -d '"'
}

NAMESPACE="$(extract_top_level namespace)"
ROUTE_NAME="$(extract_top_level routeName)"
STABLE_SERVICE="$(extract_top_level stableService)"
CANARY_SERVICE="$(extract_top_level canaryService)"
STABLE_DEPLOYMENT="$(extract_top_level stableDeployment)"
CANARY_DEPLOYMENT="$(extract_top_level canaryDeployment)"
MIN_CANARY_REPLICAS="$(extract_top_level minCanaryReplicas)"
SAFETY_EXTRA_REPLICAS="$(extract_top_level safetyExtraReplicas)"

if [[ -z "$NAMESPACE" || -z "$ROUTE_NAME" || -z "$STABLE_SERVICE" || -z "$CANARY_SERVICE" || -z "$STABLE_DEPLOYMENT" || -z "$CANARY_DEPLOYMENT" ]]; then
  echo "Could not parse required spec fields from plan file"
  exit 1
fi

if [[ -z "$MIN_CANARY_REPLICAS" ]]; then
  MIN_CANARY_REPLICAS=1
fi
if [[ -z "$SAFETY_EXTRA_REPLICAS" ]]; then
  SAFETY_EXTRA_REPLICAS=0
fi

read -r CANARY_WEIGHT STABLE_WEIGHT CANARY_REPLICAS_RAW <<<"$(awk -v step="$STEP_NAME" '
  function clean(v){gsub(/"/,"",v); return v}
  $1=="-" && $2=="name:" {
    current=clean($3)
    in_step=(current==step)
  }
  in_step && $1=="canaryWeight:" {cw=$2}
  in_step && $1=="stableWeight:" {sw=$2}
  in_step && $1=="canaryReplicas:" {cr=$2}
  END {
    if (cw=="" || sw=="") exit 1
    print cw, sw, cr
  }
' "$PLAN_FILE")"

if [[ -z "$CANARY_WEIGHT" || -z "$STABLE_WEIGHT" ]]; then
  echo "Step not found or incomplete: $STEP_NAME"
  exit 1
fi

if [[ -z "$CANARY_REPLICAS_RAW" || "$CANARY_REPLICAS_RAW" == "auto" ]]; then
  STABLE_REPLICAS="$(oc -n "$NAMESPACE" get deployment "$STABLE_DEPLOYMENT" -o jsonpath='{.spec.replicas}')"
  if [[ -z "$STABLE_REPLICAS" ]]; then
    STABLE_REPLICAS=1
  fi

  CANARY_REPLICAS="$(awk -v stable="$STABLE_REPLICAS" -v weight="$CANARY_WEIGHT" -v min="$MIN_CANARY_REPLICAS" -v extra="$SAFETY_EXTRA_REPLICAS" '
    function ceil(x){ return (x == int(x)) ? x : int(x) + 1 }
    BEGIN{
      calc = ceil((stable * weight) / 100.0) + extra
      if (calc < min) calc = min
      if (weight == 0 && calc > min) calc = min
      print calc
    }')"
else
  CANARY_REPLICAS="$CANARY_REPLICAS_RAW"
fi

echo "[1/3] Scaling canary deployment ${CANARY_DEPLOYMENT} to ${CANARY_REPLICAS} replicas in namespace ${NAMESPACE}"
oc -n "$NAMESPACE" scale deployment "$CANARY_DEPLOYMENT" --replicas="$CANARY_REPLICAS"

echo "[2/3] Waiting for canary deployment rollout"
oc -n "$NAMESPACE" rollout status deployment "$CANARY_DEPLOYMENT" --timeout=300s

echo "[3/3] Updating Route ${ROUTE_NAME} weights stable=${STABLE_WEIGHT}% canary=${CANARY_WEIGHT}%"
oc -n "$NAMESPACE" patch route "$ROUTE_NAME" --type=merge -p "$(cat <<JSON
{
  \"spec\": {
    \"to\": {
      \"kind\": \"Service\",
      \"name\": \"${STABLE_SERVICE}\",
      \"weight\": ${STABLE_WEIGHT}
    },
    \"alternateBackends\": [
      {
        \"kind\": \"Service\",
        \"name\": \"${CANARY_SERVICE}\",
        \"weight\": ${CANARY_WEIGHT}
      }
    ]
  }
}
JSON
)"

echo "Step applied successfully: ${STEP_NAME}"
