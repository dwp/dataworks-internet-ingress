data "aws_instances" "hbase_masters_development" {
  instance_tags = {
    "ShortName"                                = "ingest-hbase",
    "aws:elasticmapreduce:instance-group-role" = "MASTER"
  }

  provider = aws.development
}

data "aws_instances" "hbase_masters_qa" {
  instance_tags = {
    "ShortName"                                = "ingest-hbase",
    "aws:elasticmapreduce:instance-group-role" = "MASTER"
  }

  provider = aws.qa
}

data "aws_instances" "hbase_masters_integration" {
  instance_tags = {
    "ShortName"                                = "ingest-hbase",
    "aws:elasticmapreduce:instance-group-role" = "MASTER"
  }

  provider = aws.integration
}

data "aws_instances" "hbase_masters_preprod" {
  instance_tags = {
    "ShortName"                                = "ingest-hbase",
    "aws:elasticmapreduce:instance-group-role" = "MASTER"
  }

  provider = aws.preprod
}

data "aws_instances" "hbase_masters_production" {
  instance_tags = {
    "ShortName"                                = "ingest-hbase",
    "aws:elasticmapreduce:instance-group-role" = "MASTER"
  }

  provider = aws.production
}

locals {
  # TODO: Replace Data lookups on instances with lookups on Load Balancers which will sit in front of the clusters. Below is workaround until these Load Balancers are deployed as part of EMR deployment.
  hbase_clusters = {
    development = [ 
      for i, ip in data.aws_instances.hbase_masters_development.private_ips: tomap({
        ip_address = ip,
        node_identifier = "master${i + 1}"
        domain = local.fqdn
        target_env = local.target_env["development"]
      }) 
    ]
    qa = [ 
      for i, ip in data.aws_instances.hbase_masters_qa.private_ips: tomap({
        ip_address = ip,
        node_identifier = "master${i + 1}"
        domain = local.fqdn
        target_env = local.target_env["qa"]
      }) 
    ]
    integration = [ 
      for i, ip in data.aws_instances.hbase_masters_integration.private_ips: tomap({
        ip_address = ip,
        node_identifier = "master${i + 1}"
        domain = local.fqdn
        target_env = local.target_env["integration"]
      })
    ]
    preprod = [ 
      for i, ip in data.aws_instances.hbase_masters_preprod.private_ips: tomap({
        ip_address = ip,
        node_identifier = "master${i + 1}"
        domain = local.fqdn
        target_env = local.target_env["preprod"]
      }) 
    ]
    production = [ 
      for i, ip in data.aws_instances.hbase_masters_production.private_ips: tomap({
        ip_address = ip,
        node_identifier = "master${i + 1}"
        domain = local.fqdn
        target_env = local.target_env["production"]
      }) 
    ]
  }

  # Filtered list of HBase masters based upon whether they are lower environments or higher (live) environments
  target_hbase_clusters = flatten([ 
    for environment, cluster in local.hbase_clusters: cluster if contains(local.mgmt_account_mapping[local.environment], environment) 
  ])

  mapped_target_hbase_clusters = { for i, hc in local.target_hbase_clusters : i => hc }
}

module "hbase-nginx-entries" {
  source = "./modules/hbase-nginx-entries"

  target_hbase_clusters = local.target_hbase_clusters
}

resource "aws_route53_record" "reverse_proxy_alb" {
  for_each = toset(local.mgmt_account_mapping[local.environment])

  name    = "reverse-proxy-alb.ui.ingest-hbase${local.target_env[each.value]}"
  type    = "A"
  zone_id = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id

  alias {
    evaluate_target_health = true
    name                   = module.reverse_proxy.reverse_proxy_alb_dns_name
    zone_id                = module.reverse_proxy.reverse_proxy_alb_zone_id
  }

  provider = aws.management_dns
}

resource "aws_route53_record" "reverse_proxy_hbase_ui" {
  for_each = local.mapped_target_hbase_clusters

  name    = "hbase.ui.ingest-hbase${each.value.target_env}.${each.value.node_identifier}"
  type    = "A"
  zone_id = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id

  alias {
    evaluate_target_health = true
    name                   = module.reverse_proxy.reverse_proxy_alb_dns_name
    zone_id                = module.reverse_proxy.reverse_proxy_alb_zone_id
  }

  provider = aws.management_dns
}

resource "aws_route53_record" "reverse_proxy_ganglia_ui" {
  for_each = local.mapped_target_hbase_clusters

  name    = "ganglia.ui.ingest-hbase${each.value.target_env}.${each.value.node_identifier}"
  type    = "A"
  zone_id = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id

  alias {
    evaluate_target_health = true
    name                   = module.reverse_proxy.reverse_proxy_alb_dns_name
    zone_id                = module.reverse_proxy.reverse_proxy_alb_zone_id
  }

  provider = aws.management_dns
}

resource "aws_route53_record" "reverse_proxy_nm_ui" {
  for_each = toset(local.mgmt_account_mapping[local.environment])

  name    = "nm.ui.ingest-hbase${local.target_env[each.value]}"
  type    = "A"
  zone_id = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id

  alias {
    evaluate_target_health = true
    name                   = module.reverse_proxy.reverse_proxy_alb_dns_name
    zone_id                = module.reverse_proxy.reverse_proxy_alb_zone_id
  }

  provider = aws.management_dns
}

resource "aws_route53_record" "reverse_proxy_rm_ui" {
  for_each = toset(local.mgmt_account_mapping[local.environment])

  name    = "rm.ui.ingest-hbase${local.target_env[each.value]}"
  type    = "A"
  zone_id = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id

  alias {
    evaluate_target_health = true
    name                   = module.reverse_proxy.reverse_proxy_alb_dns_name
    zone_id                = module.reverse_proxy.reverse_proxy_alb_zone_id
  }

  provider = aws.management_dns
}
