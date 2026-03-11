# CanaryRollout Controller (Phase 2 MVP)

This MVP controller reconciles `CanaryRollout` actions:
- `ENABLE`
- `ADVANCE_STEP`
- `PROMOTE`
- `ROLLBACK`
- `DISABLE`

## How It Works
- Polls `CanaryRollout` objects every `POLL_INTERVAL_SECONDS` (default `15`).
- Waits for approval when `spec.approval.required=true` and `spec.approval.state!=APPROVED`.
- Executes route automation scripts from `infra/openshift/route-automation`.
- Patches `status` with phase/traffic/replicas/conditions.
- Uses `status.observedGeneration` for idempotent reconciliation by generation.

## Script Mapping
- `ENABLE` -> `bootstrap-primary.sh <namespace> <app> <min-canary-replicas>`
- `ADVANCE_STEP` -> `apply-step.sh <tmp-plan-file> <step-name>` where plan is read from ConfigMap
- `PROMOTE` -> `promote-to-primary.sh <namespace> <app> <canary-baseline-replicas>`
- `ROLLBACK` -> `rollback.sh <tmp-plan-file>` where plan is read from ConfigMap
- `DISABLE` -> `disable-canary.sh <namespace> <app> <delete-primary> <shift-step> <wait-seconds>`

## Prerequisites
- `oc` logged in with permission to read/write the target namespace.
- `jq` installed.
- CRD installed:
  - `infra/openshift/canaryrollout/crd/canaryrollouts.canary.company.io.yaml`
- Route automation scripts available at:
  - `infra/openshift/route-automation/`

## Local Run
```bash
export WATCH_NAMESPACE=team-a
export POLL_INTERVAL_SECONDS=15
export DEFAULT_MIN_CANARY_REPLICAS=1

infra/openshift/canaryrollout/controller/controller.sh
```

## Apply RBAC (cluster run baseline)
```bash
oc apply -f infra/openshift/canaryrollout/controller/rbac.yaml
```

Update namespace/serviceaccount names in `rbac.yaml` per environment.

## Deploy In-Cluster
```bash
oc apply -f infra/openshift/canaryrollout/controller/rbac.yaml
oc apply -f infra/openshift/canaryrollout/controller/deployment.yaml
```

The image in `deployment.yaml` is a placeholder. Build an image that contains:
- `infra/openshift/canaryrollout/controller/controller.sh`
- `infra/openshift/route-automation/*.sh`
- runtime dependencies: `bash`, `oc`, `jq`

## Notes
- This MVP is shell-based and intended to validate reconciliation behavior quickly.
- For production, replace with a proper Operator/Controller runtime (Go + controller-runtime) and leader election.
