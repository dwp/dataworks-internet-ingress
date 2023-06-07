data "aws_iam_policy_document" "container_reverse_proxy_read_config" {
  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
    ]

    resources = [
      var.config_bucket_arn,
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${var.config_bucket_arn}/${var.ecs_nginx_rp_config_s3_main_prefix}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "kms:Decrypt",
    ]

    resources = [
      var.config_bucket_cmk_arn,
    ]
  }
}

resource "aws_iam_role" "container_reverse_proxy" {
  name               = "ReverseProxy"
  assume_role_policy = var.ecs_assume_role_policy_json
  tags               = var.common_tags
}

resource "aws_iam_role_policy" "container_reverse_proxy" {
  policy = data.aws_iam_policy_document.container_reverse_proxy_read_config.json
  role   = aws_iam_role.container_reverse_proxy.id
}

resource "aws_cloudwatch_log_group" "reverse_proxy_ecs" {
  name              = var.cloudwatch_log_group_name
  retention_in_days = 30
  tags              = var.common_tags
}

resource "aws_ecs_task_definition" "container_reverse_proxy" {
  family                   = "nginx-s3"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "4096"
  task_role_arn            = aws_iam_role.container_reverse_proxy.arn
  execution_role_arn       = var.ecs_task_execution_role_arn

  container_definitions = <<DEFINITION
[
  {
    "image": "${var.reverse_proxy_image_url}",
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
        "awslogs-region": "${var.region}",
        "awslogs-stream-prefix": "${var.ecs_nginx_rp_config_s3_main_prefix}"
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
        "value": "${var.config_bucket_id}"
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
  name            = var.ecs_nginx_rp_config_s3_main_prefix
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.container_reverse_proxy.arn
  desired_count   = length(var.aws_availability_zones)
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.reverse_proxy_ecs.id]
    subnets         = var.subnet_ids
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
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true
}

resource "aws_s3_object" "nginx_config" {
  bucket     = data.terraform_remote_state.management.outputs.config_bucket.id
  key        = "${var.ecs_nginx_rp_config_s3_main_prefix}/nginx_conf_${data.archive_file.nginx_config_files.output_md5}.zip"
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
