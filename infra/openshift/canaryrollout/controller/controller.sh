#!/usr/bin/env bash
set -euo pipefail

POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-15}"
WATCH_NAMESPACE="${WATCH_NAMESPACE:-}"
DEFAULT_MIN_CANARY_REPLICAS="${DEFAULT_MIN_CANARY_REPLICAS:-1}"
DEFAULT_PROMOTE_CANARY_BASELINE_REPLICAS="${DEFAULT_PROMOTE_CANARY_BASELINE_REPLICAS:-0}"
DEFAULT_DISABLE_DELETE_PRIMARY="${DEFAULT_DISABLE_DELETE_PRIMARY:-true}"
DEFAULT_DISABLE_SHIFT_STEP="${DEFAULT_DISABLE_SHIFT_STEP:-25}"
DEFAULT_DISABLE_WAIT_SECONDS="${DEFAULT_DISABLE_WAIT_SECONDS:-20}"
EVENTS_ENABLED="${EVENTS_ENABLED:-true}"
MAX_STATUS_MESSAGE_LEN="${MAX_STATUS_MESSAGE_LEN:-700}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OPENSHIFT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROUTE_AUTOMATION_DIR="$OPENSHIFT_DIR/route-automation"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

require_cmd oc
require_cmd jq
require_cmd mktemp

