variable "cluster_name" {
  type = string
}

variable "machine_cidr" {
  type = string
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}
