# CanaryRollout Pipeline Gates (GitHub Actions + Jenkins)

Este documento entrega snippets prontos para seu pipeline validar ações no CR `CanaryRollout`.

## Regras de gate
Após aplicar/atualizar o CR no pipeline:
- Sucesso apenas quando:
  - `status.observedGeneration == metadata.generation`
  - `status.phase == Succeeded`
- Falha imediata se `status.phase == Failed`
- Timeout configurável (ex.: 15 min)

Script utilitário usado nos exemplos:
- `infra/openshift/canaryrollout/controller/wait-canaryrollout.sh`

## GitHub Actions (exemplo)
```yaml
name: Deploy With CanaryRollout Gate

on:
  workflow_dispatch:
    inputs:
      namespace:
        required: true
        default: team-a
      app_name:
        required: true
        default: payments-api
      canary_action:
        required: true
        type: choice
        options: [ENABLE, DISABLE]
        default: ENABLE

jobs:
  deploy:
    runs-on: ubuntu-latest
    env:
      NS: ${{ inputs.namespace }}
      APP: ${{ inputs.app_name }}
      ACTION: ${{ inputs.canary_action }}
    steps:
      - uses: actions/checkout@v4

      - uses: redhat-actions/oc-installer@v1

      - name: Login OpenShift
        shell: bash
        env:
          OPENSHIFT_API_URL: ${{ secrets.OPENSHIFT_API_URL }}
          OPENSHIFT_TOKEN: ${{ secrets.OPENSHIFT_TOKEN }}
        run: |
          set -euo pipefail
          oc login "$OPENSHIFT_API_URL" --token="$OPENSHIFT_TOKEN" --insecure-skip-tls-verify=true
          oc project "$NS"

      - name: Apply CanaryRollout action
        shell: bash
        run: |
          set -euo pipefail
          oc -n "$NS" patch canaryrollout "$APP" --type=merge -p "{\"spec\":{\"action\":\"$ACTION\",\"approval\":{\"required\":true,\"state\":\"APPROVED\"}}}"

      - name: Wait for CanaryRollout gate
        shell: bash
        run: |
          set -euo pipefail
          infra/openshift/canaryrollout/controller/wait-canaryrollout.sh "$NS" "$APP" 900 10

      - name: Continue deployment step
        shell: bash
        run: |
          set -euo pipefail
          echo "Canary gate passed. Continue deploy..."
          # helm upgrade / deploy logic aqui
```

## Jenkins Pipeline (exemplo)
```groovy
pipeline {
  agent any

  parameters {
    string(name: 'NAMESPACE', defaultValue: 'team-a', description: 'OpenShift namespace')
    string(name: 'APP_NAME', defaultValue: 'payments-api', description: 'App/CanaryRollout name')
    choice(name: 'CANARY_ACTION', choices: ['ENABLE', 'DISABLE'], description: 'Canary action')
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Login OpenShift') {
      steps {
        sh '''
          set -euo pipefail
          oc login "$OPENSHIFT_API_URL" --token="$OPENSHIFT_TOKEN" --insecure-skip-tls-verify=true
          oc project "$NAMESPACE"
        '''
      }
    }

    stage('Apply CanaryRollout') {
      steps {
        sh '''
          set -euo pipefail
          oc -n "$NAMESPACE" patch canaryrollout "$APP_NAME" --type=merge -p "{\"spec\":{\"action\":\"$CANARY_ACTION\",\"approval\":{\"required\":true,\"state\":\"APPROVED\"}}}"
        '''
      }
    }

    stage('Gate - Wait CanaryRollout') {
      steps {
        sh '''
          set -euo pipefail
          infra/openshift/canaryrollout/controller/wait-canaryrollout.sh "$NAMESPACE" "$APP_NAME" 900 10
        '''
      }
    }

    stage('Deploy') {
      steps {
        sh '''
          set -euo pipefail
          echo "Canary gate passed. Continue deploy..."
          # helm upgrade / deploy logic aqui
        '''
      }
    }
  }
}
```

## Sequência recomendada no pipeline
1. Atualiza CR com `spec.action=ENABLE` e aprovação.
2. Aguarda gate (`wait-canaryrollout.sh`).
3. Executa deploy da nova versão.
4. Atualiza CR para steps/promoção (`ADVANCE_STEP`/`PROMOTE`) com gates entre etapas.
5. Quando necessário, atualiza CR para `DISABLE` e aguarda gate.

## Observação importante
Para múltiplos ambientes, mantenha timeout/poll por ambiente:
- DEV: timeout menor (ex.: 600s)
- STG/PRD: timeout maior (ex.: 1200s+)
