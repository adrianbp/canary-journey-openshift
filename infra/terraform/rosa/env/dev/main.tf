module "rosa" {
  source = "../.."

  aws_region           = var.aws_region
  cluster_name         = var.cluster_name
  rosa_version         = var.rosa_version
  availability_zones   = var.availability_zones
  machine_cidr         = var.machine_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  compute_machine_type = var.compute_machine_type
  compute_nodes        = var.compute_nodes
  hosted_cp            = var.hosted_cp
  create_account_roles = var.create_account_roles
  create_oidc_config   = var.create_oidc_config
  tags                 = var.tags
}
