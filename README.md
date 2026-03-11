# Canary Platform Monorepo

This repository contains a Java/Spring Boot implementation scaffold for Flagger manual canary approvals on EKS.

## Modules
- `services/shared-contracts`
- `services/approval-api`
- `services/manual-gate-webhook`
- `charts/platform-canary-core`
- `charts/canary-library`

## Build
`mvn -T 1C clean verify`
