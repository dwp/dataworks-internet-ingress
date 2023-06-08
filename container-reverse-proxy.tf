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

