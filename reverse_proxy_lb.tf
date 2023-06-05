resource "aws_alb" "reverse_proxy" {
  name               = "reverse-proxy"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.reverse_proxy_public.*.id
  depends_on         = [aws_internet_gateway.igw]
  security_groups    = [aws_security_group.reverse_proxy_lb.id]

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
        "${aws_route53_record.reverse_proxy_hbase_ui[0].name}.${local.fqdn}",
        "${aws_route53_record.reverse_proxy_ganglia_ui[0].name}.${local.fqdn}",
        "${aws_route53_record.reverse_proxy_nm_ui[0].name}.${local.fqdn}",
        "${aws_route53_record.reverse_proxy_rm_ui[0].name}.${local.fqdn}",
      ]
    }
  }
}

resource "aws_lb_target_group" "reverse_proxy" {
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

resource "aws_security_group" "reverse_proxy_lb" {
  name                   = "reverse-proxy-lb"
  description            = "Reverse Proxy Load Balancer"
  vpc_id                 = module.vpc.vpc.id
  revoke_rules_on_delete = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "reverse_proxy_lb_http_ingress" {
  description       = "Reverse Proxy HTTP"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  cidr_blocks       = local.team_cidr_blocks
  security_group_id = aws_security_group.reverse_proxy_lb.id
}

resource "aws_security_group_rule" "reverse_proxy_lb_http_egress_to_container" {
  description              = "Reverse Proxy HTTP Rule"
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = "80"
  to_port                  = "80"
  source_security_group_id = aws_security_group.reverse_proxy_ecs.id
  security_group_id        = aws_security_group.reverse_proxy_lb.id
}
