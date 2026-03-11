# RUNBOOK - CanaryRollout (Operação Simplificada)

## Objetivo
Executar canary com o menor número de passos, mantendo segurança e governança.

## Modelo simplificado
- 1 CRD por cluster: `CanaryRollout`
- 1 controller por namespace/cluster
- 1 CR fixo por app/ambiente (não criar CR por step)

## Responsabilidades
- Pipeline: `ENABLE` e `DISABLE`
- Painel de governança: `ADVANCE_STEP`, `PROMOTE`, `ROLLBACK`
- Ambos: sempre esperar gate (`wait-canaryrollout.sh`)

## Pré-check rápido
```bash
export NS=team-a
export APP=payments-api

oc project "$NS"
oc -n "$NS" get canaryrollout "$APP"
oc -n "$NS" get deploy canaryrollout-controller
```

## Comandos operacionais
### 1) ENABLE (pipeline)
```bash
oc -n "$NS" patch canaryrollout "$APP" --type=merge -p \
'{"spec":{"action":"ENABLE","approval":{"required":true,"state":"APPROVED"}}}'

infra/openshift/canaryrollout/controller/wait-canaryrollout.sh "$NS" "$APP" 900 10
```

### 2) ADVANCE_STEP (governança)
```bash
oc -n "$NS" patch canaryrollout "$APP" --type=merge -p \
'{"spec":{"action":"ADVANCE_STEP","stepName":"step-25","approval":{"required":true,"state":"APPROVED"}}}'

infra/openshift/canaryrollout/controller/wait-canaryrollout.sh "$NS" "$APP" 900 10
```

### 3) PROMOTE (governança)
```bash
oc -n "$NS" patch canaryrollout "$APP" --type=merge -p \
'{"spec":{"action":"PROMOTE","approval":{"required":true,"state":"APPROVED"}}}'

infra/openshift/canaryrollout/controller/wait-canaryrollout.sh "$NS" "$APP" 900 10
```

### 4) ROLLBACK (governança)
```bash
oc -n "$NS" patch canaryrollout "$APP" --type=merge -p \
'{"spec":{"action":"ROLLBACK","approval":{"required":true,"state":"APPROVED"}}}'

infra/openshift/canaryrollout/controller/wait-canaryrollout.sh "$NS" "$APP" 900 10
```

### 5) DISABLE (pipeline)
```bash
oc -n "$NS" patch canaryrollout "$APP" --type=merge -p \
'{"spec":{"action":"DISABLE","approval":{"required":true,"state":"APPROVED"}}}'

infra/openshift/canaryrollout/controller/wait-canaryrollout.sh "$NS" "$APP" 900 10
```

## Gate de sucesso (regra padrão)
Sucesso só quando:
- `status.observedGeneration == metadata.generation`
- `status.phase == Succeeded`

Falha quando:
- `status.phase == Failed`

## Validação rápida de status
```bash
oc -n "$NS" get canaryrollout "$APP" -o yaml | sed -n '1,220p'
oc -n "$NS" get events --sort-by=.lastTimestamp | grep -i canaryrollout
oc -n "$NS" logs deploy/canaryrollout-controller --tail=100
```

## Troubleshooting curto
- `WaitingApproval`: patch em `spec.approval.state=APPROVED`
- `PlanNotFound`: validar ConfigMap `<app>-rollout-plan` e `rollout-steps.yaml`
- `Failed`: ver `status.message` + logs do controller
- Sem mudança de tráfego: validar Route e Services do app/primary

## Padrão recomendado para empresa
- Helm garante objeto base
- Pipeline só `ENABLE`/`DISABLE`
- Governança decide progressão e promoção
- Gate obrigatório em todas as ações
