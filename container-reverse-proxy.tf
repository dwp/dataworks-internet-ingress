data "aws_instances" "target_instance" {
  instance_tags = {
    "ShortName"                                     = "ingest-hbase",
    "aws:elasticmapreduce:instance-group-role" = "MASTER"
  }
  provider = aws.target
}

data "aws_iam_policy_document" "container_reverse_proxy_read_config" {
  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
    ]

    resources = [
      data.terraform_remote_state.management.outputs.config_bucket.arn,
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${data.terraform_remote_state.management.outputs.config_bucket.arn}/${local.ecs_nginx_rp_config_s3_main_prefix}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "kms:Decrypt",
    ]

    resources = [
      data.terraform_remote_state.management.outputs.config_bucket.cmk_arn,
    ]
  }
}

resource "aws_iam_role" "container_reverse_proxy" {
  name               = "ReverseProxy"
  assume_role_policy = data.terraform_remote_state.management.outputs.ecs_assume_role_policy_json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "container_reverse_proxy" {
  policy = data.aws_iam_policy_document.container_reverse_proxy_read_config.json
  role   = aws_iam_role.container_reverse_proxy.id
}

resource "aws_cloudwatch_log_group" "reverse_proxy_ecs" {
  name              = "/aws/ecs/main/reverse-proxy"
  retention_in_days = 30
  tags              = local.common_tags
}

resource "aws_ecs_task_definition" "container_reverse_proxy" {
  family                   = "nginx-s3"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "4096"
  task_role_arn            = aws_iam_role.container_reverse_proxy.arn
  execution_role_arn       = data.terraform_remote_state.management.outputs.ecs_task_execution_role.arn

  container_definitions = <<DEFINITION
[
  {
    "image": "${local.account[local.environment]}.${module.vpc.ecr_dkr_domain_name}/nginx-s3:latest",
    "name": "nginx-s3",
    "networkMode": "awsvpc",
    "portMappings": [
      {
        "containerPort": ${var.reverse_proxy_http_port}
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.reverse_proxy_ecs.name}",
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "${local.ecs_nginx_rp_config_s3_main_prefix}"
      }
    },
    "placementStrategy": [
      {
        "field": "attribute:ecs.availability-zone",
        "type": "spread"
      }
    ],
    "environment": [
      {
        "name": "NGINX_CONFIG_S3_BUCKET",
        "value": "${data.terraform_remote_state.management.outputs.config_bucket.id}"
      },
      {
        "name": "NGINX_CONFIG_S3_KEY",
        "value": "${aws_s3_object.nginx_config.key}"
      }
    ]
  }
]
DEFINITION

}

resource "aws_ecs_service" "container_reverse_proxy" {
  name            = local.ecs_nginx_rp_config_s3_main_prefix
  cluster         = data.terraform_remote_state.management.outputs.ecs_cluster_main.id
  task_definition = aws_ecs_task_definition.container_reverse_proxy.arn
  desired_count   = length(data.aws_availability_zones.available.names)
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.reverse_proxy_ecs.id]
    subnets         = aws_subnet.reverse_proxy_private.*.id
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.reverse_proxy.arn
    container_name   = "nginx-s3"
    container_port   = var.reverse_proxy_http_port
  }
}

resource "aws_security_group" "reverse_proxy_ecs" {
  name                   = "reverse-proxy-ecs"
  description            = "Reverse Proxy Container in ECS"
  vpc_id                 = module.vpc.vpc.id
  revoke_rules_on_delete = true
}

resource "aws_security_group_rule" "egress_internet_proxy" {
  description              = "Allow Internet access via the proxy for reverse proxy container"
  type                     = "egress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.internet_proxy_endpoint.id
  security_group_id        = aws_security_group.reverse_proxy_ecs.id
}

resource "aws_security_group_rule" "ingress_internet_proxy" {
  description              = "Allow proxy access from reverse proxy container"
  type                     = "ingress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.reverse_proxy_ecs.id
  security_group_id        = aws_security_group.internet_proxy_endpoint.id
}

resource "aws_security_group_rule" "reverse_proxy_http_ingress" {
  description       = "Reverse Proxy Container HTTP Rule"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  cidr_blocks       = [module.vpc.vpc.cidr_block]
  security_group_id = aws_security_group.reverse_proxy_ecs.id
}

