# EKS Terraform Bootstrap (Canary Platform)

This stack creates an EKS cluster and baseline Kubernetes RBAC/resources for canary observability.

## What it creates
- VPC + subnets + NAT gateway
- EKS cluster + managed node group
- Namespace for observability (`canary-observability` by default)
- ServiceAccount with read-only ClusterRole for:
  - Flagger canaries
  - NGINX ingress resources
  - Deployments/ReplicaSets
  - Core resources (services/endpoints/pods/events)
- Optional placeholder app deployment (`canary-status-api`)

## Quick Start (dev)
```bash
cd infra/terraform/eks/env/dev
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## After apply
Use output command to configure kubectl:
```bash
aws eks update-kubeconfig --region <region> --name <cluster_name>
```

## Destroy
```bash
cd infra/terraform/eks/env/dev
terraform destroy -var-file=terraform.tfvars
```
