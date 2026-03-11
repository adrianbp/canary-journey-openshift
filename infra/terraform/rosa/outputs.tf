output "vpc_id" {
  value       = module.network.vpc_id
  description = "VPC used by ROSA"
}

output "private_subnet_ids" {
  value       = module.network.private_subnet_ids
  description = "Private subnets used by ROSA"
}

output "cluster_name" {
  value       = var.cluster_name
  description = "ROSA cluster name"
}

output "cluster_create_command" {
  value       = module.rosa_cluster.cluster_create_command
  description = "Command used to create ROSA cluster"
}

output "cluster_status_command" {
  value       = "rosa describe cluster -c ${var.cluster_name}"
  description = "Command to check ROSA cluster status"
}

output "kubeconfig_command" {
  value       = "rosa create admin -c ${var.cluster_name}"
  description = "Command to generate cluster admin user"
}