resource "aws_security_group_rule" "reverse_proxy_http_egress" {
  description              = "Allow outbound requests to VPC endpoints (HTTP) from reverse-proxy container"
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = "80"
  to_port                  = "80"
  source_security_group_id = module.vpc.interface_vpce_sg_id
  security_group_id        = aws_security_group.reverse_proxy_ecs.id
}

resource "aws_security_group_rule" "vpc_endpoint_http_egress" {
  description              = "Allow inbound requests to VPC endpoints (HTTP) from reverse-proxy container"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "80"
  to_port                  = "80"
  security_group_id        = module.vpc.interface_vpce_sg_id
  source_security_group_id = aws_security_group.reverse_proxy_ecs.id
}

resource "aws_security_group_rule" "reverse_proxy_s3_egress" {
  description       = "Allow outbound requests to S3 PFL from reverse-proxy container"
  type              = "egress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  prefix_list_ids   = [module.vpc.prefix_list_ids.s3]
  security_group_id = aws_security_group.reverse_proxy_ecs.id
}

resource "aws_security_group_rule" "reverse_proxy_s3_https_egress" {
  description       = "Allow HTTPS outbound requests to S3 PFL from reverse-proxy container"
  type              = "egress"
  protocol          = "tcp"
  from_port         = "443"
  to_port           = "443"
  prefix_list_ids   = [module.vpc.prefix_list_ids.s3]
  security_group_id = aws_security_group.reverse_proxy_ecs.id
}

resource "aws_s3_object" "nginx_config" {
  bucket     = data.terraform_remote_state.management.outputs.config_bucket.id
  key        = "${local.ecs_nginx_rp_config_s3_main_prefix}/nginx_conf_${data.archive_file.nginx_config_files.output_md5}.zip"
  kms_key_id = data.terraform_remote_state.management.outputs.config_bucket.cmk_arn
  source     = data.archive_file.nginx_config_files.output_path
}

data "archive_file" "nginx_config_files" {
  type        = "zip"
  output_path = "${path.module}/files/reverse_proxy/nginx_conf.zip"
  source {
    content  = templatefile("${path.module}/files/reverse_proxy/nginx.conf.tpl", {})
    filename = "nginx.conf"
  }
  source {
    content  = templatefile("${path.module}/files/reverse_proxy/default.conf.tpl", {})
    filename = "conf.d/default.conf"
  }
  source {
    content = templatefile("${path.module}/files/reverse_proxy/ganglia.conf.tpl", {
      target_ip_1     = data.aws_instances.target_instance.private_ips[0]
      target_domain_1 = "ui.ingest-hbase${local.target_env[local.environment]}.master1.${local.fqdn}"
      target_ip_2     = data.aws_instances.target_instance.private_ips[1]
      target_domain_2 = "ui.ingest-hbase${local.target_env[local.environment]}.master2.${local.fqdn}"
      target_ip_3     = data.aws_instances.target_instance.private_ips[2]
      target_domain_3 = "ui.ingest-hbase${local.target_env[local.environment]}.master3.${local.fqdn}"
    })
    filename = "conf.d/ganglia.conf"
  }
  source {
    content = templatefile("${path.module}/files/reverse_proxy/hbase.conf.tpl", {
      target_ip_1     = data.aws_instances.target_instance.private_ips[0]
      target_domain_1 = "ui.ingest-hbase${local.target_env[local.environment]}.master1.${local.fqdn}"
      target_ip_2     = data.aws_instances.target_instance.private_ips[1]
      target_domain_2 = "ui.ingest-hbase${local.target_env[local.environment]}.master2.${local.fqdn}"
      target_ip_3     = data.aws_instances.target_instance.private_ips[2]
      target_domain_3 = "ui.ingest-hbase${local.target_env[local.environment]}.master3.${local.fqdn}"
    })
    filename = "conf.d/hbase.conf"
  }
  source {
    content = templatefile("${path.module}/files/reverse_proxy/nm.conf.tpl", {
      target_ip     = data.aws_instances.target_instance.private_ips[0]
      target_domain = "ui.ingest-hbase${local.target_env[local.environment]}.${local.fqdn}"
    })
    filename = "conf.d/nm.conf"
  }
  source {
    content = templatefile("${path.module}/files/reverse_proxy/rm.conf.tpl", {
      target_ip     = data.aws_instances.target_instance.private_ips[0]
      target_domain = "ui.ingest-hbase${local.target_env[local.environment]}.${local.fqdn}"
    })
    filename = "conf.d/rm.conf"
  }
}
