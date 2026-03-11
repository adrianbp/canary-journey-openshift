# Canary Add-on Values (Per Deployment)

This folder stores per-deployment canary settings for the `charts/canary-addon` chart.
No global traffic weights are used.

Example install for one deployment:

```bash
helm upgrade --install payments-api-canary-addon charts/canary-addon \
  -n team-a \
  -f infra/helm-values/canary-addon/payments-api/dev/values.yaml
```

Each deployment/service has its own values file and rollout steps.
