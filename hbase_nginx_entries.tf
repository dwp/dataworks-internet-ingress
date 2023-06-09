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
  hbase_clusters = {
    development = [ 
      for i, ip in data.aws_instances.hbase_masters_development.private_ips: tomap({
        ip_address = ip, 
        domain = "${local.target_env["development"]}.master${i + 1}.${local.fqdn}"
      }) 
    ]
    qa = [ 
      for i, ip in data.aws_instances.hbase_masters_qa.private_ips: tomap({
        ip_address = ip, 
        domain = "${local.target_env["qa"]}.master${i + 1}.${local.fqdn}"
      }) 
    ]
    integration = [ 
      for i, ip in data.aws_instances.hbase_masters_integration.private_ips: tomap({
        ip_address = ip, 
        domain = "${local.target_env["integration"]}.master${i + 1}.${local.fqdn}"
      })
    ]
    preprod = [ 
      for i, ip in data.aws_instances.hbase_masters_preprod.private_ips: tomap({
        ip_address = ip, 
        domain = "${local.target_env["preprod"]}.master${i + 1}.${local.fqdn}"
      }) 
    ]
    production = [ 
      for i, ip in data.aws_instances.hbase_masters_production.private_ips: tomap({
        ip_address = ip, 
        domain = "${local.target_env["production"]}.master${i + 1}.${local.fqdn}"
      }) 
    ]
  }

  target_hbase_clusters = flatten([ 
    for environment, cluster in local.hbase_clusters: cluster if contains(local.mgmt_account_mapping[local.environment], environment) 
  ])
}

module "hbase-nginx-entries" {
  source = "./modules/hbase-nginx-entries"

  target_hbase_clusters = local.target_hbase_clusters
}
