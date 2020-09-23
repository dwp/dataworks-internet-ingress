resource "aws_acm_certificate" "reverse_proxy" {
  # This depends_on exists to work around a problem with ordering that is
  # fixed in AWS Provider v3.0.0.
  depends_on = [aws_route53_record.reverse_proxy_hbase_ui,
    aws_route53_record.reverse_proxy_ganglia_ui,
    aws_route53_record.reverse_proxy_nm_ui,
    aws_route53_record.reverse_proxy_rm_ui
  ]
  count             = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  domain_name       = "ui.ingest-hbase${local.target_env[local.environment]}.${local.fqdn}"
  validation_method = "DNS"

  subject_alternative_names = [
    "hbase.ui.ingest-hbase${local.target_env[local.environment]}.master1.${local.fqdn}",
    "hbase.ui.ingest-hbase${local.target_env[local.environment]}.master2.${local.fqdn}",
    "hbase.ui.ingest-hbase${local.target_env[local.environment]}.master3.${local.fqdn}",
    "ganglia.ui.ingest-hbase${local.target_env[local.environment]}.master1.${local.fqdn}",
    "ganglia.ui.ingest-hbase${local.target_env[local.environment]}.master2.${local.fqdn}",
    "ganglia.ui.ingest-hbase${local.target_env[local.environment]}.master3.${local.fqdn}",
    "nm.ui.ingest-hbase${local.target_env[local.environment]}.${local.fqdn}",
    "rm.ui.ingest-hbase${local.target_env[local.environment]}.${local.fqdn}",
  ]

  tags = merge(
    local.common_tags,
    { Name = "reverse-proxy",
    Environment = local.environment },
  )


  lifecycle {
    ignore_changes = [subject_alternative_names]
  }
}

resource "aws_acm_certificate_validation" "reverse_proxy_cert_validation" {
  count           = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  certificate_arn = aws_acm_certificate.reverse_proxy[0].arn
  validation_record_fqdns = [
    aws_route53_record.reverse_proxy_alb_cert_validation_record[0].fqdn,
    aws_route53_record.reverse_proxy_alb_cert_validation_nm_record[0].fqdn,
    aws_route53_record.reverse_proxy_alb_cert_validation_rm_record[0].fqdn
  ]
}

resource "aws_acm_certificate_validation" "reverse_proxy_cert_validation_masters" {
  count           = local.reverse_proxy_enabled[local.environment] ? length(data.aws_instances.target_instance[0].private_ips) : 0
  certificate_arn = aws_acm_certificate.reverse_proxy[0].arn
  validation_record_fqdns = [
    aws_route53_record.reverse_proxy_alb_cert_validation_hbase_record[count.index].fqdn,
    aws_route53_record.reverse_proxy_alb_cert_validation_ganglia_record[count.index].fqdn
  ]
}

resource "aws_route53_record" "reverse_proxy_alb" {
  count   = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name    = "reverse-proxy-alb.ui.ingest-hbase${local.target_env[local.environment]}"
  type    = "A"
  zone_id = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id

  alias {
    evaluate_target_health = true
    name                   = aws_alb.reverse_proxy[0].dns_name
    zone_id                = aws_alb.reverse_proxy[0].zone_id
  }

  provider = aws.management_dns
}

resource "aws_route53_record" "reverse_proxy_alb_cert_validation_record" {
  count    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name     = aws_acm_certificate.reverse_proxy[0].domain_validation_options.0.resource_record_name
  type     = aws_acm_certificate.reverse_proxy[0].domain_validation_options.0.resource_record_type
  zone_id  = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id
  records  = [aws_acm_certificate.reverse_proxy[0].domain_validation_options.0.resource_record_value]
  ttl      = 60
  provider = aws.management_dns
}

