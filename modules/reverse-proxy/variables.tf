variable "config_bucket_arn" {
  type = string
}

variable "config_bucket_id" {
  type = string
}

variable "config_bucket_cmk_arn" {
  type = string
}

variable "ecs_nginx_rp_config_s3_main_prefix" {
  type = string
}

variable "ecs_assume_role_policy_json" {
  type = string
}

variable "ecs_task_execution_role_arn" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "cloudwatch_log_group_name" {
  type    = string
  default = "/aws/ecs/main/reverse-proxy"
}

variable "reverse_proxy_image_url" {
  type = string
}

variable "reverse_proxy_http_port" {
  type = string
}

variable "region" {
  type = string
}

variable "ecs_cluster_id" {
  type = string
}

variable "aws_availability_zones" {
  type = list(any)
}

variable "subnet_ids" {
  type = list(any)
}

variable "vpc_id" {
  type = string
}