truncate_message() {
  local msg="$1"
  local max_len="$2"
  if [[ ${#msg} -le $max_len ]]; then
    echo "$msg"
  else
    echo "${msg:0:max_len}..."
  fi
}

emit_event() {
  local cr_ns="$1"
  local cr_name="$2"
  local event_type="$3"
  local reason="$4"
  local message="$5"

  if [[ "$EVENTS_ENABLED" != "true" ]]; then
    return 0
  fi

  local ts short_msg
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  short_msg="$(truncate_message "$message" 250)"

  oc -n "$cr_ns" create -f - >/dev/null 2>&1 <<YAML || true
apiVersion: v1
kind: Event
metadata:
  generateName: ${cr_name}-
  namespace: ${cr_ns}
involvedObject:
  apiVersion: canary.company.io/v1alpha1
  kind: CanaryRollout
  name: ${cr_name}
  namespace: ${cr_ns}
type: ${event_type}
reason: ${reason}
message: |-
  ${short_msg}
firstTimestamp: ${ts}
lastTimestamp: ${ts}
count: 1
source:
  component: canaryrollout-controller
YAML
}

get_rollouts_json() {
  if [[ -n "$WATCH_NAMESPACE" ]]; then
    oc -n "$WATCH_NAMESPACE" get canaryrollouts.canary.company.io -o json
  else
    oc get canaryrollouts.canary.company.io -A -o json
  fi
}

get_route_name() {
  local item="$1"
  local app_name="$2"
  local route_name
  route_name="$(echo "$item" | jq -r '.spec.targetRef.routeName // empty')"
  if [[ -z "$route_name" || "$route_name" == "null" ]]; then
    route_name="$app_name"
  fi
  echo "$route_name"
}

get_plan_from_configmap() {
  local target_ns="$1"
  local item="$2"
  local app_name="$3"
  local out_file="$4"

  local cm_name plan_key
  cm_name="$(echo "$item" | jq -r '.spec.planRef.configMapName // empty')"
  plan_key="$(echo "$item" | jq -r '.spec.planRef.key // "rollout-steps.yaml"')"

  if [[ -z "$cm_name" || "$cm_name" == "null" ]]; then
    cm_name="${app_name}-rollout-plan"
  fi

  oc -n "$target_ns" get configmap "$cm_name" -o json \
    | jq -r --arg key "$plan_key" '.data[$key] // empty' > "$out_file"

  if [[ ! -s "$out_file" ]]; then
    echo "Plan not found in ConfigMap ${cm_name} key ${plan_key}"
    return 1
  fi
}

safe_json_int() {
  local v="$1"
  if [[ "$v" =~ ^[0-9]+$ ]]; then
    echo "$v"
  else
    echo "0"
  fi
}

collect_runtime_status() {
  local target_ns="$1"
  local app_name="$2"
  local route_name="$3"

  local stable_weight canary_weight stable_replicas canary_replicas

  stable_weight="$(oc -n "$target_ns" get route "$route_name" -o jsonpath='{.spec.to.weight}' 2>/dev/null || true)"
  canary_weight="$(oc -n "$target_ns" get route "$route_name" -o jsonpath='{.spec.alternateBackends[0].weight}' 2>/dev/null || true)"

  stable_replicas="$(oc -n "$target_ns" get deployment "${app_name}-primary" -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
  canary_replicas="$(oc -n "$target_ns" get deployment "$app_name" -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"

  stable_weight="$(safe_json_int "$stable_weight")"
  canary_weight="$(safe_json_int "$canary_weight")"
  stable_replicas="$(safe_json_int "$stable_replicas")"
  canary_replicas="$(safe_json_int "$canary_replicas")"

  echo "$stable_weight $canary_weight $stable_replicas $canary_replicas"
}

patch_status() {
  local cr_ns="$1"
  local cr_name="$2"
  local observed_generation="$3"
  local phase="$4"
  local last_action="$5"
  local current_step="$6"
  local message="$7"
  local stable_weight="$8"
  local canary_weight="$9"
  local stable_replicas="${10}"
  local canary_replicas="${11}"
  local condition_type="${12}"
  local condition_status="${13}"
  local condition_reason="${14}"

  local timestamp payload msg
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  msg="$(truncate_message "$message" "$MAX_STATUS_MESSAGE_LEN")"

  payload="$(jq -n \
    --argjson observedGeneration "$observed_generation" \
    --arg phase "$phase" \
    --arg lastAction "$last_action" \
    --arg currentStep "$current_step" \
    --arg message "$msg" \
    --argjson stableWeight "$stable_weight" \
    --argjson canaryWeight "$canary_weight" \
    --argjson stableReplicas "$stable_replicas" \
    --argjson canaryReplicas "$canary_replicas" \
    --arg conditionType "$condition_type" \
    --arg conditionStatus "$condition_status" \
    --arg conditionReason "$condition_reason" \
    --arg transition "$timestamp" \
    '{
      status: {
        observedGeneration: $observedGeneration,
        phase: $phase,
        lastAction: $lastAction,
        currentStep: $currentStep,
        message: $message,
        traffic: {
          stableWeight: $stableWeight,
          canaryWeight: $canaryWeight
        },
        replicas: {
          stable: $stableReplicas,
          canary: $canaryReplicas
        },
        conditions: [
          {
            type: $conditionType,
            status: $conditionStatus,
            reason: $conditionReason,
            message: $message,
            lastTransitionTime: $transition
          }
        ],
        history: [
          {
            action: $lastAction,
            stepName: $currentStep,
            result: (if $conditionStatus == "True" then "Succeeded" else "Failed" end),
            timestamp: $transition,
            message: $message
          }
        ]
      }
    }')"

  oc -n "$cr_ns" patch canaryrollout "$cr_name" --subresource=status --type=merge -p "$payload" >/dev/null
}

update_result() {
  local cr_ns="$1"
  local cr_name="$2"
  local generation="$3"
  local action="$4"
  local step_name="$5"
  local phase="$6"
  local success="$7"
  local reason="$8"
  local message="$9"
  local target_ns="${10}"
  local app_name="${11}"
  local route_name="${12}"

  local stable_weight canary_weight stable_replicas canary_replicas cond_status event_type
  read -r stable_weight canary_weight stable_replicas canary_replicas <<<"$(collect_runtime_status "$target_ns" "$app_name" "$route_name")"

  if [[ "$success" == "true" ]]; then
    cond_status="True"
    event_type="Normal"
  else
    cond_status="False"
    event_type="Warning"
  fi

  patch_status "$cr_ns" "$cr_name" "$generation" "$phase" "$action" "$step_name" "$message" \
    "$stable_weight" "$canary_weight" "$stable_replicas" "$canary_replicas" "Ready" "$cond_status" "$reason"
  emit_event "$cr_ns" "$cr_name" "$event_type" "$reason" "$message"
}

run_action() {
  local action="$1"
  local item="$2"
  local target_ns="$3"
  local app_name="$4"
  local step_name="$5"

  local tmp_plan_file enable_min_replicas promote_baseline disable_delete disable_shift disable_wait

  case "$action" in
    ENABLE)
      enable_min_replicas="$(echo "$item" | jq -r '.spec.enablePolicy.minCanaryReplicas // empty')"
      if [[ -z "$enable_min_replicas" || "$enable_min_replicas" == "null" ]]; then
        enable_min_replicas="$DEFAULT_MIN_CANARY_REPLICAS"
      fi
      "$ROUTE_AUTOMATION_DIR/bootstrap-primary.sh" "$target_ns" "$app_name" "$enable_min_replicas"
      ;;

    ADVANCE_STEP)
      if [[ -z "$step_name" ]]; then
        echo "spec.stepName is required for ADVANCE_STEP"
        return 1
      fi
      tmp_plan_file="$(mktemp)"
      if ! get_plan_from_configmap "$target_ns" "$item" "$app_name" "$tmp_plan_file"; then
        rm -f "$tmp_plan_file"
        return 1
      fi
      "$ROUTE_AUTOMATION_DIR/apply-step.sh" "$tmp_plan_file" "$step_name"
      rm -f "$tmp_plan_file"
      ;;

    PROMOTE)
      promote_baseline="$(echo "$item" | jq -r '.spec.promotePolicy.canaryBaselineReplicas // empty')"
      if [[ -z "$promote_baseline" || "$promote_baseline" == "null" ]]; then
        promote_baseline="$DEFAULT_PROMOTE_CANARY_BASELINE_REPLICAS"
      fi
      "$ROUTE_AUTOMATION_DIR/promote-to-primary.sh" "$target_ns" "$app_name" "$promote_baseline"
      ;;

    ROLLBACK)
      tmp_plan_file="$(mktemp)"
      if ! get_plan_from_configmap "$target_ns" "$item" "$app_name" "$tmp_plan_file"; then
        rm -f "$tmp_plan_file"
        return 1
      fi
      "$ROUTE_AUTOMATION_DIR/rollback.sh" "$tmp_plan_file"
      rm -f "$tmp_plan_file"
      ;;

    DISABLE)
      disable_delete="$(echo "$item" | jq -r '.spec.disablePolicy.deletePrimary // empty')"
      disable_shift="$(echo "$item" | jq -r '.spec.disablePolicy.shiftStep // empty')"
      disable_wait="$(echo "$item" | jq -r '.spec.disablePolicy.waitSeconds // empty')"

      if [[ -z "$disable_delete" || "$disable_delete" == "null" ]]; then
        disable_delete="$DEFAULT_DISABLE_DELETE_PRIMARY"
      fi
      if [[ -z "$disable_shift" || "$disable_shift" == "null" ]]; then
        disable_shift="$DEFAULT_DISABLE_SHIFT_STEP"
      fi
      if [[ -z "$disable_wait" || "$disable_wait" == "null" ]]; then
        disable_wait="$DEFAULT_DISABLE_WAIT_SECONDS"
      fi

      "$ROUTE_AUTOMATION_DIR/disable-canary.sh" "$target_ns" "$app_name" "$disable_delete" "$disable_shift" "$disable_wait"
      ;;

    *)
      echo "Action not implemented: $action"
      return 1
      ;;
  esac

  return 0
}

