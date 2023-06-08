# COMMENTED - THIS IS NOT USED AND CERT RENEWAL & VALIDATION DOES NOT WORK BECAUSE IT IS NOT USED
# Work to enforce HTTPS is covered by DW-9398

# resource "aws_acm_certificate" "reverse_proxy" {
#   # This depends_on exists to work around a problem with ordering that is
#   # fixed in AWS Provider v3.0.0.
#   depends_on = [aws_route53_record.reverse_proxy_hbase_ui,
#     aws_route53_record.reverse_proxy_ganglia_ui,
#     aws_route53_record.reverse_proxy_nm_ui,
#     aws_route53_record.reverse_proxy_rm_ui
#   ]
#
#   domain_name       = "ui.ingest-hbase${local.target_env[local.environment]}.${local.fqdn}"
#   validation_method = "DNS"

#   subject_alternative_names = [
#     "hbase.ui.ingest-hbase${local.target_env[local.environment]}.master1.${local.fqdn}",
#     "hbase.ui.ingest-hbase${local.target_env[local.environment]}.master2.${local.fqdn}",
#     "hbase.ui.ingest-hbase${local.target_env[local.environment]}.master3.${local.fqdn}",
#     "ganglia.ui.ingest-hbase${local.target_env[local.environment]}.master1.${local.fqdn}",
#     "ganglia.ui.ingest-hbase${local.target_env[local.environment]}.master2.${local.fqdn}",
#     "ganglia.ui.ingest-hbase${local.target_env[local.environment]}.master3.${local.fqdn}",
#     "nm.ui.ingest-hbase${local.target_env[local.environment]}.${local.fqdn}",
#     "rm.ui.ingest-hbase${local.target_env[local.environment]}.${local.fqdn}",
#   ]

#   tags = merge(
#     local.common_tags,
#     { Name = "reverse-proxy",
#     Environment = local.environment },
#   )


#   lifecycle {
#     ignore_changes = [subject_alternative_names]
#   }
# }

# resource "aws_acm_certificate_validation" "reverse_proxy_cert_validation" {
#   certificate_arn = aws_acm_certificate.reverse_proxy[0].arn
#   validation_record_fqdns = [for record in aws_route53_record.reverse_proxy_alb_cert_validation_record : record.fqdn]
# }

resource "aws_route53_record" "reverse_proxy_alb" {
  name    = "reverse-proxy-alb.ui.ingest-hbase${local.target_env[local.environment]}"
  type    = "A"
  zone_id = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id

  alias {
    evaluate_target_health = true
    name                   = module.reverse_proxy.reverse_proxy_dns_name
    zone_id                = module.reverse_proxy.reverse_proxy_zone_id
  }

  provider = aws.management_dns
}

# resource "aws_route53_record" "reverse_proxy_alb_cert_validation_record" {
#   for_each = {
#     for dvo in aws_acm_certificate.reverse_proxy[0].domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   }

#   name     = each.value.name
#   type     = each.value.type
#   records  = [each.value.record]
#   ttl      = 60
#   zone_id  = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id
#   provider = aws.management_dns
# }

resource "aws_route53_record" "reverse_proxy_hbase_ui" {
  count   = length(data.aws_instances.target_instance.private_ips)
  name    = "hbase.ui.ingest-hbase${local.target_env[local.environment]}.master${count.index + 1}"
  type    = "A"
  zone_id = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id

  alias {
    evaluate_target_health = true
    name                   = module.reverse_proxy.reverse_proxy_dns_name
    zone_id                = module.reverse_proxy.reverse_proxy_zone_id
  }

  provider = aws.management_dns
}

resource "aws_route53_record" "reverse_proxy_ganglia_ui" {
  count   = length(data.aws_instances.target_instance.private_ips)
  name    = "ganglia.ui.ingest-hbase${local.target_env[local.environment]}.master${count.index + 1}"
  type    = "A"
  zone_id = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id

  alias {
    evaluate_target_health = true
    name                   = module.reverse_proxy.reverse_proxy_dns_name
    zone_id                = module.reverse_proxy.reverse_proxy_zone_id
  }

  provider = aws.management_dns
}
resource "aws_route53_record" "reverse_proxy_nm_ui" {
  name    = "nm.ui.ingest-hbase${local.target_env[local.environment]}"
  type    = "A"
  zone_id = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id

  alias {
    evaluate_target_health = true
    name                   = module.reverse_proxy.reverse_proxy_dns_name
    zone_id                = module.reverse_proxy.reverse_proxy_zone_id
  }

  provider = aws.management_dns
}

resource "aws_route53_record" "reverse_proxy_rm_ui" {
  name    = "rm.ui.ingest-hbase${local.target_env[local.environment]}"
  type    = "A"
  zone_id = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id

  alias {
    evaluate_target_health = true
    name                   = module.reverse_proxy.reverse_proxy_dns_name
    zone_id                = module.reverse_proxy.reverse_proxy_zone_id
  }

  provider = aws.management_dns
}
