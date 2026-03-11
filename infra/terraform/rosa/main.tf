locals {
  common_tags = merge(
    {
      project     = "canary-platform"
      managed_by  = "terraform"
      environment = "dev"
    },
    var.tags
  )
}

module "network" {
  source = "./modules/network"

  cluster_name         = var.cluster_name
  machine_cidr         = var.machine_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  availability_zones   = var.availability_zones
  tags                 = local.common_tags
}

module "iam" {
  source = "./modules/iam"

  cluster_name         = var.cluster_name
  create_account_roles = var.create_account_roles
  create_oidc_config   = var.create_oidc_config
  region               = var.aws_region

  depends_on = [module.network]
}

module "rosa_cluster" {
  source = "./modules/rosa-cluster"

  cluster_name         = var.cluster_name
  rosa_version         = var.rosa_version
  compute_machine_type = var.compute_machine_type
  compute_nodes        = var.compute_nodes
  hosted_cp            = var.hosted_cp
  region               = var.aws_region
  private_subnet_ids   = module.network.private_subnet_ids

  depends_on = [module.iam]
}
