output "cluster_name" {
  value = module.rosa.cluster_name
}

output "vpc_id" {
  value = module.rosa.vpc_id
}

output "create_command" {
  value = module.rosa.cluster_create_command
}
