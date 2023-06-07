module "reverse_proxy" {
  source = "../modules/reverse_proxy"

  region                 = data.aws_region.current.name
  vpc_id                 = module.vpc.vpc.id
  aws_availability_zones = data.aws_availability_zones.available.names
  subnet_ids             = aws_subnet.reverse_proxy_private.*.id

  config_bucket_arn     = data.terraform_remote_state.management.outputs.config_bucket.arn
  config_bucket_id      = data.terraform_remote_state.management.outputs.config_bucket.id
  config_bucket_cmk_arn = data.terraform_remote_state.management.outputs.config_bucket.cmk_arn

  ecs_nginx_rp_config_s3_main_prefix = local.ecs_nginx_rp_config_s3_main_prefix
  ecs_assume_role_policy_json        = data.terraform_remote_state.management.outputs.ecs_assume_role_policy_json
  ecs_task_execution_role_arn        = data.terraform_remote_state.management.outputs.ecs_task_execution_role.arn
  ecs_cluster_id                     = data.terraform_remote_state.management.outputs.ecs_cluster_main.id

  reverse_proxy_image_url = "${local.account[local.environment]}.${module.vpc.ecr_dkr_domain_name}/nginx-s3:latest"
  reverse_proxy_http_port = var.reverse_proxy_http_port

  common_tags = local.common_tags
}

data "aws_instances" "target_instance" {
  instance_tags = {
    "ShortName"                                = "ingest-hbase",
    "aws:elasticmapreduce:instance-group-role" = "MASTER"
  }
  provider = aws.target
}

resource "aws_security_group_rule" "egress_internet_proxy" {
  description              = "Allow Internet access via the proxy for reverse proxy container"
  type                     = "egress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.internet_proxy_endpoint.id
  security_group_id        = module.reverse_proxy.reverse_proxy_ecs_id
}

resource "aws_security_group_rule" "ingress_internet_proxy" {
  description              = "Allow proxy access from reverse proxy container"
  type                     = "ingress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  source_security_group_id = module.reverse_proxy.reverse_proxy_ecs_id
  security_group_id        = aws_security_group.internet_proxy_endpoint.id
}

resource "aws_security_group_rule" "reverse_proxy_http_ingress" {
  description       = "Reverse Proxy Container HTTP Rule"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  cidr_blocks       = [module.vpc.vpc.cidr_block]
  security_group_id = module.reverse_proxy.reverse_proxy_ecs_id
}

resource "aws_security_group_rule" "reverse_proxy_http_egress" {
  description              = "Allow outbound requests to VPC endpoints (HTTP) from reverse-proxy container"
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = "80"
  to_port                  = "80"
  source_security_group_id = module.vpc.interface_vpce_sg_id
  security_group_id        = module.reverse_proxy.reverse_proxy_ecs_id
}

resource "aws_security_group_rule" "vpc_endpoint_http_egress" {
  description              = "Allow inbound requests to VPC endpoints (HTTP) from reverse-proxy container"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "80"
  to_port                  = "80"
  security_group_id        = module.vpc.interface_vpce_sg_id
  source_security_group_id = module.reverse_proxy.reverse_proxy_ecs_id
}

resource "aws_security_group_rule" "reverse_proxy_s3_egress" {
  description       = "Allow outbound requests to S3 PFL from reverse-proxy container"
  type              = "egress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  prefix_list_ids   = [module.vpc.prefix_list_ids.s3]
  security_group_id = module.reverse_proxy.reverse_proxy_ecs_id
}

resource "aws_security_group_rule" "reverse_proxy_s3_https_egress" {
  description       = "Allow HTTPS outbound requests to S3 PFL from reverse-proxy container"
  type              = "egress"
  protocol          = "tcp"
  from_port         = "443"
  to_port           = "443"
  prefix_list_ids   = [module.vpc.prefix_list_ids.s3]
  security_group_id = module.reverse_proxy.reverse_proxy_ecs_id
}