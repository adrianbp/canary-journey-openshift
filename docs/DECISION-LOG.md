# Decision Log - CanaryRollout PoC A

## Objetivo
Registrar decisões técnicas já tomadas e decisões pendentes para o rollout canary em OpenShift.

## Como ler
- Status:
  - `DECIDED`: decisão fechada
  - `TBD`: decisão pendente
- Owner: responsável por fechar/executar

## Decisões

### DL-001 - Modelo de workload
- Status: `DECIDED`
- Decisão: manter `Deployment` como workload padrão (sem trocar para objeto proprietário de rollout).
- Contexto: alinhamento com padronização atual da empresa.
- Owner: Plataforma

### DL-002 - Tráfego canary em OpenShift
- Status: `DECIDED`
- Decisão: usar `Route` com pesos (`spec.to.weight` + `alternateBackends`).
- Owner: Plataforma

### DL-003 - Ownership de `-primary`
- Status: `DECIDED`
- Decisão: Helm não cria/gerencia `-primary`; lifecycle de `-primary` fica com scripts/controller.
- Owner: Plataforma

### DL-004 - Objeto declarativo de controle
- Status: `DECIDED`
- Decisão: usar CRD `CanaryRollout` (`canary.company.io/v1alpha1`).
- Owner: Plataforma

### DL-005 - Ações suportadas no CR
- Status: `DECIDED`
- Decisão: `ENABLE`, `ADVANCE_STEP`, `PROMOTE`, `ROLLBACK`, `DISABLE`.
- Owner: Plataforma

### DL-006 - Gate de pipeline
- Status: `DECIDED`
- Decisão: pipeline só segue quando `observedGeneration == generation` e `status.phase == Succeeded`; falha em `status.phase == Failed`.
- Owner: Plataforma + DevEx

### DL-007 - Source of truth do rollout plan
- Status: `DECIDED`
- Decisão:
  - Git (`rollout-steps.yaml`) = fonte de configuração
  - ConfigMap (`<app>-rollout-plan`) = fonte operacional de execução
- Owner: Plataforma + Times de app

### DL-008 - Escopo da esteira (pipeline)
- Status: `DECIDED`
- Decisão: esteira controla `ENABLE`/`DISABLE`; ações de progressão ficam fora do deploy padrão.
- Owner: Plataforma + Release

### DL-009 - Ownership de steps (`ADVANCE_STEP`/`PROMOTE`/`ROLLBACK`)
- Status: `TBD`
- Opções:
  1. Governança/plataforma central
  2. Time de app com aprovação obrigatória
  3. Modelo híbrido por criticidade
- Proposta para piloto DEV: centralizado temporariamente.
- Owner: Release Management + Arquitetura
- Deadline sugerido: antes de iniciar STG

### DL-010 - Critérios de promoção e rollback
- Status: `TBD`
- Decisão pendente:
  - thresholds mínimos (erro/latência)
  - janela mínima por step
  - quem aprova promoção final
- Owner: SRE + Release + Times de app

### DL-011 - Notificações externas (Slack/Teams)
- Status: `TBD`
- Estado atual: Events no OpenShift já implementados.
- Decisão pendente: worker externo (RabbitMQ + adapters) e padrão de mensagens.
- Owner: Plataforma Observabilidade

### DL-012 - Estratégia de adoção por ambiente
- Status: `DECIDED`
- Decisão: iniciar em DEV com app piloto, depois STG, depois PRD incremental.
- Owner: Plataforma + Release

## Próximas decisões da reunião de sexta
1. Fechar DL-009 (owner dos steps).
2. Fechar DL-010 (critérios formais de promote/rollback).
3. Confirmar app piloto + janela DEV + responsáveis.

## Referências
- `docs/plano-adocao-canaryrollout-sexta.md`
- `docs/RUNBOOK.md`
- `docs/canaryrollout-pipeline-gates.md`
- `docs/PLAYBOOK-DEV.md`
