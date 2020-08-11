data "aws_instance" "target_instance" {
  count = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["ingest-hbase"]
  }
  filter {
    name   = "tag:aws:elasticmapreduce:instance-group-role"
    values = ["MASTER"]
  }
  provider = aws.target
}

data "aws_iam_policy_document" "container_reverse_proxy_read_config" {
  count = local.reverse_proxy_enabled[local.environment] ? 1 : 0

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
  count              = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name               = "ReverseProxy"
  assume_role_policy = data.terraform_remote_state.management.outputs.ecs_assume_role_policy_json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "container_reverse_proxy" {
  count  = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  policy = data.aws_iam_policy_document.container_reverse_proxy_read_config[0].json
  role   = aws_iam_role.container_reverse_proxy[0].id
}

resource "aws_cloudwatch_log_group" "reverse_proxy_ecs" {
  count             = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name              = "/aws/ecs/main/reverse-proxy"
  retention_in_days = 30
  tags              = local.common_tags
}

resource "aws_ecs_task_definition" "container_reverse_proxy" {
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  family                   = "nginx-s3"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "4096"
  task_role_arn            = aws_iam_role.container_reverse_proxy[0].arn
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
        "awslogs-group": "${aws_cloudwatch_log_group.reverse_proxy_ecs[0].name}",
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
        "value": "${aws_s3_bucket_object.nginx_config[0].key}"
      }
    ]
  }
]
DEFINITION

}

resource "aws_ecs_service" "container_reverse_proxy" {
  count           = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name            = local.ecs_nginx_rp_config_s3_main_prefix
  cluster         = data.terraform_remote_state.management.outputs.ecs_cluster_main.id
  task_definition = aws_ecs_task_definition.container_reverse_proxy[0].arn
  desired_count   = length(data.aws_availability_zones.available.names)
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.reverse_proxy_ecs[0].id]
    subnets         = aws_subnet.reverse_proxy_private.*.id
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.reverse_proxy[0].arn
    container_name   = "nginx-s3"
    container_port   = var.reverse_proxy_http_port
  }
}

resource "aws_security_group" "reverse_proxy_ecs" {
  count                  = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name                   = "reverse-proxy-ecs"
  description            = "Reverse Proxy Container in ECS"
  vpc_id                 = module.vpc.vpc.id
  revoke_rules_on_delete = true
}


resource "aws_security_group_rule" "egress_ganglia_endpoint" {
  depends_on               = [aws_vpc_peering_connection_accepter.reverse_proxy_ingest[0]]
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Allow nginx reverse proxy container to reach Ganglia UI"
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = data.terraform_remote_state.ingest.outputs.emr_common_sg.id
  security_group_id        = aws_security_group.reverse_proxy_ecs[0].id
}

resource "aws_security_group_rule" "ingress_ganglia_endpoint" {
  depends_on               = [aws_vpc_peering_connection_accepter.reverse_proxy_ingest[0]]
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Allow Ganglia UI to be reached by nginx reverse proxy container"
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.reverse_proxy_ecs[0].id
  security_group_id        = data.terraform_remote_state.ingest.outputs.emr_common_sg.id
  provider                 = aws.target
}

resource "aws_security_group_rule" "egress_hbase_endpoint" {
  depends_on               = [aws_vpc_peering_connection_accepter.reverse_proxy_ingest[0]]
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Allow nginx reverse proxy container to reach Hbase UI"
  type                     = "egress"
  from_port                = 16010
  to_port                  = 16010
  protocol                 = "tcp"
  source_security_group_id = data.terraform_remote_state.ingest.outputs.emr_common_sg.id
  security_group_id        = aws_security_group.reverse_proxy_ecs[0].id
}

resource "aws_security_group_rule" "ingress_hbase_endpoint" {
  depends_on               = [aws_vpc_peering_connection_accepter.reverse_proxy_ingest[0]]
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Allow Hbase UI to be reached by nginx reverse proxy container"
  type                     = "ingress"
  from_port                = 16010
  to_port                  = 16010
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.reverse_proxy_ecs[0].id
  security_group_id        = data.terraform_remote_state.ingest.outputs.emr_common_sg.id
  provider                 = aws.target
}

resource "aws_security_group_rule" "egress_nm_endpoint" {
  depends_on               = [aws_vpc_peering_connection_accepter.reverse_proxy_ingest[0]]
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Allow nginx reverse proxy container to reach Yarn NodeManager UI"
  type                     = "egress"
  from_port                = 8042
  to_port                  = 8042
  protocol                 = "tcp"
  source_security_group_id = data.terraform_remote_state.ingest.outputs.emr_common_sg.id
  security_group_id        = aws_security_group.reverse_proxy_ecs[0].id
}

resource "aws_security_group_rule" "ingress_nm_endpoint" {
  depends_on               = [aws_vpc_peering_connection_accepter.reverse_proxy_ingest[0]]
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Allow Yarn NodeManager UI to be reached by nginx reverse proxy container"
  type                     = "ingress"
  from_port                = 8042
  to_port                  = 8042
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.reverse_proxy_ecs[0].id
  security_group_id        = data.terraform_remote_state.ingest.outputs.emr_common_sg.id
  provider                 = aws.target
}

