resource "aws_alb" "reverse_proxy" {
  count              = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name               = "reverse-proxy"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.reverse_proxy_public.*.id
  depends_on         = [aws_internet_gateway.igw]
  security_groups    = [aws_security_group.reverse_proxy_lb[0].id]

  access_logs {
    bucket  = data.terraform_remote_state.security_tools.outputs.logstore_bucket.id
    prefix  = "ELBLogs/${local.ecs_nginx_rp_config_s3_main_prefix}"
    enabled = true
  }

  tags = merge(
    local.common_tags,
    { Name = "reverse-proxy" }
  )
}

//resource "aws_lb_listener" "reverse_proxy_http" {
//  count             = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  load_balancer_arn = aws_alb.reverse_proxy[0].arn
//  port              = var.reverse_proxy_http_port
//  protocol          = "HTTP"
//
//  default_action {
//    type             = "forward"
//    target_group_arn = aws_lb_target_group.reverse_proxy_http[0].arn
//  }
//}

//resource "aws_lb_listener_rule" "reverse_proxy_http" {
//  count        = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  listener_arn = aws_lb_listener.reverse_proxy_http[0].arn
//  action {
//    type             = "forward"
//    target_group_arn = aws_lb_target_group.reverse_proxy_http[0].arn
//  }
//  condition {
//    host_header {
//      values = [
//        "${aws_route53_record.reverse_proxy_hbase_ui[0].name}.${local.fqdn}",
//        "${aws_route53_record.reverse_proxy_ganglia_ui[0].name}.${local.fqdn}",
//        "${aws_route53_record.reverse_proxy_nm_ui[0].name}.${local.fqdn}",
//        "${aws_route53_record.reverse_proxy_rm_ui[0].name}.${local.fqdn}",
//      ]
//    }
//  }
//}

resource "aws_lb_listener" "reverse_proxy_https" {
  count             = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  load_balancer_arn = aws_alb.reverse_proxy[0].arn
  port              = var.reverse_proxy_https_port
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.reverse_proxy[0].arn

  //  default_action {
  //    type = "authenticate-cognito"
  //
  //    authenticate_cognito {
  //      user_pool_arn       = data.terraform_remote_state.aws_concourse.outputs.cognito.user_pool.arn
  //      user_pool_client_id = aws_cognito_user_pool_client.reverse_proxy_ganglia[0].id
  //      user_pool_domain    = local.user_pool_domain_main_domain
  //    }
  //  }
  //
  //  default_action {
  //    type             = "forward"
  //    target_group_arn = aws_lb_target_group.reverse_proxy_https[0].arn
  //  }
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.reverse_proxy[0].arn
  }
}

