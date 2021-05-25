data "aws_secretsmanager_secret_version" "internet_ingress" {
  secret_id = "/concourse/dataworks/internet-ingress"
}

locals {
  mgmt_account_mapping = {
    management-dev = "development"
    management     = "production"
  }

  reverse_proxy_ssmenabled = {
    management-dev = "True"
    management     = "False"
  }

  reverse_proxy_enabled = {
    management-dev = true
    management     = true
  }

  fqdn = "dataworks.dwp.gov.uk"

  ssh_bastion_enabled = {
    management-dev = false
    management     = false
  }

  ssh_bastion_ssmenabled = {
    management-dev = "True"
    management     = "False"
  }

  ssh_bastion_users              = jsondecode(data.aws_secretsmanager_secret_version.internet_ingress.secret_binary)["ssh_bastion_users"]
  ssh_bastion_whitelisted_ranges = jsondecode(data.aws_secretsmanager_secret_version.internet_ingress.secret_binary)["ssh_bastion_whitelisted_ranges"]

  env_prefix = {
    management-dev = "mgt-dev."
    management     = "mgt."
  }

  target_env = {
    management-dev = ".dev"
    management     = ""
  }

  dw_domain = "${local.env_prefix[local.environment]}dataworks.dwp.gov.uk"

  ecs_nginx_rp_config_s3_main_prefix = "reverse-proxy"

  deploy_ithc_infra = {
    development    = false
    qa             = false
    integration    = false
    preprod        = false
    production     = false
    management     = false
    management-dev = false
  }
}
