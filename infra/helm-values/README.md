# Helm Values Layout for Multi-Cluster

This folder standardizes Helm values by component and environment.

## Structure
- `infra/helm-values/<component>/common/values.yaml`
- `infra/helm-values/<component>/<env>/values.yaml` where env is `dev|stg|prod`

## Components
- `ingress-nginx`
- `prometheus` (kube-prometheus-stack)
- `loki` (loki-stack)
- `rabbitmq`
- `postgres` (audit DB)
- `flagger`

## Install Examples (dev)

```bash
# Ingress NGINX
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx \
  -f infra/helm-values/ingress-nginx/common/values.yaml \
  -f infra/helm-values/ingress-nginx/dev/values.yaml

# Prometheus + Grafana
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring \
  -f infra/helm-values/prometheus/common/values.yaml \
  -f infra/helm-values/prometheus/dev/values.yaml

# Loki + Promtail
helm upgrade --install loki grafana/loki-stack -n logging \
  -f infra/helm-values/loki/common/values.yaml \
  -f infra/helm-values/loki/dev/values.yaml

# RabbitMQ
helm upgrade --install rabbitmq bitnami/rabbitmq -n messaging \
  -f infra/helm-values/rabbitmq/common/values.yaml \
  -f infra/helm-values/rabbitmq/dev/values.yaml

# Postgres (audit)
helm upgrade --install audit-postgres bitnami/postgresql -n data \
  -f infra/helm-values/postgres/common/values.yaml \
  -f infra/helm-values/postgres/dev/values.yaml

# Flagger
helm upgrade --install flagger flagger/flagger -n flagger-system \
  -f infra/helm-values/flagger/common/values.yaml \
  -f infra/helm-values/flagger/dev/values.yaml
```

## Environment Switch
Change only the second values file from `dev` to `stg` or `prod`.

## Recommended Next Step
Add cluster overlays like:
- `infra/helm-values/flagger/clusters/eks-dev-1.yaml`
- `infra/helm-values/prometheus/clusters/aks-stg-1.yaml`

Then apply with: `-f common -f env -f cluster`.

## Separate Automation for Istio and Kiali
Istio/Kiali is intentionally separated from the main platform stack.

Script:
- `infra/automation/istio-kiali.sh`

Values:
- `infra/helm-values/istio/*`
- `infra/helm-values/kiali/*`

Usage:
```bash
# Install (dev)
./infra/automation/istio-kiali.sh install dev

# Check status
./infra/automation/istio-kiali.sh status

# Uninstall releases (keeps namespace)
./infra/automation/istio-kiali.sh uninstall
```
