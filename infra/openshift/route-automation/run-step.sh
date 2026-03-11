#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-}"
ENVIRONMENT="${2:-}"
STEP_NAME="${3:-}"

if [[ -z "$APP_NAME" || -z "$ENVIRONMENT" || -z "$STEP_NAME" ]]; then
  echo "Usage: $0 <app-name> <dev|stg|prod> <step-name>"
  echo "Example: $0 payments-api dev step-25"
  exit 1
fi

PLAN_FILE="$(cd "$(dirname "$0")" && pwd)/plans/${APP_NAME}/${ENVIRONMENT}/rollout-steps.yaml"
DIR="$(cd "$(dirname "$0")" && pwd)"

"$DIR/validate-plan.sh" "$PLAN_FILE"
"$DIR/apply-step.sh" "$PLAN_FILE" "$STEP_NAME"