resource "aws_route53_record" "reverse_proxy_hbase_ui" {
  count   = local.reverse_proxy_enabled[local.environment] ? length(data.aws_instances.target_instance[0].private_ips) : 0
  name    = "hbase.ui.ingest-hbase${local.target_env[local.environment]}.master${count.index}"
  type    = "A"
  zone_id = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id

  alias {
    evaluate_target_health = true
    name                   = aws_alb.reverse_proxy[0].dns_name
    zone_id                = aws_alb.reverse_proxy[0].zone_id
  }

  provider = aws.management_dns
}

resource "aws_route53_record" "reverse_proxy_alb_cert_validation_hbase_record" {
  count    = local.reverse_proxy_enabled[local.environment] ? length(data.aws_instances.target_instance[0].private_ips) : 0
  name     = aws_acm_certificate.reverse_proxy[0].domain_validation_options.1.resource_record_name
  type     = aws_acm_certificate.reverse_proxy[0].domain_validation_options.1.resource_record_type
  zone_id  = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id
  records  = [aws_acm_certificate.reverse_proxy[0].domain_validation_options.1.resource_record_value]
  ttl      = 60
  provider = aws.management_dns
}

resource "aws_route53_record" "reverse_proxy_ganglia_ui" {
  count   = local.reverse_proxy_enabled[local.environment] ? length(data.aws_instances.target_instance[0].private_ips) : 0
  name    = "ganglia.ui.ingest-hbase${local.target_env[local.environment]}.master${count.index}"
  type    = "A"
  zone_id = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id

  alias {
    evaluate_target_health = true
    name                   = aws_alb.reverse_proxy[0].dns_name
    zone_id                = aws_alb.reverse_proxy[0].zone_id
  }

  provider = aws.management_dns
}

resource "aws_route53_record" "reverse_proxy_alb_cert_validation_ganglia_record" {
  count    = local.reverse_proxy_enabled[local.environment] ? length(data.aws_instances.target_instance[0].private_ips) : 0
  name     = aws_acm_certificate.reverse_proxy[0].domain_validation_options.2.resource_record_name
  type     = aws_acm_certificate.reverse_proxy[0].domain_validation_options.2.resource_record_type
  zone_id  = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id
  records  = [aws_acm_certificate.reverse_proxy[0].domain_validation_options.2.resource_record_value]
  ttl      = 60
  provider = aws.management_dns
}

resource "aws_route53_record" "reverse_proxy_nm_ui" {
  count   = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name    = "nm.ui.ingest-hbase${local.target_env[local.environment]}"
  type    = "A"
  zone_id = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id

  alias {
    evaluate_target_health = true
    name                   = aws_alb.reverse_proxy[0].dns_name
    zone_id                = aws_alb.reverse_proxy[0].zone_id
  }

  provider = aws.management_dns
}

resource "aws_route53_record" "reverse_proxy_alb_cert_validation_nm_record" {
  count    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name     = aws_acm_certificate.reverse_proxy[0].domain_validation_options.3.resource_record_name
  type     = aws_acm_certificate.reverse_proxy[0].domain_validation_options.3.resource_record_type
  zone_id  = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id
  records  = [aws_acm_certificate.reverse_proxy[0].domain_validation_options.3.resource_record_value]
  ttl      = 60
  provider = aws.management_dns
}

resource "aws_route53_record" "reverse_proxy_rm_ui" {
  count   = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name    = "rm.ui.ingest-hbase${local.target_env[local.environment]}"
  type    = "A"
  zone_id = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id

  alias {
    evaluate_target_health = true
    name                   = aws_alb.reverse_proxy[0].dns_name
    zone_id                = aws_alb.reverse_proxy[0].zone_id
  }

  provider = aws.management_dns
}

resource "aws_route53_record" "reverse_proxy_alb_cert_validation_rm_record" {
  count    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name     = aws_acm_certificate.reverse_proxy[0].domain_validation_options.4.resource_record_name
  type     = aws_acm_certificate.reverse_proxy[0].domain_validation_options.4.resource_record_type
  zone_id  = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id
  records  = [aws_acm_certificate.reverse_proxy[0].domain_validation_options.4.resource_record_value]
  ttl      = 60
  provider = aws.management_dns
}
