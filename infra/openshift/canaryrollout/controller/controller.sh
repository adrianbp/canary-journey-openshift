#!/usr/bin/env bash
set -euo pipefail

POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-15}"
WATCH_NAMESPACE="${WATCH_NAMESPACE:-}"
DEFAULT_MIN_CANARY_REPLICAS="${DEFAULT_MIN_CANARY_REPLICAS:-1}"

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

  local timestamp payload
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  payload="$(jq -n \
    --argjson observedGeneration "$observed_generation" \
    --arg phase "$phase" \
    --arg lastAction "$last_action" \
    --arg currentStep "$current_step" \
    --arg message "$message" \
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
        ]
      }
    }')"

  oc -n "$cr_ns" patch canaryrollout "$cr_name" --subresource=status --type=merge -p "$payload" >/dev/null
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
    echo "[$cr_ns/$cr_name] invalid spec, missing targetRef/action"
    patch_status "$cr_ns" "$cr_name" "$observed_generation" "Failed" "$action" "$step_name" "Invalid spec: missing targetRef/action" 0 0 0 0 "Ready" "False" "InvalidSpec"
    return
  fi

  route_name="$(get_route_name "$item" "$app_name")"

  if [[ "$suspended" == "true" ]]; then
    echo "[$cr_ns/$cr_name] suspended=true, skipping"
    patch_status "$cr_ns" "$cr_name" "$observed_generation" "Pending" "$action" "$step_name" "Reconciliation suspended by spec.suspend=true" 0 0 0 0 "Ready" "Unknown" "Suspended"
    return
  fi

  if [[ "$generation" -le "$observed_generation" ]]; then
    return
  fi

  if [[ "$approval_required" == "true" && "$approval_state" != "APPROVED" ]]; then
    echo "[$cr_ns/$cr_name] waiting approval"
    patch_status "$cr_ns" "$cr_name" "$observed_generation" "WaitingApproval" "$action" "$step_name" "Waiting for manual approval" 0 0 0 0 "Approved" "False" "ApprovalPending"
    return
  fi

  echo "[$cr_ns/$cr_name] reconciling action=$action app=$app_name ns=$target_ns"

  local cmd_output tmp_plan_file stable_weight canary_weight stable_replicas canary_replicas
  tmp_plan_file=""

  if [[ "$action" == "ENABLE" ]]; then
    if cmd_output="$($ROUTE_AUTOMATION_DIR/bootstrap-primary.sh "$target_ns" "$app_name" "$DEFAULT_MIN_CANARY_REPLICAS" 2>&1)"; then
      read -r stable_weight canary_weight stable_replicas canary_replicas <<<"$(collect_runtime_status "$target_ns" "$app_name" "$route_name")"
      patch_status "$cr_ns" "$cr_name" "$generation" "Succeeded" "$action" "" "Enable executed successfully" "$stable_weight" "$canary_weight" "$stable_replicas" "$canary_replicas" "Ready" "True" "EnableSucceeded"
    else
      patch_status "$cr_ns" "$cr_name" "$generation" "Failed" "$action" "" "$cmd_output" 0 0 0 0 "Ready" "False" "EnableFailed"
    fi
    return
  fi

  if [[ "$action" == "ADVANCE_STEP" ]]; then
    if [[ -z "$step_name" ]]; then
      patch_status "$cr_ns" "$cr_name" "$generation" "Failed" "$action" "$step_name" "spec.stepName is required for ADVANCE_STEP" 0 0 0 0 "Ready" "False" "InvalidStep"
      return
    fi

    tmp_plan_file="$(mktemp)"
    if ! get_plan_from_configmap "$target_ns" "$item" "$app_name" "$tmp_plan_file"; then
      patch_status "$cr_ns" "$cr_name" "$generation" "Failed" "$action" "$step_name" "Could not load rollout plan from ConfigMap" 0 0 0 0 "Ready" "False" "PlanNotFound"
      rm -f "$tmp_plan_file"
      return
    fi

    if cmd_output="$($ROUTE_AUTOMATION_DIR/apply-step.sh "$tmp_plan_file" "$step_name" 2>&1)"; then
      read -r stable_weight canary_weight stable_replicas canary_replicas <<<"$(collect_runtime_status "$target_ns" "$app_name" "$route_name")"
      patch_status "$cr_ns" "$cr_name" "$generation" "Succeeded" "$action" "$step_name" "Step executed successfully" "$stable_weight" "$canary_weight" "$stable_replicas" "$canary_replicas" "Ready" "True" "AdvanceStepSucceeded"
    else
      patch_status "$cr_ns" "$cr_name" "$generation" "Failed" "$action" "$step_name" "$cmd_output" 0 0 0 0 "Ready" "False" "AdvanceStepFailed"
    fi

    rm -f "$tmp_plan_file"
    return
  fi

  patch_status "$cr_ns" "$cr_name" "$generation" "Pending" "$action" "$step_name" "Action not implemented in Phase 2 MVP controller" 0 0 0 0 "Ready" "Unknown" "NotImplemented"
}

main_loop() {
  echo "CanaryRollout MVP controller started (watch_namespace='${WATCH_NAMESPACE:-ALL}', poll=${POLL_INTERVAL_SECONDS}s)"

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
