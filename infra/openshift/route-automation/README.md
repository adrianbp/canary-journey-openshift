# OpenShift Route Automation (Test A)

This package applies canary rollout steps on OpenShift Routes by combining:
1. Canary deployment scaling (replicas)
2. Route weight shifting (stable/canary)

## Why this exists
When HPA/KEDA is not enabled, pod capacity must be adjusted per traffic step.
This automation enforces a safer sequence:
1. Scale canary deployment
2. Wait rollout ready
3. Shift Route traffic weight

The script supports dynamic replica calculation from the current stable deployment:
- `canaryReplicas: auto` per step
- `minCanaryReplicas` at plan level
- `safetyExtraReplicas` at plan level

## Ownership Model
- Helm: must not create/manage `<app>-primary` deployment/service for this PoC.
- `oc` scripts in this folder: own `-primary` bootstrap, promotion sync, rollback, disable, and route weight changes.

## Files
- `plans/<app>/<env>/rollout-steps.yaml`: per-deployment per-environment rollout plans
- `validate-plan.sh`: validates required fields and weight consistency per step
- `run-step.sh`: wrapper to run one step by `<app>/<env>`
- `run-progressive.sh`: wrapper to run progressive flow by `<app>/<env>`
- `rollout-steps.yaml`: rollout plan with traffic and replicas per step
- `bootstrap-primary.sh`: creates `<app>-primary` deployment/service and shifts route to primary
- `disable-canary.sh`: reverses canary mode and routes 100% traffic back to `<app>`
- `promote-to-primary.sh`: syncs canary spec to `<app>-primary` and routes traffic back to primary
- `apply-step.sh`: applies one named step
- `rollback.sh`: returns to preview/safe step (`step-00-preview`)
- `check-metrics-dynatrace.sh`: metric gate using Dynatrace API
- `progressive-rollout-dynatrace.sh`: runs step progression with automatic rollback on metric failure
- `dynatrace.env.example`: Dynatrace environment variables template

## Prerequisites
- `oc` logged in and pointed to your OpenShift cluster
- Existing Route with stable service as main backend
- Existing app deployment/service (`<app>`) as baseline
- `bootstrap-primary.sh` will create `<app>-primary` deployment/service when canary mode is enabled

## Usage
```bash
cd infra/openshift/route-automation

# One-time bootstrap to mimic Flagger naming/behavior:
# primary: <app>-primary, canary: <app>
./bootstrap-primary.sh team-a payments-api 1

# Validate plan (per deployment/env)
./validate-plan.sh plans/payments-api/dev/rollout-steps.yaml

# Apply one step (per deployment/env)
./run-step.sh payments-api dev step-10
./run-step.sh payments-api dev step-25

# Apply 50%
./run-step.sh payments-api dev step-50

# Temporarily route 100% to canary
./run-step.sh payments-api dev step-100-canary

# Finalize promotion like Flagger (sync to -primary, route 100% to primary, and scale canary to 0)
./promote-to-primary.sh team-a payments-api 0

# Roll back to safe preview mode
./rollback.sh plans/payments-api/dev/rollout-steps.yaml

# Disable canary mode and return to single deployment pattern
# true => remove <app>-primary resources
./disable-canary.sh team-a payments-api true 25 20
```

## Dynatrace-based automatic progression
1. Create environment file from template and set your values:
```bash
cp dynatrace.env.example dynatrace.env
```

2. Load variables:
```bash
set -a
source dynatrace.env
set +a
```

3. Validate metrics gate only:
```bash
./check-metrics-dynatrace.sh
```

4. Run progressive rollout with automatic rollback:
```bash
./run-progressive.sh payments-api dev 120 step-10 step-25 step-50 step-100-canary promote-primary
```

Behavior:
- Before each step, script checks Dynatrace thresholds.
- If gate fails, script runs `rollback.sh` and exits.

Bootstrap behavior:
- Copies current `<app>` deployment/service to `<app>-primary`.
- Preserves stable capacity using current `<app>` replica count.
- Scales canary `<app>` to baseline (`min-canary-replicas` argument, default `1`).
- Patches route to `primary=100` and `canary=0`.

Disable behavior:
- Copies `<app>-primary` spec to `<app>` and scales `<app>` to preserved primary replicas.
- Shifts route traffic gradually from `<app>-primary` to `<app>` (configurable step/wait).
- Finalizes route with `<app>=100%` and clears alternate backends.
- Optionally removes `<app>-primary` deployment/service (or scales it to zero if keep mode).

Promotion behavior (Flagger-like):
- Route canary temporarily to 100% (`step-100-canary`).
- Sync canary deployment spec to `<app>-primary`.
- Wait `<app>-primary` healthy.
- Route traffic back to `<app>-primary` 100%.
- Preserve `<app>-primary` replicas from before promotion.
- Scale canary to 0 by default.

## Balancing recommendation without HPA/KEDA
Default auto rule:
`canaryReplicas = max(minCanaryReplicas, ceil(stableReplicas * canaryWeight / 100) + safetyExtraReplicas)`

Example if stable has 7 replicas:
- 10% -> 1 pod
- 25% -> 2 pods
- 50% -> 4 pods

Set `safetyExtraReplicas: 1` when latency-sensitive workloads need extra headroom.

## Naming model (Flagger-like)
- Canary deployment/service: `<app>`
- Stable deployment/service: `<app>-primary`
- Route: `<app>`