resource "aws_lb_listener_rule" "reverse_proxy_https_ganglia" {
  count        = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  listener_arn = aws_lb_listener.reverse_proxy_https[0].arn

  action {
    type = "authenticate-cognito"

    authenticate_cognito {
      user_pool_arn       = data.terraform_remote_state.aws_concourse.outputs.cognito.user_pool.arn
      user_pool_client_id = aws_cognito_user_pool_client.reverse_proxy_ganglia[0].id
      user_pool_domain    = local.user_pool_main_domain
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.reverse_proxy[0].arn
  }
  condition {
    host_header {
      values = ["${aws_route53_record.reverse_proxy_ganglia_ui[0].name}.${local.fqdn}"]
    }
  }
}

resource "aws_lb_listener_rule" "reverse_proxy_https_hbaseui" {
  count        = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  listener_arn = aws_lb_listener.reverse_proxy_https[0].arn

  action {
    type = "authenticate-cognito"

    authenticate_cognito {
      user_pool_arn       = data.terraform_remote_state.aws_concourse.outputs.cognito.user_pool.arn
      user_pool_client_id = aws_cognito_user_pool_client.reverse_proxy_hbaseui[0].id
      user_pool_domain    = local.user_pool_main_domain
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.reverse_proxy[0].arn
  }
  condition {
    host_header {
      values = ["${aws_route53_record.reverse_proxy_hbase_ui[0].name}.${local.fqdn}"]
    }
  }
}

resource "aws_lb_listener_rule" "reverse_proxy_https_rm" {
  count        = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  listener_arn = aws_lb_listener.reverse_proxy_https[0].arn

  action {
    type = "authenticate-cognito"

    authenticate_cognito {
      user_pool_arn       = data.terraform_remote_state.aws_concourse.outputs.cognito.user_pool.arn
      user_pool_client_id = aws_cognito_user_pool_client.reverse_proxy_rm[0].id
      user_pool_domain    = local.user_pool_main_domain
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.reverse_proxy[0].arn
  }
  condition {
    host_header {
      values = ["${aws_route53_record.reverse_proxy_rm_ui[0].name}.${local.fqdn}"]
    }
  }
}

resource "aws_lb_listener_rule" "reverse_proxy_https_nm" {
  count        = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  listener_arn = aws_lb_listener.reverse_proxy_https[0].arn

  action {
    type = "authenticate-cognito"

    authenticate_cognito {
      user_pool_arn       = data.terraform_remote_state.aws_concourse.outputs.cognito.user_pool.arn
      user_pool_client_id = aws_cognito_user_pool_client.reverse_proxy_nm[0].id
      user_pool_domain    = local.user_pool_main_domain
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.reverse_proxy[0].arn
  }
  condition {
    host_header {
      values = ["${aws_route53_record.reverse_proxy_nm_ui[0].name}.${local.fqdn}"]
    }
  }
}

resource "aws_lb_target_group" "reverse_proxy" {
  count       = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name_prefix = "rp"
  port        = var.reverse_proxy_http_port
  protocol    = "HTTP"
  target_type = "ip"
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

//resource "aws_lb_target_group" "reverse_proxy_https" {
//  count       = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  name_prefix = "rp-ssl"
//  port        = var.reverse_proxy_https_port
//  protocol    = "HTTPS"
//  target_type = "ip"
//  vpc_id      = module.vpc.vpc.id
//
//  stickiness {
//    type    = "lb_cookie"
//    enabled = false
//  }
//
//  lifecycle {
//    create_before_destroy = true
//  }
//
//  tags = merge(
//    local.common_tags,
//    { Name = "reverse-proxy" },
//  )
//}

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

//resource "aws_security_group_rule" "reverse_proxy_lb_http_ingress" {
//  count             = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  description       = "Reverse Proxy HTTP"
//  type              = "ingress"
//  protocol          = "tcp"
//  from_port         = "80"
//  to_port           = "80"
//  cidr_blocks       = [local.team_cidr_block]
//  security_group_id = aws_security_group.reverse_proxy_lb[0].id
//}

resource "aws_security_group_rule" "reverse_proxy_lb_http_egress_to_container" {
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Reverse Proxy HTTP Rule"
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = "80"
  to_port                  = "80"
  source_security_group_id = aws_security_group.reverse_proxy_ecs[0].id
  security_group_id        = aws_security_group.reverse_proxy_lb[0].id
}

resource "aws_security_group_rule" "reverse_proxy_lb_https_ingress" {
  count             = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description       = "Reverse Proxy HTTPS"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "443"
  to_port           = "443"
  cidr_blocks       = [local.team_cidr_block]
  security_group_id = aws_security_group.reverse_proxy_lb[0].id
}

//resource "aws_security_group_rule" "reverse_proxy_lb_https_egress_to_container" {
//  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  description              = "Reverse Proxy HTTPS Rule"
//  type                     = "egress"
//  protocol                 = "tcp"
//  from_port                = "443"
//  to_port                  = "443"
//  source_security_group_id = aws_security_group.reverse_proxy_ecs[0].id
//  security_group_id        = aws_security_group.reverse_proxy_lb[0].id
//}

