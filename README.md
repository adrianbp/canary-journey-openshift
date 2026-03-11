# Canary Journey OpenShift - PoC A

This branch contains only the assets required for PoC A:
- OpenShift Route automation for canary rollout
- Optional Dynatrace-assisted progressive rollout
- Helm add-on chart for per-deployment canary config (no `-primary` object management)
- Architecture and notifications design docs

## Main Paths
- `infra/openshift/route-automation/`
- `charts/canary-addon/`
- `infra/helm-values/canary-addon/`
- `docs/`

## Resource Ownership (PoC A)
- Helm: baseline app resources and canary rollout configuration (route/ingress references + rollout plan).
- `oc` automation scripts: full lifecycle of transient canary resources (`<app>-primary` deployment/service, traffic shifts, promote, rollback, disable).
