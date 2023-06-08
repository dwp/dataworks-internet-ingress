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
    development = {
      ip_addresses: data.aws_instances.hbase_masters_development.private_ips
      domains: "dev"
    },
    qa = {
      ip_addresses: data.aws_instances.hbase_masters_qa.private_ips
      domains: "qa"
    }
    integration = {
      ip_addresses: data.aws_instances.hbase_masters_integration.private_ips
      domains: "integration"
    }
    preprod = {
      ip_addresses: data.aws_instances.hbase_masters_preprod.private_ips
      domains: "preprod"
    }
    production = {
      ip_addresses: data.aws_instances.hbase_masters_production.private_ips
      domains: "production"
    }
  }

  target_hbase_clusters = [ for environment, cluster in local.hbase_clusters: cluster if contains(local.mgmt_account_mapping[local.environment], environment) ]
}

output "target_hbase_clusters" {
  value = local.target_hbase_clusters
}

module "hbase-nginx-entries" {
  source = "./modules/hbase-nginx-entries"

  target_hbase_clusters = local.target_hbase_clusters
}
