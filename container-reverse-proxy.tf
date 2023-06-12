module "reverse_proxy" {
  source = "./modules/reverse-proxy"

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

  nginx_config_file_path      = data.archive_file.nginx_config_files.output_path
  nginx_config_md5            = data.archive_file.nginx_config_files.output_md5
  nginx_config_bucket         = data.terraform_remote_state.management.outputs.config_bucket.id
  nginx_config_bucket_cmk_arn = data.terraform_remote_state.management.outputs.config_bucket.cmk_arn

  team_cidr_blocks = local.team_cidr_blocks

  reverse_proxy_alb_subnets = aws_subnet.reverse_proxy_public.*.id

  common_tags = local.common_tags
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
    content  = module.hbase-nginx-entries.ganglia_nginx_config
    filename = "conf.d/ganglia.conf"
  }
  source {
    content  = module.hbase-nginx-entries.hbase_nginx_config
    filename = "conf.d/hbase.conf"
  }
  source {
    content  = module.hbase-nginx-entries.node_manager_nginx_config
    filename = "conf.d/nm.conf"
  }
  source {
    content  = module.hbase-nginx-entries.resource_manager_nginx_config
    filename = "conf.d/rm.conf"
  }
}
