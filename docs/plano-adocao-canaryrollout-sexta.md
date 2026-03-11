# Plano de Adoção CanaryRollout (Apresentação de Sexta)

## Objetivo
Validar em `DEV` a estratégia de canary com `CanaryRollout` (OpenShift Route + Deployment) e evoluir de forma segura para `STG` e `PRD`.

## Resumo Executivo
- Modelo: canary declarativo via CR (`CanaryRollout`), sem trocar `Deployment` por objeto proprietário.
- Tráfego: OpenShift `Route` com pesos (stable/canary).
- Controle: controller MVP executa ações (`ENABLE`, `ADVANCE_STEP`, `PROMOTE`, `ROLLBACK`, `DISABLE`).
- Governança: gate de pipeline aguardando `status.phase=Succeeded`.

Decisão pendente:
- ownership de `ADVANCE_STEP`/`PROMOTE`/`ROLLBACK` está **TBD** (governança central vs times de app).

## Escopo da fase DEV
1. Instalar CRD e controller no cluster DEV.
2. Selecionar 1 serviço piloto (`payments-api` ou equivalente).
3. Executar fluxo completo:
- `ENABLE`
- `ADVANCE_STEP` (10/25/50)
- `PROMOTE`
- `DISABLE`
4. Validar rollback manual (`ROLLBACK`) em cenário de teste.
5. Medir tempo total, falhas e aderência operacional.

## Critérios de sucesso (DEV)
- 100% dos comandos do fluxo executados via CR (sem intervenção manual em Route).
- Pipeline bloqueia corretamente até CR concluir.
- Rollback funciona em menos de X minutos (definir com time).
- Sem indisponibilidade percebida no serviço piloto.
- Evidência de auditoria em `status` do CR e `Events` do OpenShift.

## Pré-requisitos por ambiente
- Namespace do app existente.
- App baseline com `Deployment`, `Service` e `Route`.
- Rollout plan em ConfigMap (`<app>-rollout-plan`).
- Permissões RBAC do controller.
- Pipeline com `wait-canaryrollout.sh` configurado.

## Estratégia por ondas
### Onda 1: DEV (1-2 apps)
- Foco: estabilidade da automação e operação diária.
- Duração sugerida: 1-2 semanas.
- Entregável: playbook validado + incidentes conhecidos.

### Onda 2: STG (2-4 apps)
- Foco: comportamento próximo de produção (carga e latência realistas).
- Adicionar gates de mudança e checklist de release.
- Duração sugerida: 1-2 semanas.

### Onda 3: PRD (incremental)
- Foco: rollout progressivo com janela controlada.
- Começar com 1 app de risco moderado.
- Expandir após 2-3 ciclos estáveis.

## RACI simplificado
- Plataforma/SRE: operar controller, RBAC, observabilidade.
- Times de aplicação: manter planos por app/env.
- Release management: autorizar ações críticas conforme política.
- Owner de `ADVANCE_STEP`/`PROMOTE`/`ROLLBACK`: TBD (definir na reunião).

## Riscos e mitigação
- Drift de objetos (`-primary`) vs Helm:
  - Mitigação: ownership fixo (Helm config-only; controller/scripts runtime).
- Plano de steps inválido:
  - Mitigação: validação de plan + revisão por app.
- Timeout de gate no pipeline:
  - Mitigação: timeout por ambiente e troubleshooting padronizado.
- Falhas de permissão:
  - Mitigação: checklist RBAC antes de habilitar app.

## Plano de execução (sexta)
1. Contexto: problema atual e objetivo.
2. Demo técnica curta (DEV):
- aplicar `ENABLE`
- aguardar gate
- aplicar `ADVANCE_STEP`
- mostrar status/events
3. Discussão de governança:
- quem aprova cada ação
- critérios para `PROMOTE` e `ROLLBACK`
 - decisão de ownership dos steps (`ADVANCE_STEP`/`PROMOTE`/`ROLLBACK`)
4. Decisão de piloto:
- app inicial
- janela de teste
- responsáveis

## Próximos passos após a reunião
1. Fechar app piloto e cronograma DEV.
2. Configurar pipeline do app com gate por CR.
3. Rodar primeiro ciclo completo com acompanhamento.
4. Consolidar lições aprendidas e preparar onda STG.

## Referências
- Quickstart E2E: `docs/quickstart-openshift-canaryrollout.md`
- Pipeline gates: `docs/canaryrollout-pipeline-gates.md`
- CRD design: `docs/openshift-canaryrollout-crd-phase1.md`
