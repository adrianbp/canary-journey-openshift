resource "null_resource" "account_roles" {
  count = var.create_account_roles ? 1 : 0

  triggers = {
    cluster_name = var.cluster_name
    region       = var.region
  }

  provisioner "local-exec" {
    command = "rosa create account-roles --mode auto --yes"
  }
}

resource "null_resource" "oidc_config" {
  count = var.create_oidc_config ? 1 : 0

  triggers = {
    cluster_name = var.cluster_name
    region       = var.region
  }

  provisioner "local-exec" {
    command = "rosa create oidc-config --mode auto --yes"
  }

  depends_on = [null_resource.account_roles]
}
