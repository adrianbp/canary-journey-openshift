# Arquitetura de Solução Alvo

## Objetivo
Desenhar o estado desejado para canary corporativo com:
- Operator
- CR (`CanaryRollout`) distribuído por Helm
- Portal de Governança
- integração com pipeline, observabilidade e auditoria

## Visão macro
```mermaid
flowchart LR
  Dev["Time de App"] --> Git["Git Repo\n(app + values + plano)"]
  Git --> CI["CI/CD Pipeline"]

  CI --> Helm["Helm Deploy"]
  Helm --> Cluster["Cluster OpenShift/K8s"]

  subgraph Cluster
    CRD["CRD CanaryRollout"]
    CR["CR CanaryRollout\n1 por app/env"]
    OP["Canary Operator"]
    APP["Deployment/Service app"]
    PRIM["Deployment/Service app-primary"]
    TRAF["Route/Ingress Adapter"]
  end

  Helm --> CR
  OP --> CR
  OP --> APP
  OP --> PRIM
  OP --> TRAF

  Gov["Portal de Governança"] --> API["Governance API"]
  API --> CR

  Obs["Dynatrace/Prometheus"] --> OP
  OP --> MQ["Event Bus"]
  MQ --> Notif["Slack/Teams"]
  OP --> Audit[("PostgreSQL Audit")]

  Users["Usuários"] --> TRAF
```

## Princípios de ownership
- Helm:
  - mantém baseline do app
  - cria/atualiza o CR `CanaryRollout`
- Operator:
  - reconcilia ações (`ENABLE`, `ADVANCE_STEP`, `PROMOTE`, `ROLLBACK`, `DISABLE`)
  - gerencia lifecycle de `-primary` e pesos de tráfego
- Portal:
  - aprovações e progressão (ownership de steps = política da empresa)

## Fluxo de controle (alto nível)
```mermaid
sequenceDiagram
  participant CI as Pipeline
  participant H as Helm
  participant CR as CanaryRollout CR
  participant OP as Operator
  participant GOV as Portal/API

  CI->>H: deploy app + CR base
  H->>CR: apply/upgrade

  CI->>CR: patch action=ENABLE
  OP->>OP: reconcile ENABLE
  OP-->>CR: status Succeeded
  CI->>CI: gate (wait status)

  GOV->>CR: patch action=ADVANCE_STEP
  OP->>OP: scale + shift traffic
  OP-->>CR: status Succeeded/Failed

  GOV->>CR: patch action=PROMOTE
  OP->>OP: sync canary -> primary
  OP-->>CR: status Succeeded

  CI->>CR: patch action=DISABLE (quando aplicável)
  OP->>OP: return to single deployment
  OP-->>CR: status Succeeded
```

## Topologia multi-cluster
```mermaid
flowchart TB
  Portal["Portal de Governança"] --> ControlAPI["Governance API"]

  ControlAPI --> C1["Cluster DEV"]
  ControlAPI --> C2["Cluster STG"]
  ControlAPI --> C3["Cluster PRD"]

  subgraph C1[Cluster DEV]
    OP1[Operator]
    CR1[CanaryRollout CRs]
  end

  subgraph C2[Cluster STG]
    OP2[Operator]
    CR2[CanaryRollout CRs]
  end

  subgraph C3[Cluster PRD]
    OP3[Operator]
    CR3[CanaryRollout CRs]
  end
```

## Contrato operacional
- 1 CR por app/ambiente
- pipeline usa gate obrigatório por status do CR
- steps/progressão controlados por política (`TBD` em decisão de governança)

## Caminho de implementação
1. OpenShift primeiro (Route adapter + OLM opcional)
2. estabilização de processo em DEV/STG
3. expansão para Kubernetes (Ingress adapter) mantendo mesmo CR
