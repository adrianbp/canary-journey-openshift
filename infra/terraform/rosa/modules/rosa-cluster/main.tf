locals {
  subnet_arg = join(",", var.private_subnet_ids)
  hcp_flag   = var.hosted_cp ? "--hosted-cp" : ""
  create_cmd = "rosa create cluster --cluster-name ${var.cluster_name} --sts --mode auto --yes --version ${var.rosa_version} --region ${var.region} --compute-machine-type ${var.compute_machine_type} --replicas ${var.compute_nodes} --subnet-ids ${local.subnet_arg} ${local.hcp_flag}"
}

resource "null_resource" "cluster" {
  triggers = {
    cluster_name   = var.cluster_name
    rosa_version   = var.rosa_version
    machine_type   = var.compute_machine_type
    compute_nodes  = tostring(var.compute_nodes)
    hosted_cp      = tostring(var.hosted_cp)
    region         = var.region
    private_subnet = local.subnet_arg
  }

  provisioner "local-exec" {
    command = local.create_cmd
  }
}
