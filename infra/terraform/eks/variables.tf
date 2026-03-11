variable "aws_region" {
  description = "AWS region for EKS"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.90.0.0/16"
}

variable "private_subnets" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = ["10.90.1.0/24", "10.90.2.0/24", "10.90.3.0/24"]
}

variable "public_subnets" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.90.101.0/24", "10.90.102.0/24", "10.90.103.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway"
  type        = bool
  default     = true
}

variable "node_instance_types" {
  description = "Worker node instance types"
  type        = list(string)
  default     = ["m5.large"]
}

variable "node_min_size" {
  description = "Minimum node count"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum node count"
  type        = number
  default     = 5
}

variable "node_desired_size" {
  description = "Desired node count"
  type        = number
  default     = 3
}

variable "observability_namespace" {
  description = "Namespace for canary observability app"
  type        = string
  default     = "canary-observability"
}

variable "service_account_name" {
  description = "Service account used by canary status reader"
  type        = string
  default     = "canary-status-reader"
}

variable "deploy_status_api" {
  description = "Deploy placeholder canary status API app"
  type        = bool
  default     = true
}

variable "status_api_image" {
  description = "Image for canary status API"
  type        = string
  default     = "ghcr.io/company/canary-status-api:latest"
}

variable "status_api_replicas" {
  description = "Replicas for status API"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
