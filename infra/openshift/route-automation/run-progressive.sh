#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-}"
ENVIRONMENT="${2:-}"
WAIT_SECONDS="${3:-120}"
shift 3 || true
STEPS=("$@")

if [[ -z "$APP_NAME" || -z "$ENVIRONMENT" ]]; then
  echo "Usage: $0 <app-name> <dev|stg|prod> [wait-seconds] <steps...>"
  echo "Example: $0 payments-api dev 120 step-10 step-25 step-50 promote-primary"
  exit 1
fi

if [[ ${#STEPS[@]} -eq 0 ]]; then
  echo "At least one step is required"
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
PLAN_FILE="$DIR/plans/${APP_NAME}/${ENVIRONMENT}/rollout-steps.yaml"

"$DIR/validate-plan.sh" "$PLAN_FILE"
"$DIR/progressive-rollout-dynatrace.sh" "$PLAN_FILE" "$WAIT_SECONDS" "${STEPS[@]}"
