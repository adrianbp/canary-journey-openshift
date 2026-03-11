#!/usr/bin/env bash
set -euo pipefail

PLAN_FILE="${1:-}"

if [[ -z "$PLAN_FILE" ]]; then
  echo "Usage: $0 <plan-file>"
  echo "Example: $0 rollout-steps.yaml"
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/apply-step.sh" "$PLAN_FILE" "step-00-preview"

echo "Rollback complete: traffic back to stable, canary at preview capacity."
