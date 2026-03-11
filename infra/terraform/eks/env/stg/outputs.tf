output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "kubectl_update_kubeconfig" {
  value = module.eks.kubectl_update_kubeconfig
}

output "service_account_name" {
  value = module.eks.service_account_name
}

output "observability_namespace" {
  value = module.eks.observability_namespace
}
