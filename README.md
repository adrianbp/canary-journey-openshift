# Canary Journey OpenShift - PoC A

This branch contains only the assets required for PoC A:
- OpenShift Route automation for canary rollout
- Optional Dynatrace-assisted progressive rollout
- Helm add-on chart for per-deployment canary config (no `-primary` object management)
- CanaryRollout CRD + controller MVP
- Architecture, notifications, and quickstart docs

## Main Paths
- `infra/openshift/route-automation/`
- `infra/openshift/canaryrollout/`
- `charts/canary-addon/`
- `infra/helm-values/canary-addon/`
- `docs/`
- `.github/workflows/openshift-canary-orchestration.yml`

## Resource Ownership (PoC A)
- Helm: baseline app resources and canary rollout configuration (route/ingress references + rollout plan).
- `oc` automation scripts: full lifecycle of transient canary resources (`<app>-primary` deployment/service, traffic shifts, promote, rollback, disable).

## CI/CD Orchestration
GitHub Actions workflow is included to enforce execution order:
- Enable: `bootstrap-primary.sh` first, then `helm upgrade`.
- Disable: `disable-canary.sh` first, then `helm upgrade --set canary.enabled=false`.
- Controller image build/push: `.github/workflows/build-canaryrollout-controller-image.yml`.

## Canary CRD + Controller (Phase 1 + Phase 2 MVP)
- CRD: `infra/openshift/canaryrollout/crd/canaryrollouts.canary.company.io.yaml`
- Examples: `infra/openshift/canaryrollout/examples/`
- Design doc: `docs/openshift-canaryrollout-crd-phase1.md`
- Quickstart E2E: `docs/quickstart-openshift-canaryrollout.md`
- Simple runbook: `docs/RUNBOOK.md`
- Dev playbook: `docs/PLAYBOOK-DEV.md`
- Pipeline gates snippets: `docs/canaryrollout-pipeline-gates.md`
- Adoption plan for Friday presentation: `docs/plano-adocao-canaryrollout-sexta.md`
- Operator migration plan (OpenShift -> Kubernetes): `docs/plano-migracao-operator-openshift-k8s.md`
- Decision log: `docs/DECISION-LOG.md`
- Controller MVP (Phase 2): `infra/openshift/canaryrollout/controller/controller.sh`
- Controller in-cluster manifest: `infra/openshift/canaryrollout/controller/deployment.yaml`
- Controller image build workflow: `.github/workflows/build-canaryrollout-controller-image.yml`
