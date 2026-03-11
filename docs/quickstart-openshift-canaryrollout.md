# Quickstart: CanaryRollout no OpenShift (E2E)

Este guia valida o fluxo completo no cluster local/POC:
1. Instalar CRD
2. Publicar imagem do controller
3. Deploy do controller (RBAC + Deployment)
4. Aplicar `CanaryRollout` e validar status/events

## 0) Pré-requisitos
- `oc` autenticado no cluster.
- Projeto alvo existente (exemplo: `team-a`).
- Aplicação baseline já criada no namespace:
  - `Deployment` e `Service` com nome `<app>` (ex: `payments-api`)
  - `Route` com nome `<app>` (ex: `payments-api`)
- `jq`, `docker` instalados na máquina local.

## 1) Ajustar namespace e app
Defina variáveis para evitar erro de contexto:

```bash
export NS=team-a
export APP=payments-api
oc project "$NS"
```

## 2) Instalar CRD
```bash
oc apply -f infra/openshift/canaryrollout/crd/canaryrollouts.canary.company.io.yaml
oc get crd canaryrollouts.canary.company.io
```

## 3) Publicar imagem do controller
### Opção A: local
```bash
export IMAGE_REPO=ghcr.io/<seu-user>/canaryrollout-controller
export IMAGE_TAG=0.1.0
infra/openshift/canaryrollout/controller/build-image.sh
docker push ${IMAGE_REPO}:${IMAGE_TAG}
```

### Opção B: GitHub Actions
- Execute workflow `.github/workflows/build-canaryrollout-controller-image.yml`
- Informe `image_tag` (exemplo: `0.1.0`)

## 4) Configurar Deployment do controller
Atualize a imagem no arquivo abaixo para o valor publicado:
- `infra/openshift/canaryrollout/controller/deployment.yaml`

Exemplo de imagem:
- `ghcr.io/<seu-user>/canaryrollout-controller:0.1.0`

## 5) Aplicar RBAC e Deployment
```bash
oc apply -f infra/openshift/canaryrollout/controller/rbac.yaml
oc apply -f infra/openshift/canaryrollout/controller/deployment.yaml
```

Checar pod:
```bash
oc -n "$NS" get pods -l app.kubernetes.io/name=canaryrollout-controller
oc -n "$NS" logs deploy/canaryrollout-controller --tail=100
```

## 6) Garantir rollout plan em ConfigMap
O controller lê os steps do ConfigMap `<app>-rollout-plan` chave `rollout-steps.yaml`.

Se você já aplicou o chart `canary-addon`, esse ConfigMap já existe.
Valide:
```bash
oc -n "$NS" get configmap ${APP}-rollout-plan -o yaml | head -n 40
```

## 7) Rodar fluxo E2E com CRs
Os manifests de exemplo estão em:
- `infra/openshift/canaryrollout/examples/`

### 7.1 Enable canary
```bash
oc apply -f infra/openshift/canaryrollout/examples/payments-api-enable.yaml
oc -n "$NS" get canaryrollout ${APP} -o yaml | sed -n '1,220p'
```

### 7.2 Advance step (ex: 25%)
```bash
oc apply -f infra/openshift/canaryrollout/examples/payments-api-advance-step.yaml
oc -n "$NS" get canaryrollout ${APP} -o yaml | sed -n '1,220p'
```

### 7.3 Promote
```bash
oc apply -f infra/openshift/canaryrollout/examples/payments-api-promote.yaml
oc -n "$NS" get canaryrollout ${APP} -o yaml | sed -n '1,220p'
```

### 7.4 Rollback (teste opcional)
```bash
oc apply -f infra/openshift/canaryrollout/examples/payments-api-rollback.yaml
oc -n "$NS" get canaryrollout ${APP} -o yaml | sed -n '1,220p'
```

### 7.5 Disable canary
```bash
oc apply -f infra/openshift/canaryrollout/examples/payments-api-disable.yaml
oc -n "$NS" get canaryrollout ${APP} -o yaml | sed -n '1,220p'
```

## 8) Observabilidade e auditoria
Status resumido:
```bash
oc -n "$NS" get canaryrollouts
```

Eventos emitidos pelo controller:
```bash
oc -n "$NS" get events --sort-by=.lastTimestamp | grep -i canaryrollout
```

Logs do controller:
```bash
oc -n "$NS" logs deploy/canaryrollout-controller -f
```

## 9) Troubleshooting rápido
- `WaitingApproval`: ajustar `spec.approval.state=APPROVED` no CR.
- `PlanNotFound`: conferir ConfigMap `<app>-rollout-plan` e chave `rollout-steps.yaml`.
- `...Failed` com erro de script: revisar logs do controller e permissões RBAC.
- Sem mudanças de tráfego: validar existência da `Route` e nomes de `Service` no plano.
