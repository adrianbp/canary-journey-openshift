#!/usr/bin/env bash
set -euo pipefail

PLAN_FILE="${1:-}"
WAIT_SECONDS="${2:-120}"
shift 2 || true
STEPS=("$@")
PROMOTE_PRIMARY_BASELINE_REPLICAS="${PROMOTE_PRIMARY_BASELINE_REPLICAS:-0}"

if [[ -z "$PLAN_FILE" ]]; then
  echo "Usage: $0 <plan-file> <wait-seconds> <step-1> [step-2 ...]"
  echo "Example: $0 rollout-steps.yaml 120 step-10 step-25 step-50 step-100-promote"
  exit 1
fi

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "Plan file not found: $PLAN_FILE"
  exit 1
fi

if [[ ${#STEPS[@]} -eq 0 ]]; then
  echo "No steps provided"
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
NAMESPACE="$(awk '$1=="namespace:" {print $2; exit}' "$PLAN_FILE" | tr -d '\"')"
APP_NAME="$(awk '$1=="appName:" {print $2; exit}' "$PLAN_FILE" | tr -d '\"')"

if [[ -z "$NAMESPACE" || -z "$APP_NAME" ]]; then
  echo "Could not parse namespace/appName from plan file"
  exit 1
fi

for step in "${STEPS[@]}"; do
  echo "=== Evaluating Dynatrace gate before ${step} ==="
  if ! "$DIR/check-metrics-dynatrace.sh"; then
    echo "Dynatrace gate failed before step ${step}. Triggering rollback."
    "$DIR/rollback.sh" "$PLAN_FILE"
    exit 1
  fi

  echo "=== Applying rollout step ${step} ==="
  if [[ "$step" == "promote-primary" ]]; then
    if ! "$DIR/promote-to-primary.sh" "$NAMESPACE" "$APP_NAME" "$PROMOTE_PRIMARY_BASELINE_REPLICAS"; then
      echo "Promotion to primary failed. Triggering rollback."
      "$DIR/rollback.sh" "$PLAN_FILE"
      exit 1
    fi
  elif ! "$DIR/apply-step.sh" "$PLAN_FILE" "$step"; then
    echo "Step execution failed: ${step}. Triggering rollback."
    "$DIR/rollback.sh" "$PLAN_FILE"
    exit 1
  fi

  echo "=== Waiting ${WAIT_SECONDS}s for stabilization ==="
  sleep "$WAIT_SECONDS"

done

echo "Progressive rollout completed successfully."
