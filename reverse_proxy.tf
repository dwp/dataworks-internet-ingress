resource "aws_security_group" "reverse_proxy_lb" {
  count                  = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name                   = "reverse-proxy-lb"
  description            = "Reverse Proxy Load Balancer"
  vpc_id                 = module.vpc.vpc.id
  revoke_rules_on_delete = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "egress_internet_proxy" {
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Allow Internet access via the proxy for reverse proxy"
  type                     = "egress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.internet_proxy_endpoint.id
  security_group_id        = aws_security_group.reverse_proxy_instance[0].id
}

resource "aws_security_group_rule" "ingress_internet_proxy" {
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Allow proxy access from reverse proxy"
  type                     = "ingress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.reverse_proxy_instance[0].id
  security_group_id        = aws_security_group.internet_proxy_endpoint.id
}

//resource "aws_security_group_rule" "reverse_proxy_lb_https_ingress" {
//  description       = "Reverse Proxy HTTPS Rule"
//  type              = "ingress"
//  protocol          = "tcp"
//  from_port         = "443"
//  to_port           = "443"
//  cidr_blocks       = [local.team_cidr_block]
//  security_group_id = aws_security_group.reverse_proxy_lb.id
//}

resource "aws_security_group_rule" "reverse_proxy_lb_http_egress_to_instance" {
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Reverse Proxy HTTP Rule"
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = "80"
  to_port                  = "80"
  source_security_group_id = aws_security_group.reverse_proxy_instance[0].id
  security_group_id        = aws_security_group.reverse_proxy_lb[0].id
}

resource "aws_security_group" "reverse_proxy_instance" {
  count                  = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name                   = "reverse-proxy-instance"
  description            = "Reverse Proxy Instance"
  vpc_id                 = module.vpc.vpc.id
  revoke_rules_on_delete = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "reverse_proxy_http_ingress" {
  count             = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description       = "Reverse Proxy HTTP Rule"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  cidr_blocks       = [local.team_cidr_block]
  security_group_id = aws_security_group.reverse_proxy_instance[0].id
}

resource "aws_security_group_rule" "reverse_proxy_http_egress" {
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Allow outbound requests to VPC endpoints (HTTP)"
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = "80"
  to_port                  = "80"
  source_security_group_id = module.vpc.interface_vpce_sg_id
  security_group_id        = aws_security_group.reverse_proxy_instance[0].id
}

resource "aws_security_group_rule" "vpc_endpoint_http_egress" {
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Allow inbound requests to VPC endpoints (HTTP)"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "80"
  to_port                  = "80"
  security_group_id        = module.vpc.interface_vpce_sg_id
  source_security_group_id = aws_security_group.reverse_proxy_instance[0].id
}

// Egress rules to be added by applications, leaving this to remind me
//resource "aws_security_group_rule" "reverse_proxy_instance_lb_egress" {
//  description              = "Reverse Proxy HTTPS Rule"
//  type                     = "egress"
//  protocol                 = "tcp"
//  from_port                = "80"
//  to_port                  = "80"
//  source_security_group_id = "" // SG emr_common
//  security_group_id        = aws_security_group.reverse_proxy_instance.id
//}

resource "aws_alb" "reverse_proxy" {
  count              = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name               = "reverse-proxy"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.reverse_proxy.*.id
  depends_on         = [aws_internet_gateway.igw]
  security_groups    = [aws_security_group.reverse_proxy_lb[0].id]

  tags = merge(
    local.common_tags,
    { Name = "reverse-proxy" }
  )
}

resource "aws_lb_listener" "reverse_proxy_http" {
  count             = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  load_balancer_arn = aws_alb.reverse_proxy[0].arn
  port              = 80
  protocol          = "HTTP"
  //  ssl_policy        = "ELBSecurityPolicy-2016-08"
  //  certificate_arn   = aws_acm_certificate.reverse_proxy.arn


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.reverse_proxy[0].arn
  }
}

resource "aws_lb_listener_rule" "reverse_proxy_ganglia" {
  count        = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  listener_arn = aws_lb_listener.reverse_proxy_http[0].arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.reverse_proxy[0].arn
  }
  condition {
    host_header {
      values = [
        "hbase.ui.ingest-hbase.dev.dataworks.dwp.gov.uk",
        "ganglia.ui.ingest-hbase.dev.dataworks.dwp.gov.uk",
        "nm.ui.ingest-hbase.dev.dataworks.dwp.gov.uk",
        "rm.ui.ingest-hbase.dev.dataworks.dwp.gov.uk"
      ]
    }
  }
}

resource "aws_lb_target_group" "reverse_proxy" {
  count       = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name        = "reverse-proxy"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = module.vpc.vpc.id

  stickiness {
    type    = "lb_cookie"
    enabled = false
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    { Name = "reverse-proxy" },
  )
}

resource "aws_acm_certificate" "reverse_proxy" {
  count             = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  domain_name       = "ui.ingest-hbase.dev.dataworks.dwp.gov.uk"
  validation_method = "DNS"

  subject_alternative_names = [
    "hbase.ui.ingest-hbase.dev.dataworks.dwp.gov.uk",
    "ganglia.ui.ingest-hbase.dev.dataworks.dwp.gov.uk",
    "nm.ui.ingest-hbase.dev.dataworks.dwp.gov.uk",
    "rm.ui.ingest-hbase.dev.dataworks.dwp.gov.uk"
  ]

  tags = {
    Environment = local.environment
  }

  lifecycle {
    ignore_changes = [subject_alternative_names]
  }
}

