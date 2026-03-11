#!/usr/bin/env bash
set -euo pipefail

if ! command -v curl >/dev/null 2>&1; then
  echo "Missing required command: curl"
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Missing required command: jq"
  exit 2
fi

DT_BASE_URL="${DT_BASE_URL:-}"
DT_API_TOKEN="${DT_API_TOKEN:-}"
DT_ERROR_METRIC_SELECTOR="${DT_ERROR_METRIC_SELECTOR:-builtin:service.errors.server.rate:avg}"
DT_LATENCY_METRIC_SELECTOR="${DT_LATENCY_METRIC_SELECTOR:-builtin:service.response.time:percentile(95)}"
DT_ENTITY_SELECTOR="${DT_ENTITY_SELECTOR:-}"
DT_FROM="${DT_FROM:-now-5m}"
DT_TO="${DT_TO:-now}"
DT_MAX_ERROR_RATE_PERCENT="${DT_MAX_ERROR_RATE_PERCENT:-1.0}"
DT_MAX_P95_MS="${DT_MAX_P95_MS:-500}"
DT_ALLOW_NO_DATA="${DT_ALLOW_NO_DATA:-false}"

if [[ -z "$DT_BASE_URL" || -z "$DT_API_TOKEN" ]]; then
  echo "DT_BASE_URL and DT_API_TOKEN are required"
  exit 2
fi

query_metric() {
  local selector="$1"
  local encoded_selector
  encoded_selector="$(printf '%s' "$selector" | jq -sRr @uri)"

  local url="${DT_BASE_URL%/}/api/v2/metrics/query?metricSelector=${encoded_selector}&from=${DT_FROM}&to=${DT_TO}&resolution=Inf"
  if [[ -n "$DT_ENTITY_SELECTOR" ]]; then
    local encoded_entity
    encoded_entity="$(printf '%s' "$DT_ENTITY_SELECTOR" | jq -sRr @uri)"
    url+="&entitySelector=${encoded_entity}"
  fi

  local response
  response="$(curl -fsS "$url" -H "Authorization: Api-Token ${DT_API_TOKEN}" -H "Accept: application/json")"

  local value
  value="$(printf '%s' "$response" | jq -r '
    .result
    | if length == 0 then empty else .[0].data end
    | if length == 0 then empty else .[0].values end
    | map(select(. != null))
    | if length == 0 then empty else .[-1] end
  ')"

  if [[ -z "$value" || "$value" == "null" ]]; then
    if [[ "$DT_ALLOW_NO_DATA" == "true" ]]; then
      echo "nan"
      return 0
    fi
    echo "No metric data returned for selector: $selector" >&2
    return 1
  fi

  printf '%s' "$value"
}

greater_than() {
  awk -v n1="$1" -v n2="$2" 'BEGIN { if (n1 > n2) print 1; else print 0 }'
}

error_value="$(query_metric "$DT_ERROR_METRIC_SELECTOR")" || exit 1
latency_value="$(query_metric "$DT_LATENCY_METRIC_SELECTOR")" || exit 1

if [[ "$error_value" == "nan" || "$latency_value" == "nan" ]]; then
  echo "Dynatrace check passed with no-data allowed"
  exit 0
fi

echo "Dynatrace gate values: error_rate=${error_value}% p95_ms=${latency_value}"

if [[ "$(greater_than "$error_value" "$DT_MAX_ERROR_RATE_PERCENT")" == "1" ]]; then
  echo "Gate failed: error rate ${error_value}% > ${DT_MAX_ERROR_RATE_PERCENT}%"
  exit 1
fi

if [[ "$(greater_than "$latency_value" "$DT_MAX_P95_MS")" == "1" ]]; then
  echo "Gate failed: p95 ${latency_value}ms > ${DT_MAX_P95_MS}ms"
  exit 1
fi

echo "Dynatrace gate passed"
