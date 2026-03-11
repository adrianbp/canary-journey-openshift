#!/usr/bin/env bash
set -euo pipefail

PLAN_FILE="${1:-}"

if [[ -z "$PLAN_FILE" ]]; then
  echo "Usage: $0 <plan-file>"
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

require_cmd awk
require_cmd tr

required_keys=(appName stableDeployment canaryDeployment stableService canaryService routeName namespace)
for key in "${required_keys[@]}"; do
  value="$(awk -v key="$key" '$1==key":" {print $2; exit}' "$PLAN_FILE" | tr -d '"')"
  if [[ -z "$value" ]]; then
    echo "Missing required spec key: $key"
    exit 1
  fi
done

step_count="$(awk '$1=="-" && $2=="name:" {count++} END {print count+0}' "$PLAN_FILE")"
if [[ "$step_count" -eq 0 ]]; then
  echo "Plan must contain at least one step"
  exit 1
fi

awk '
  $1=="-" && $2=="name:" {step=$3; gsub(/"/,"",step)}
  $1=="canaryWeight:" {
    cw=$2+0
    if (cw < 0 || cw > 100) {
      print "Invalid canaryWeight in step " step ": " cw
      exit 1
    }
  }
  $1=="stableWeight:" {
    sw=$2+0
    if (sw < 0 || sw > 100) {
      print "Invalid stableWeight in step " step ": " sw
      exit 1
    }
    if ((cw + sw) != 100) {
      print "Weights must sum 100 in step " step ": canary=" cw " stable=" sw
      exit 1
    }
  }
' "$PLAN_FILE"

echo "Plan validation passed: $PLAN_FILE"