resource "aws_route53_record" "reverse_proxy_alb" {
  count   = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name    = "reverse-proxy-alb.ui.ingest-hbase.dev"
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
  count   = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name    = "hbase.ui.ingest-hbase.dev"
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
  count    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name     = aws_acm_certificate.reverse_proxy[0].domain_validation_options.1.resource_record_name
  type     = aws_acm_certificate.reverse_proxy[0].domain_validation_options.1.resource_record_type
  zone_id  = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id
  records  = [aws_acm_certificate.reverse_proxy[0].domain_validation_options.1.resource_record_value]
  ttl      = 60
  provider = aws.management_dns
}

resource "aws_route53_record" "reverse_proxy_ganglia_ui" {
  count   = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name    = "ganglia.ui.ingest-hbase.dev"
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
  count    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name     = aws_acm_certificate.reverse_proxy[0].domain_validation_options.2.resource_record_name
  type     = aws_acm_certificate.reverse_proxy[0].domain_validation_options.2.resource_record_type
  zone_id  = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id
  records  = [aws_acm_certificate.reverse_proxy[0].domain_validation_options.2.resource_record_value]
  ttl      = 60
  provider = aws.management_dns
}

resource "aws_route53_record" "reverse_proxy_nm_ui" {
  count   = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name    = "nm.ui.ingest-hbase.dev"
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
  name    = "rm.ui.ingest-hbase.dev"
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

resource "aws_acm_certificate_validation" "reverse_proxy_cert_validation" {
  count           = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  certificate_arn = aws_acm_certificate.reverse_proxy[0].arn
  validation_record_fqdns = [
    aws_route53_record.reverse_proxy_alb_cert_validation_record[0].fqdn,
    aws_route53_record.reverse_proxy_alb_cert_validation_hbase_record[0].fqdn,
    aws_route53_record.reverse_proxy_alb_cert_validation_ganglia_record[0].fqdn,
    aws_route53_record.reverse_proxy_alb_cert_validation_nm_record[0].fqdn,
    aws_route53_record.reverse_proxy_alb_cert_validation_rm_record[0].fqdn
  ]
  provider = aws.management_dns
}

data "aws_ami" "reverse_proxy_nginxplus" {
  most_recent = true

  filter {
    name   = "name"
    values = ["nginx-plus-ami-amazon-linux-hvm-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["aws-marketplace"]
}

data "template_file" "reverse_proxy_user_data" {
  count    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  template = file("files/reverse_proxy_user_data.tpl")

  vars = {
    no_proxy       = join(",", module.vpc.no_proxy_list)
    internet_proxy = "http://${aws_vpc_endpoint.internet_proxy.dns_entry[0].dns_name}:3128"
  }
}

resource "aws_launch_configuration" "reverse_proxy" {
  count       = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name_prefix = "reverse-proxy-"
  //  image_id             = data.aws_ami.reverse_proxy_nginxplus.image_id
  image_id             = "ami-086289e3240973ac7" // latest general-ami
  instance_type        = "t2.xlarge"
  security_groups      = [aws_security_group.reverse_proxy_instance[0].id]
  iam_instance_profile = aws_iam_instance_profile.reverse_proxy[0].arn
  user_data            = base64encode(data.template_file.reverse_proxy_user_data[0].rendered)

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 50
    delete_on_termination = true
    encrypted             = true
  }

  lifecycle {
    create_before_destroy = true
  }

  //      tag_specifications {
  //        resource_type = "instance"
  //
  //        tags = merge(
  //          local.common_tags,
  //          {
  //            "application" = "reverse-proxy"
  //          },
  //        )
  //      }
}

resource "aws_autoscaling_group" "reverse_proxy" {
  count                     = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name                      = aws_launch_configuration.reverse_proxy[0].name
  min_size                  = 1
  desired_capacity          = 1
  max_size                  = 1
  health_check_grace_period = 180
  health_check_type         = "EC2"
  force_delete              = true
  launch_configuration      = aws_launch_configuration.reverse_proxy[0].name
  vpc_zone_identifier       = aws_subnet.reverse_proxy.*.id
  target_group_arns         = [aws_lb_target_group.reverse_proxy[0].arn]

  dynamic "tag" {
    for_each = merge(
      local.common_tags,
      { Name         = "reverse_proxy_host",
        Persistence  = "Ignore",
        AutoShutdown = "False",
        SSMEnabled   = local.reverse_proxy_ssmenabled[local.environment]
      },
    )

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_instance_profile" "reverse_proxy" {
  count = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name  = "reverse_proxy"
  role  = aws_iam_role.reverse_proxy[0].name
}

resource "aws_iam_role" "reverse_proxy" {
  count              = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name               = "reverse_proxy"
  assume_role_policy = data.aws_iam_policy_document.reverse_proxy_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "reverse_proxy_ssm_role" {
  count      = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  role       = aws_iam_role.reverse_proxy[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_role_policy_attachment" "reverse_proxy_cw_role" {
  count      = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  role       = aws_iam_role.reverse_proxy[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_iam_policy_document" "reverse_proxy_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "ec2.amazonaws.com",
      ]
    }

    actions = [
      "sts:AssumeRole",
    ]
  }
}

