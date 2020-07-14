data "aws_secretsmanager_secret_version" "internet_ingress" {
  secret_id = "/concourse/dataworks/internet-ingress"
}

locals {
  reverse_proxy_ssmenabled = {
    management-dev = "True"
    management     = "False"
  }

  reverse_proxy_enabled = {
    management-dev = true
    management     = false
  }

  ssh_bastion_enabled = {
    management-dev = true
    management     = true
  }

  ssh_bastion_users              = jsondecode(data.aws_secretsmanager_secret_version.internet_ingress.secret_binary)["ssh_bastion_users"]
  ssh_bastion_whitelisted_ranges = jsondecode(data.aws_secretsmanager_secret_version.internet_ingress.secret_binary)["ssh_bastion_whitelisted_ranges"]
}
