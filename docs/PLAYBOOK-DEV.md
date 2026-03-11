# Playbook para Devs - CanaryRollout

## Resposta curta sobre rollout plan
Usar **os dois**:
- `rollout-steps.yaml` no Git = **fonte de verdade** (versionado, revisável, auditável)
- `<app>-rollout-plan` (ConfigMap) no cluster = **fonte operacional** consumida pelo controller

Fluxo recomendado:
1. Dev altera `rollout-steps.yaml` no repo (via PR).
2. Helm aplica/atualiza ConfigMap `<app>-rollout-plan`.
3. Controller lê o ConfigMap para executar `ADVANCE_STEP`/`ROLLBACK`.

## Decisão pendente (importante)
O ownership de `ADVANCE_STEP`/`PROMOTE`/`ROLLBACK` ainda está **TBD**.
Até essa decisão, este playbook cobre principalmente:
- manutenção do plano (`rollout-steps.yaml`)
- validação técnica do plano antes de merge

## O que o dev pode fazer no dia a dia (se aplicável pela política)
1. Manter plano de rollout por app/ambiente (`dev/stg/prod`).
2. Garantir que os nomes do plano batem com o app real:
- `appName`
- `stableDeployment` (`<app>-primary`)
- `canaryDeployment` (`<app>`)
- `stableService` / `canaryService`
- `routeName`
3. Validar pesos e steps antes de merge.

## Onde editar
- Plano no cluster/repo:
  - `infra/openshift/route-automation/plans/<app>/<env>/rollout-steps.yaml`
- Values do chart canary:
  - `infra/helm-values/canary-addon/<app>/<env>/values.yaml`

## Checklist de PR (dev)
- Steps existem e estão em ordem (ex.: `step-10`, `step-25`, `step-50`, `step-100-canary`).
- Pesos por step somam 100 (`stableWeight + canaryWeight`).
- `canaryReplicas` consistente (`auto` ou número válido).
- `minCanaryReplicas` e `safetyExtraReplicas` condizem com risco do serviço.
- Não alterou nomes base (`<app>` e `<app>-primary`) sem alinhar plataforma.

## Ações que podem ficar fora do escopo do dev (conforme decisão final)
- `ENABLE`/`DISABLE` de canary no pipeline.
- Operação de aprovação/execução (`ADVANCE_STEP`, `PROMOTE`, `ROLLBACK`, gates formais), caso a política fique centralizada.
- Operação do controller/RBAC.

## Comandos úteis
Validar plano localmente:
```bash
infra/openshift/route-automation/validate-plan.sh infra/openshift/route-automation/plans/payments-api/dev/rollout-steps.yaml
```

Ver status do canary no cluster:
```bash
oc -n team-a get canaryrollout payments-api -o yaml | sed -n '1,220p'
```

## Regra de ouro
- Plano no Git é a verdade de configuração.
- ConfigMap no cluster é a verdade de execução.
- Não editar ConfigMap manualmente em produção; sempre via esteira/Helm.
