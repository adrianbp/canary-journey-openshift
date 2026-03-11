# Plano de Migração: Controller Atual -> Operator (OpenShift e Kubernetes)

## Objetivo
Evoluir o controller shell-based atual para um Operator distribuível, versionado e escalável, preservando o modelo `CanaryRollout` e permitindo adoção futura em Kubernetes além de OpenShift.

## Princípios
- Não quebrar o piloto atual.
- Reutilizar CRD e semântica de ações já validadas.
- Separar lógica de negócio de detalhes de plataforma (Route vs Ingress).

## Estado atual
- CRD `CanaryRollout` já definido e funcional.
- Controller MVP executa ações: `ENABLE`, `ADVANCE_STEP`, `PROMOTE`, `ROLLBACK`, `DISABLE`.
- Fluxo operacional já validável com pipeline gate (`wait-canaryrollout.sh`).

## Estratégia por fases

## Fase 1 - Hardening do MVP (OpenShift)
Objetivo: estabilizar antes da migração para Operator Go.

Entregas:
1. Congelar contrato do CRD `v1alpha1`.
2. Adicionar testes de regressão E2E no fluxo atual.
3. Consolidar runbook + decision log + critérios de sucesso em DEV.
4. Fechar decisões de governança pendentes (ownership de steps e critérios de promoção).

Saída esperada:
- baseline funcional estável para portar para Operator.

## Fase 2 - Operator OpenShift (primeiro alvo)
Objetivo: substituir controller shell por Operator Go com lifecycle gerenciável.

Tecnologia recomendada:
- Kubebuilder + controller-runtime (Go)
- Bundle para OLM no OpenShift (CSV/Package/Channel)

Entregas:
1. Projeto Operator com reconciliação do `CanaryRollout`.
2. Reconcile idempotente com `status.conditions` e `observedGeneration`.
3. Execução das ações por módulos internos (sem shell scripts como core).
4. Emissão de Events Kubernetes/OpenShift.
5. Packaging OLM para instalação/upgrade controlados.
6. Migração gradual: rodar em paralelo com feature flag e cutover por namespace.

Saída esperada:
- instalação simplificada e padronizada em OpenShift via OLM.

## Fase 3 - Expansão Kubernetes (EKS/AKS/on-prem)
Objetivo: manter mesmo CRD e trocar apenas adaptador de tráfego.

Abordagem:
- `TrafficAdapter` interface:
  - `OpenShiftRouteAdapter`
  - `KubernetesIngressAdapter` (NGINX inicialmente)

Entregas:
1. Adapter Ingress para canary weights/anotações.
2. Helm chart genérico de instalação do Operator fora de OLM.
3. Matriz de compatibilidade por cluster/provider.
4. Testes conformance em EKS/AKS.

Saída esperada:
- mesma UX de CR para OpenShift e Kubernetes.

## Arquitetura alvo (resumo)
- API: `CanaryRollout` (mesmo contrato lógico)
- Core: state machine + validation + gates
- Adapter de tráfego por plataforma
- Integrações opcionais: aprovação, notificações, métricas

## Instalação e distribuição

OpenShift (recomendado):
1. Publicar bundle do Operator em catálogo OLM.
2. Instalar via Subscription por canal (`alpha`, `beta`, `stable`).
3. Upgrade controlado por política do OLM.

Kubernetes genérico:
1. Distribuir via Helm chart do Operator.
2. CRD versionado + Deployment + RBAC.
3. Upgrade por chart version (sem OLM).

## Vantagens do Operator para distribuição
- Instalação única padronizada por cluster.
- Upgrade/versionamento centralizados.
- RBAC/CRD/controller empacotados.
- Menor risco de drift operacional.
- Melhor governança para múltiplos times e clusters.

## Riscos e mitigação
1. Mudança de engine shell -> Go pode introduzir regressão.
- Mitigação: testes E2E com mesmos cenários do MVP.

2. Diferença OpenShift Route vs Ingress.
- Mitigação: camada adapter com testes por plataforma.

3. Adoção em times com maturidade diferente.
- Mitigação: rollout por ondas e canais de release do Operator.

## Critérios de prontidão para migrar da Fase 1 para Fase 2
- Piloto DEV aprovado.
- Ownership de steps definido.
- SLOs de rollout definidos.
- Sem incidentes críticos abertos do MVP.

## Cronograma sugerido (alto nível)
- Semanas 1-2: Fase 1 (hardening)
- Semanas 3-6: Fase 2 (Operator OpenShift)
- Semanas 7-10: Fase 3 (Kubernetes adapters + rollout EKS/AKS)

## Recomendação final
- Continuar piloto com controller atual para aprender rápido.
- Iniciar em paralelo design do Operator Go já com foco em OLM.
- Tratar OpenShift como trilha principal e Kubernetes como extensão natural do mesmo CRD.
