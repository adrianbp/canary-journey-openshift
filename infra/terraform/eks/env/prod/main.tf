module "eks" {
  source = "../.."

  aws_region              = var.aws_region
  cluster_name            = var.cluster_name
  cluster_version         = var.cluster_version
  vpc_cidr                = var.vpc_cidr
  private_subnets         = var.private_subnets
  public_subnets          = var.public_subnets
  enable_nat_gateway      = var.enable_nat_gateway
  single_nat_gateway      = var.single_nat_gateway
  node_instance_types     = var.node_instance_types
  node_min_size           = var.node_min_size
  node_max_size           = var.node_max_size
  node_desired_size       = var.node_desired_size
  observability_namespace = var.observability_namespace
  service_account_name    = var.service_account_name
  deploy_status_api       = var.deploy_status_api
  status_api_image        = var.status_api_image
  status_api_replicas     = var.status_api_replicas
  tags                    = var.tags
}