resource "aws_security_group_rule" "egress_rm_endpoint" {
  depends_on               = [aws_vpc_peering_connection_accepter.reverse_proxy_ingest[0]]
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Allow nginx reverse proxy container to reach Yarn ResourceManager UI"
  type                     = "egress"
  from_port                = 8088
  to_port                  = 8088
  protocol                 = "tcp"
  source_security_group_id = data.terraform_remote_state.ingest.outputs.emr_common_sg.id
  security_group_id        = aws_security_group.reverse_proxy_ecs[0].id
}

resource "aws_security_group_rule" "ingress_rm_endpoint" {
  depends_on               = [aws_vpc_peering_connection_accepter.reverse_proxy_ingest[0]]
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Allow Yarn ResourceManager UI to be reached by nginx reverse proxy container"
  type                     = "ingress"
  from_port                = 8088
  to_port                  = 8088
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.reverse_proxy_ecs[0].id
  security_group_id        = data.terraform_remote_state.ingest.outputs.emr_common_sg.id
  provider                 = aws.target
}

resource "aws_security_group_rule" "egress_internet_proxy" {
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Allow Internet access via the proxy for reverse proxy container"
  type                     = "egress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.internet_proxy_endpoint.id
  security_group_id        = aws_security_group.reverse_proxy_ecs[0].id
}

resource "aws_security_group_rule" "ingress_internet_proxy" {
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Allow proxy access from reverse proxy container"
  type                     = "ingress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.reverse_proxy_ecs[0].id
  security_group_id        = aws_security_group.internet_proxy_endpoint.id
}

resource "aws_security_group_rule" "reverse_proxy_http_ingress" {
  count             = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description       = "Reverse Proxy Container HTTP Rule"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  cidr_blocks       = [module.vpc.vpc.cidr_block]
  security_group_id = aws_security_group.reverse_proxy_ecs[0].id
}

resource "aws_security_group_rule" "reverse_proxy_http_egress" {
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Allow outbound requests to VPC endpoints (HTTP) from reverse-proxy container"
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = "80"
  to_port                  = "80"
  source_security_group_id = module.vpc.interface_vpce_sg_id
  security_group_id        = aws_security_group.reverse_proxy_ecs[0].id
}

resource "aws_security_group_rule" "vpc_endpoint_http_egress" {
  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description              = "Allow inbound requests to VPC endpoints (HTTP) from reverse-proxy container"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "80"
  to_port                  = "80"
  security_group_id        = module.vpc.interface_vpce_sg_id
  source_security_group_id = aws_security_group.reverse_proxy_ecs[0].id
}

resource "aws_security_group_rule" "reverse_proxy_s3_egress" {
  count             = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description       = "Allow outbound requests to S3 PFL from reverse-proxy container"
  type              = "egress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  prefix_list_ids   = [module.vpc.prefix_list_ids.s3]
  security_group_id = aws_security_group.reverse_proxy_ecs[0].id
}

resource "aws_security_group_rule" "reverse_proxy_s3_https_egress" {
  count             = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  description       = "Allow HTTPS outbound requests to S3 PFL from reverse-proxy container"
  type              = "egress"
  protocol          = "tcp"
  from_port         = "443"
  to_port           = "443"
  prefix_list_ids   = [module.vpc.prefix_list_ids.s3]
  security_group_id = aws_security_group.reverse_proxy_ecs[0].id
}

resource "aws_s3_bucket_object" "nginx_config" {
  count      = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  bucket     = data.terraform_remote_state.management.outputs.config_bucket.id
  key        = "${local.ecs_nginx_rp_config_s3_main_prefix}/nginx_conf_${data.archive_file.nginx_config_files[0].output_md5}.zip"
  kms_key_id = data.terraform_remote_state.management.outputs.config_bucket.cmk_arn
  source     = data.archive_file.nginx_config_files[0].output_path
}

data "archive_file" "nginx_config_files" {
  count       = local.reverse_proxy_enabled[local.environment] ? 1 : 0
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
      target_ip     = data.aws_instance.target_instance[0].private_ip
      target_domain = "ui.ingest-hbase${local.target_env[local.environment]}.${local.fqdn}"
    })
    filename = "conf.d/ganglia.conf"
  }
  source {
    content = templatefile("${path.module}/files/reverse_proxy/hbase.conf.tpl", {
      target_ip     = data.aws_instance.target_instance[0].private_ip
      target_domain = "ui.ingest-hbase${local.target_env[local.environment]}.${local.fqdn}"
    })
    filename = "conf.d/hbase.conf"
  }
  source {
    content = templatefile("${path.module}/files/reverse_proxy/nm.conf.tpl", {
      target_ip     = data.aws_instance.target_instance[0].private_ip
      target_domain = "ui.ingest-hbase${local.target_env[local.environment]}.${local.fqdn}"
    })
    filename = "conf.d/nm.conf"
  }
  source {
    content = templatefile("${path.module}/files/reverse_proxy/rm.conf.tpl", {
      target_ip     = data.aws_instance.target_instance[0].private_ip
      target_domain = "ui.ingest-hbase${local.target_env[local.environment]}.${local.fqdn}"
    })
    filename = "conf.d/rm.conf"
  }
}
