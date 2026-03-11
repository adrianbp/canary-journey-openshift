variable "aws_region" {
  description = "AWS region where ROSA will run"
  type        = string
}

variable "cluster_name" {
  description = "ROSA cluster name"
  type        = string
}

variable "rosa_version" {
  description = "OpenShift version"
  type        = string
  default     = "4.15.16"
}

variable "machine_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.60.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = ["10.60.1.0/24", "10.60.2.0/24", "10.60.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.60.101.0/24", "10.60.102.0/24", "10.60.103.0/24"]
}

variable "availability_zones" {
  description = "AZs for subnets"
  type        = list(string)
}

variable "compute_machine_type" {
  description = "ROSA worker machine type"
  type        = string
  default     = "m5.xlarge"
}

variable "compute_nodes" {
  description = "Initial worker node count"
  type        = number
  default     = 3
}

variable "hosted_cp" {
  description = "Use hosted control planes"
  type        = bool
  default     = true
}

variable "create_account_roles" {
  description = "Create ROSA account roles via rosa CLI"
  type        = bool
  default     = true
}

variable "create_oidc_config" {
  description = "Create ROSA OIDC config via rosa CLI"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to AWS resources"
  type        = map(string)
  default     = {}
}
