# Gateway API Evidence - Flagger on EKS

Date: 2026-03-16 (America/Sao_Paulo)  
Cluster: `canary-eks-dev` (`us-east-1`)

## Objective

Validate if Flagger works with Gateway API in practice (not only config validation).

## Test setup

- Envoy Gateway installed via Helm (`envoyproxy/gateway-helm:v1.7.0`)
- Flagger upgraded with:
  - `meshProvider=gatewayapi:v1`
  - `metricsServer=http://flagger-prometheus.nginx-ingress:9090`
- Gateway API resources:
  - `Gateway` in namespace `gateway-ingress`, class `eg`
- Canary workload in namespace `gateway-test`:
  - app `podinfo`
  - `Canary` with `provider: gatewayapi:v1`
  - `service.gatewayRefs` pointing to `gateway/gateway-ingress`
  - analysis step weight `10`, interval `30s`

## Evidence captured

### 1) HTTPRoute created by Flagger

```text
"msg":"HTTPRoute podinfo.gateway-test created","canary":"podinfo.gateway-test"
```

### 2) Canary progression observed

```text
"msg":"Advance podinfo.gateway-test canary weight 10"
"msg":"Advance podinfo.gateway-test canary weight 20"
"msg":"Advance podinfo.gateway-test canary weight 30"
"msg":"Advance podinfo.gateway-test canary weight 40"
"msg":"Advance podinfo.gateway-test canary weight 50"
```

### 3) HTTPRoute backend weights updated

Observed snapshots:

```text
weights=90 10
weights=80 20
weights=70 30
weights=60 40
weights=50 50
```

Final `HTTPRoute` excerpt:

```yaml
spec:
  hostnames:
  - podinfo-gw.localtest.me
  parentRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: gateway
    namespace: gateway-ingress
  rules:
  - backendRefs:
    - name: podinfo-primary
      port: 9898
      weight: 50
    - name: podinfo-canary
      port: 9898
      weight: 50
```

### 4) Final canary status snapshot

```text
NAME      STATUS        WEIGHT   FAILEDCHECKS   INTERVAL   STEPWEIGHT   MAXWEIGHT
podinfo   Progressing   50       0              30s        10           50
```

## Conclusion

Yes, **Gateway API works with Flagger** in this EKS test.

- Flagger created and managed `HTTPRoute`.
- Flagger changed backend weights incrementally according to canary strategy.
- No provider-specific incompatibility was observed in this scenario (different from the F5 ingress host-collision evidence in the Ingress test).

