# ROSA Terraform Bootstrap

This stack creates AWS network resources and orchestrates ROSA cluster creation via `rosa` CLI.

## Prerequisites
- AWS credentials configured (`aws sts get-caller-identity` works)
- Terraform >= 1.6
- ROSA CLI installed and logged in (`rosa login`)
- OpenShift pull secret available

## Layout
- `modules/network`: VPC, subnets, IGW, NAT, routing
- `modules/iam`: optional ROSA account roles + OIDC setup (CLI-based)
- `modules/rosa-cluster`: creates ROSA cluster using STS/auto mode

## Quick Start (dev)
```bash
cd infra/terraform/rosa/env/dev
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## After Apply
```bash
rosa describe cluster -c <cluster_name>
rosa create admin -c <cluster_name>
```

## Destroy
1. Delete ROSA cluster first:
```bash
rosa delete cluster -c <cluster_name> -y
```
2. Then destroy infra:
```bash
terraform destroy -var-file=terraform.tfvars
```