reconcile_item() {
  local item="$1"

  local cr_name cr_ns generation observed_generation
  local app_name target_ns action step_name route_name
  local approval_required approval_state suspended

  cr_name="$(echo "$item" | jq -r '.metadata.name')"
  cr_ns="$(echo "$item" | jq -r '.metadata.namespace')"
  generation="$(echo "$item" | jq -r '.metadata.generation // 0')"
  observed_generation="$(echo "$item" | jq -r '.status.observedGeneration // 0')"

  app_name="$(echo "$item" | jq -r '.spec.targetRef.name // empty')"
  target_ns="$(echo "$item" | jq -r '.spec.targetRef.namespace // empty')"
  action="$(echo "$item" | jq -r '.spec.action // empty')"
  step_name="$(echo "$item" | jq -r '.spec.stepName // ""')"
  approval_required="$(echo "$item" | jq -r '.spec.approval.required // true')"
  approval_state="$(echo "$item" | jq -r '.spec.approval.state // "PENDING"')"
  suspended="$(echo "$item" | jq -r '.spec.suspend // false')"

  if [[ -z "$app_name" || -z "$target_ns" || -z "$action" ]]; then
    patch_status "$cr_ns" "$cr_name" "$observed_generation" "Failed" "$action" "$step_name" \
      "Invalid spec: missing targetRef/action" 0 0 0 0 "Ready" "False" "InvalidSpec"
    emit_event "$cr_ns" "$cr_name" "Warning" "InvalidSpec" "Invalid spec: missing targetRef/action"
    return
  fi

  route_name="$(get_route_name "$item" "$app_name")"

  if [[ "$suspended" == "true" ]]; then
    patch_status "$cr_ns" "$cr_name" "$observed_generation" "Pending" "$action" "$step_name" \
      "Reconciliation suspended by spec.suspend=true" 0 0 0 0 "Ready" "Unknown" "Suspended"
    emit_event "$cr_ns" "$cr_name" "Normal" "Suspended" "Reconciliation suspended by spec.suspend=true"
    return
  fi

  if [[ "$generation" -le "$observed_generation" ]]; then
    return
  fi

  if [[ "$approval_required" == "true" && "$approval_state" != "APPROVED" ]]; then
    patch_status "$cr_ns" "$cr_name" "$observed_generation" "WaitingApproval" "$action" "$step_name" \
      "Waiting for manual approval" 0 0 0 0 "Approved" "False" "ApprovalPending"
    emit_event "$cr_ns" "$cr_name" "Normal" "ApprovalPending" "Waiting for manual approval"
    return
  fi

  local output

  echo "[$cr_ns/$cr_name] reconciling action=$action app=$app_name ns=$target_ns"
  emit_event "$cr_ns" "$cr_name" "Normal" "Reconciling" "Reconciling action=${action}"

  if output="$(run_action "$action" "$item" "$target_ns" "$app_name" "$step_name" 2>&1)"; then
    update_result "$cr_ns" "$cr_name" "$generation" "$action" "$step_name" "Succeeded" "${action}Succeeded" \
      "Action ${action} executed successfully" "$target_ns" "$app_name" "$route_name"
  else
    output="$(truncate_message "$output" "$MAX_STATUS_MESSAGE_LEN")"
    update_result "$cr_ns" "$cr_name" "$generation" "$action" "$step_name" "Failed" "${action}Failed" \
      "$output" "$target_ns" "$app_name" "$route_name"
  fi
}

main_loop() {
  echo "CanaryRollout controller started (watch_namespace='${WATCH_NAMESPACE:-ALL}', poll=${POLL_INTERVAL_SECONDS}s)"

  while true; do
    rollouts_json="$(get_rollouts_json)"
    mapfile -t items < <(echo "$rollouts_json" | jq -c '.items[]?')

    for item in "${items[@]}"; do
      reconcile_item "$item"
    done

    sleep "$POLL_INTERVAL_SECONDS"
  done
}

main_loop
