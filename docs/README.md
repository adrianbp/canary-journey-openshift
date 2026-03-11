# Documentation Index (PoC A)

Ownership rule for PoC A:
- Helm does not create/manage `<app>-primary`.
- OpenShift automation scripts (`infra/openshift/route-automation`) own `<app>-primary` lifecycle and traffic operations.

- Unified OpenShift + Kubernetes architecture:
  - `docs/canary-unified-architecture-openshift-k8s.md`
- OpenShift CanaryRollout CRD design (Phase 1, with Phase 2 MVP status):
  - `docs/openshift-canaryrollout-crd-phase1.md`
- Quickstart OpenShift CanaryRollout (E2E):
  - `docs/quickstart-openshift-canaryrollout.md`
- Notifications architecture (Slack/Teams):
  - `docs/canary-notifications-architecture.md`
