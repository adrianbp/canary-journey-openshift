# Canary Add-on Values (Per Deployment)

This folder stores per-deployment canary settings for the `charts/canary-addon` chart.
No global traffic weights are used.
In PoC A, these values only reference stable names (`stable.deploymentName`, `stable.serviceName`);
the chart does not create/manage `<app>-primary`.
These values also provide the rollout plan consumed by the CanaryRollout controller via ConfigMap.

Example install for one deployment:

```bash
helm upgrade --install payments-api-canary-addon charts/canary-addon \
  -n team-a \
  -f infra/helm-values/canary-addon/payments-api/dev/values.yaml
```

Each deployment/service has its own values file and rollout steps.
