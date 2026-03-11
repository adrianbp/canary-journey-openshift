# CanaryRollout CRD (Phase 1)

This folder adds a Flagger-like declarative contract for OpenShift Route canary operations.

## Goal
Provide one CRD object to describe the action to execute:
- `ENABLE`
- `ADVANCE_STEP`
- `PROMOTE`
- `ROLLBACK`
- `DISABLE`

The controller/operator (next phase) will reconcile this object and execute the existing route automation scripts.

## Files
- `crd/canaryrollouts.canary.company.io.yaml`: CRD definition (`v1alpha1`)
- `examples/*.yaml`: sample resources for each action
- `controller/controller.sh`: Phase 2 MVP reconciler (`ENABLE`, `ADVANCE_STEP`, `PROMOTE`, `ROLLBACK`, `DISABLE`)
- `controller/rbac.yaml`: minimal RBAC for the controller
- `controller/deployment.yaml`: sample in-cluster deployment
- `controller/README.md`: operation guide for controller MVP

## Install
```bash
oc apply -f infra/openshift/canaryrollout/crd/canaryrollouts.canary.company.io.yaml
```

## Test CRs
```bash
oc apply -f infra/openshift/canaryrollout/examples/payments-api-enable.yaml
oc apply -f infra/openshift/canaryrollout/examples/payments-api-advance-step.yaml
oc apply -f infra/openshift/canaryrollout/examples/payments-api-promote.yaml
oc apply -f infra/openshift/canaryrollout/examples/payments-api-rollback.yaml
oc apply -f infra/openshift/canaryrollout/examples/payments-api-disable.yaml
```

## Inspect Status
```bash
oc get canaryrollouts -n team-a
oc get canaryrollout payments-api -n team-a -o yaml
```

## Action Mapping (Controller Behavior)
- `ENABLE` -> `infra/openshift/route-automation/bootstrap-primary.sh`
- `ADVANCE_STEP` -> `infra/openshift/route-automation/apply-step.sh`
- `PROMOTE` -> `infra/openshift/route-automation/promote-to-primary.sh`
- `ROLLBACK` -> `infra/openshift/route-automation/rollback.sh`
- `DISABLE` -> `infra/openshift/route-automation/disable-canary.sh`

## Notes
- In PoC A, Helm does not manage `<app>-primary` resources.
- CRD/controller must keep idempotency via `spec.request.idempotencyKey`.
- Manual gates should set `spec.approval.state=APPROVED` before reconciliation executes state-changing actions.
- Phase 2 MVP controller emits OpenShift `Event` objects for audit visibility.
