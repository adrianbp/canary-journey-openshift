#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-}"
NAME="${2:-}"
TIMEOUT_SECONDS="${3:-900}"
POLL_SECONDS="${4:-10}"

if [[ -z "$NAMESPACE" || -z "$NAME" ]]; then
  echo "Usage: $0 <namespace> <canaryrollout-name> [timeout-seconds] [poll-seconds]"
  echo "Example: $0 team-a payments-api 900 10"
  exit 1
fi

if ! [[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || [[ "$TIMEOUT_SECONDS" -le 0 ]]; then
  echo "timeout-seconds must be a positive integer"
  exit 1
fi

if ! [[ "$POLL_SECONDS" =~ ^[0-9]+$ ]] || [[ "$POLL_SECONDS" -le 0 ]]; then
  echo "poll-seconds must be a positive integer"
  exit 1
fi

start_epoch="$(date +%s)"

while true; do
  now_epoch="$(date +%s)"
  elapsed="$((now_epoch - start_epoch))"

  if [[ "$elapsed" -ge "$TIMEOUT_SECONDS" ]]; then
    echo "Timeout waiting for CanaryRollout ${NAMESPACE}/${NAME}"
    oc -n "$NAMESPACE" get canaryrollout "$NAME" -o yaml || true
    exit 1
  fi

  json="$(oc -n "$NAMESPACE" get canaryrollout "$NAME" -o json 2>/dev/null || true)"
  if [[ -z "$json" ]]; then
    echo "CanaryRollout ${NAMESPACE}/${NAME} not found yet. elapsed=${elapsed}s"
    sleep "$POLL_SECONDS"
    continue
  fi

  generation="$(echo "$json" | jq -r '.metadata.generation // 0')"
  observed="$(echo "$json" | jq -r '.status.observedGeneration // 0')"
  phase="$(echo "$json" | jq -r '.status.phase // "Pending"')"
  message="$(echo "$json" | jq -r '.status.message // ""')"

  echo "state: generation=${generation} observed=${observed} phase=${phase} elapsed=${elapsed}s"

  if [[ "$phase" == "Failed" ]]; then
    echo "CanaryRollout failed: ${message}"
    oc -n "$NAMESPACE" get canaryrollout "$NAME" -o yaml || true
    exit 1
  fi

  if [[ "$observed" == "$generation" && "$phase" == "Succeeded" ]]; then
    echo "CanaryRollout completed successfully"
    exit 0
  fi

  sleep "$POLL_SECONDS"
done
