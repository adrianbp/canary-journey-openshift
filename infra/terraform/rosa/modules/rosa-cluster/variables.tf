variable "cluster_name" {
  type = string
}

variable "rosa_version" {
  type = string
}

variable "compute_machine_type" {
  type = string
}

variable "compute_nodes" {
  type = number
}

variable "hosted_cp" {
  type = bool
}

variable "region" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}
