output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "EKS version"
  value       = module.eks.cluster_version
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnets"
  value       = module.vpc.private_subnets
}

output "kubectl_update_kubeconfig" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "observability_namespace" {
  description = "Namespace where status reader resources were created"
  value       = kubernetes_namespace.observability.metadata[0].name
}

output "service_account_name" {
  description = "Service account with read permissions for canary monitoring"
  value       = kubernetes_service_account.canary_status_reader.metadata[0].name
}
