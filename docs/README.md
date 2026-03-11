# Canary Platform Bootstrap

## Modules
- `services/approval-api`: Approval state machine + audit + ServiceNow stub.
- `services/manual-gate-webhook`: Flagger manual hook responder.
- `services/shared-contracts`: Shared enums and DTOs.

## APIs
### Approval API
- `POST /v1/approvals`
- `GET /v1/approvals/{id}`
- `POST /v1/approvals/{id}/approve`
- `POST /v1/approvals/{id}/reject`
- `POST /v1/approvals/resolve`

### Manual Gate Webhook
- `POST /v1/flagger/hooks/manual-gate`
- `POST /v1/flagger/hooks/manual-rollback`

Status mapping:
- `200`: approved
- `409`: pending
- `412`: rejected/expired

## Local Run
1. Start dependencies: `docker compose -f infra/docker-compose/docker-compose.yml up -d`
2. Run approval API: `mvn -pl services/approval-api spring-boot:run`
3. Run webhook: `mvn -pl services/manual-gate-webhook spring-boot:run`

## Verify
- Full build: `mvn -T 1C clean verify`
- Lint charts:
  - `helm lint charts/platform-canary-core`
  - `helm lint charts/canary-library`

## Additional Design Docs
- Notifications architecture (Slack/Teams):
  - `/Users/adrianobenignopavao/Documents/New project/docs/canary-notifications-architecture.md`
- Unified OpenShift + Kubernetes architecture (Route/Ingress adapter):
  - `/Users/adrianobenignopavao/Documents/New project/docs/canary-unified-architecture-openshift-k8s.md`

## Release Management Modes
- Pause Flagger reconciliation (temporary freeze):
  - `helm upgrade --install payments-canary charts/canary-library --set canary.suspend=true`
- Keep Flagger object but bypass canary analysis (behave closer to regular rollout):
  - `helm upgrade --install payments-canary charts/canary-library --set canary.skipAnalysis=true`
- Disable canary CR and rely on regular Helm rolling update strategy:
  - `helm upgrade --install payments-canary charts/canary-library --set canary.enabled=false`

Recommended practice:
- Use `canary.suspend=true` for short freeze windows.
- Use `canary.enabled=false` only when release management explicitly chooses standard rolling updates.
