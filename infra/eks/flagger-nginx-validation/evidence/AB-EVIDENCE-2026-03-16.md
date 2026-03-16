# A/B Evidence - Flagger + Ingress Controllers (EKS)

Date: 2026-03-16 (America/Sao_Paulo)  
Cluster: `canary-eks-dev` (`us-east-1`)

## Scope

- **A**: Community `ingress-nginx` controller (`ingressClassName: nginx-community`)
- **B**: F5 NGINX Ingress OSS controller (`ingressClassName: nginx`)
- Flagger version observed in logs: `1.42.0`

## A) ingress-nginx (community)

### Final canary status (snapshot)

```text
NAME      STATUS        WEIGHT   FAILEDCHECKS   INTERVAL   STEPWEIGHT   MAXWEIGHT
podinfo   Progressing   10       3              30s        10           50
```

### Key events

```text
Normal  Synced  New revision detected! Scaling up podinfo.test-ab-a
Normal  Synced  Starting canary analysis for podinfo.test-ab-a
Normal  Synced  Advance podinfo.test-ab-a canary weight 10
Warning Synced  Halt advancement no values found for nginx metric request-success-rate ...
```

### Flagger log evidence

```text
... "msg":"Starting canary analysis for podinfo.test-ab-a" ...
... "msg":"Advance podinfo.test-ab-a canary weight 10" ...
... "msg":"Halt advancement no values found for nginx metric request-success-rate probably podinfo.test-ab-a is not receiving traffic: running query failed: no values found" ...
```

### Interpretation

- Controller integration path **works up to weight progression** (`0 -> 10`).
- Progress halts due to missing traffic series for `request-success-rate` in Prometheus query path.
- This indicates an **observability/metrics wiring issue**, not an ingress host collision.

---

## B) F5 NGINX Ingress OSS

### Final canary status (snapshot)

```text
NAME      STATUS   WEIGHT   FAILEDCHECKS   INTERVAL   STEPWEIGHT   MAXWEIGHT
podinfo   Failed   0        0              1m         10           50
```

### Key events

```text
Warning Rejected ingress/podinfo-canary  All hosts are taken by other resources
Normal  Synced   New revision detected! Scaling up podinfo.test
Warning Synced   canary deployment podinfo.test not ready ...
Warning Synced   Canary failed! Scaling down podinfo.test
```

### Interpretation

- Flagger (`provider: nginx`) attempts to create/manage a canary ingress resource.
- F5 controller rejects this because host ownership is exclusive in this shape (`podinfo-canary` vs existing host).
- Result: **default Flagger nginx-provider flow is not compatible out-of-the-box** with this F5 behavior.

---

## Consolidated Conclusion

- **A (community ingress-nginx): partial success**  
  Flagger progressed to weight `10`, proving control-plane compatibility; next blocker is metrics/traffic visibility.

- **B (F5 nginx OSS): failed for host collision in canary ingress model**  
  Evidence strongly supports that this path needs custom strategy (e.g. custom automation/controller) instead of stock Flagger `provider: nginx`.

