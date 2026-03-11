data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az_count = max(length(var.private_subnets), length(var.public_subnets))
  azs      = slice(data.aws_availability_zones.available.names, 0, local.az_count)

  common_tags = merge(
    {
      project    = "canary-platform"
      managed_by = "terraform"
    },
    var.tags
  )
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.common_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
    }
  }

  tags = local.common_tags
}

resource "kubernetes_namespace" "observability" {
  metadata {
    name = var.observability_namespace
    labels = {
      "app.kubernetes.io/part-of" = "canary-platform"
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_service_account" "canary_status_reader" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "canary-status-api"
    }
  }
}

resource "kubernetes_cluster_role" "canary_status_reader" {
  metadata {
    name = "${var.cluster_name}-canary-status-reader"
  }

  rule {
    api_groups = ["flagger.app"]
    resources  = ["canaries"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses", "ingressclasses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["services", "endpoints", "pods", "namespaces", "events"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "canary_status_reader" {
  metadata {
    name = "${var.cluster_name}-canary-status-reader-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.canary_status_reader.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.canary_status_reader.metadata[0].name
    namespace = kubernetes_service_account.canary_status_reader.metadata[0].namespace
  }
}

resource "kubernetes_deployment" "canary_status_api" {
  count = var.deploy_status_api ? 1 : 0

  metadata {
    name      = "canary-status-api"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels = {
      app = "canary-status-api"
    }
  }

  spec {
    replicas = var.status_api_replicas

    selector {
      match_labels = {
        app = "canary-status-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "canary-status-api"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.canary_status_reader.metadata[0].name

        container {
          name  = "api"
          image = var.status_api_image

          port {
            container_port = 8080
          }

          env {
            name  = "LOG_LEVEL"
            value = "INFO"
          }

          env {
            name  = "CANARY_NAMESPACE_SELECTOR"
            value = "*"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_cluster_role_binding.canary_status_reader]
}

resource "kubernetes_service" "canary_status_api" {
  count = var.deploy_status_api ? 1 : 0

  metadata {
    name      = "canary-status-api"
    namespace = kubernetes_namespace.observability.metadata[0].name
  }

  spec {
    selector = {
      app = "canary-status-api"
    }

    port {
      port        = 80
      target_port = 8080
    }

    type = "ClusterIP"
  }
}
