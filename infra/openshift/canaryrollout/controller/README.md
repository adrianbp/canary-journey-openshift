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
- Emits OpenShift `Event` objects for reconciliation/audit visibility.

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
export EVENTS_ENABLED=true

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

## Build and Push Image (local)
```bash
export IMAGE_REPO=ghcr.io/<your-user>/canaryrollout-controller
export IMAGE_TAG=0.1.0
infra/openshift/canaryrollout/controller/build-image.sh
docker push ${IMAGE_REPO}:${IMAGE_TAG}
```

Update `infra/openshift/canaryrollout/controller/deployment.yaml` with your image tag.

## Build and Push Image (GitHub Actions)
Workflow:
- `.github/workflows/build-canaryrollout-controller-image.yml`

Manual trigger options:
- `image_tag`: target tag to publish to GHCR

Default image target:
- `ghcr.io/<repo-owner>/canaryrollout-controller:<tag>`
- `ghcr.io/<repo-owner>/canaryrollout-controller:latest`

## Notes
- This MVP is shell-based and intended to validate reconciliation behavior quickly.
- For production, replace with a proper Operator/Controller runtime (Go + controller-runtime) and leader election.
- Use `docs/quickstart-openshift-canaryrollout.md` for full end-to-end validation flow.
