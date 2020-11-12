//data "aws_instance" "target_instance" {
//  count = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  filter {
//    name   = "tag:Name"
//    values = ["ingest-hbase"]
//  }
//  filter {
//    name   = "tag:aws:elasticmapreduce:instance-group-role"
//    values = ["MASTER"]
//  }
//  provider = aws.target
//}
//
//data "template_file" "reverse_proxy_user_data" {
//  count    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  template = file("files/reverse_proxy/reverse_proxy_user_data.tpl")
//
//  vars = {
//    target_ip     = data.aws_instance.target_instance[0].private_ip
//    target_domain = "ui.ingest-hbase${local.target_env[local.environment]}.${local.fqdn}"
//  }
//}
//
//resource "aws_launch_configuration" "reverse_proxy" {
//  count                = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  name_prefix          = "reverse-proxy-"
//  image_id             = "ami-0c5ccbc9bd5bb0b48" // latest hardened-ami
//  instance_type        = "t2.xlarge"
//  security_groups      = [aws_security_group.reverse_proxy_instance[0].id]
//  iam_instance_profile = aws_iam_instance_profile.reverse_proxy[0].arn
//  user_data            = base64encode(data.template_file.reverse_proxy_user_data[0].rendered)
//
//  root_block_device {
//    volume_type           = "gp2"
//    volume_size           = 50
//    delete_on_termination = true
//    encrypted             = true
//  }
//
//  lifecycle {
//    create_before_destroy = true
//  }
//}
//
//resource "aws_autoscaling_group" "reverse_proxy" {
//  count                     = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  name                      = aws_launch_configuration.reverse_proxy[0].name
//  min_size                  = 1
//  desired_capacity          = 1
//  max_size                  = 1
//  health_check_grace_period = 180
//  health_check_type         = "EC2"
//  force_delete              = true
//  launch_configuration      = aws_launch_configuration.reverse_proxy[0].name
//  vpc_zone_identifier       = aws_subnet.reverse_proxy_private.*.id
//  target_group_arns         = [aws_lb_target_group.reverse_proxy[0].arn]
//
//  dynamic "tag" {
//    for_each = merge(
//      local.common_tags,
//      { Name         = "reverse_proxy_host",
//        Persistence  = "Ignore",
//        AutoShutdown = "False",
//        SSMEnabled   = local.reverse_proxy_ssmenabled[local.environment]
//      },
//    )
//
//    content {
//      key                 = tag.key
//      value               = tag.value
//      propagate_at_launch = true
//    }
//  }
//
//  lifecycle {
//    create_before_destroy = true
//  }
//}
//
//resource "aws_iam_instance_profile" "reverse_proxy" {
//  count = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  name  = "reverse_proxy"
//  role  = aws_iam_role.reverse_proxy[0].name
//}
//
//resource "aws_iam_role" "reverse_proxy" {
//  count              = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  name               = "reverse_proxy"
//  assume_role_policy = data.aws_iam_policy_document.reverse_proxy_assume_role.json
//  tags               = local.common_tags
//}
//
//resource "aws_iam_role_policy_attachment" "reverse_proxy_ssm_role" {
//  count      = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  role       = aws_iam_role.reverse_proxy[0].name
//  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
//}
//
//resource "aws_iam_role_policy_attachment" "reverse_proxy_cw_role" {
//  count      = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  role       = aws_iam_role.reverse_proxy[0].name
//  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
//}
//
//data "aws_iam_policy_document" "reverse_proxy_assume_role" {
//  statement {
//    effect = "Allow"
//
//    principals {
//      type = "Service"
//
//      identifiers = [
//        "ec2.amazonaws.com",
//      ]
//    }
//
//    actions = [
//      "sts:AssumeRole",
//    ]
//  }
//}
//
//resource "aws_security_group" "reverse_proxy_instance" {
//  count                  = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  name                   = "reverse-proxy-instance"
//  description            = "Reverse Proxy Instance"
//  vpc_id                 = module.vpc.vpc.id
//  revoke_rules_on_delete = true
//
//  lifecycle {
//    create_before_destroy = true
//  }
//}
//
//resource "aws_security_group_rule" "egress_ganglia_endpoint" {
//  depends_on               = [aws_vpc_peering_connection_accepter.reverse_proxy_ingest[0], aws_vpc_peering_connection_accepter.reverse_proxy_internal_compute[0]]
//  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  description              = "Allow nginx reverse proxy to reach Ganglia UI"
//  type                     = "egress"
//  from_port                = 80
//  to_port                  = 80
//  protocol                 = "tcp"
//  source_security_group_id = data.terraform_remote_state.internal_compute.outputs.aws_emr_cluster.common_sg_id
//  security_group_id        = aws_security_group.reverse_proxy_instance[0].id
//}
//
//resource "aws_security_group_rule" "ingress_ganglia_endpoint" {
//  depends_on               = [aws_vpc_peering_connection_accepter.reverse_proxy_ingest[0], aws_vpc_peering_connection_accepter.reverse_proxy_internal_compute[0]]
//  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  description              = "Allow Ganglia UI to be reached by nginx reverse proxy"
//  type                     = "ingress"
//  from_port                = 80
//  to_port                  = 80
//  protocol                 = "tcp"
//  source_security_group_id = aws_security_group.reverse_proxy_instance[0].id
//  security_group_id        = data.terraform_remote_state.internal_compute.outputs.aws_emr_cluster.common_sg_id
//  provider                 = aws.target
//}
//
//resource "aws_security_group_rule" "egress_hbase_endpoint" {
//  depends_on               = [aws_vpc_peering_connection_accepter.reverse_proxy_ingest[0], aws_vpc_peering_connection_accepter.reverse_proxy_internal_compute[0]]
//  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  description              = "Allow nginx reverse proxy to reach Hbase UI"
//  type                     = "egress"
//  from_port                = 16010
//  to_port                  = 16010
//  protocol                 = "tcp"
//  source_security_group_id = data.terraform_remote_state.internal_compute.outputs.aws_emr_cluster.common_sg_id
//  security_group_id        = aws_security_group.reverse_proxy_instance[0].id
//}
//
//resource "aws_security_group_rule" "ingress_hbase_endpoint" {
//  depends_on               = [aws_vpc_peering_connection_accepter.reverse_proxy_ingest[0], aws_vpc_peering_connection_accepter.reverse_proxy_internal_compute[0]]
//  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  description              = "Allow Hbase UI to be reached by nginx reverse proxy"
//  type                     = "ingress"
//  from_port                = 16010
//  to_port                  = 16010
//  protocol                 = "tcp"
//  source_security_group_id = aws_security_group.reverse_proxy_instance[0].id
//  security_group_id        = data.terraform_remote_state.internal_compute.outputs.aws_emr_cluster.common_sg_id
//  provider                 = aws.target
//}
//
//resource "aws_security_group_rule" "egress_nm_endpoint" {
//  depends_on               = [aws_vpc_peering_connection_accepter.reverse_proxy_ingest[0], aws_vpc_peering_connection_accepter.reverse_proxy_internal_compute[0]]
//  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  description              = "Allow nginx reverse proxy to reach Yarn NodeManager UI"
//  type                     = "egress"
//  from_port                = 8042
//  to_port                  = 8042
//  protocol                 = "tcp"
//  source_security_group_id = data.terraform_remote_state.internal_compute.outputs.aws_emr_cluster.common_sg_id
//  security_group_id        = aws_security_group.reverse_proxy_instance[0].id
//}
//
//resource "aws_security_group_rule" "ingress_nm_endpoint" {
//  depends_on               = [aws_vpc_peering_connection_accepter.reverse_proxy_ingest[0], aws_vpc_peering_connection_accepter.reverse_proxy_internal_compute[0]]
//  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  description              = "Allow Yarn NodeManager UI to be reached by nginx reverse proxy"
//  type                     = "ingress"
//  from_port                = 8042
//  to_port                  = 8042
//  protocol                 = "tcp"
//  source_security_group_id = aws_security_group.reverse_proxy_instance[0].id
//  security_group_id        = data.terraform_remote_state.internal_compute.outputs.aws_emr_cluster.common_sg_id
//  provider                 = aws.target
//}
//
//resource "aws_security_group_rule" "egress_rm_endpoint" {
//  depends_on               = [aws_vpc_peering_connection_accepter.reverse_proxy_ingest[0], aws_vpc_peering_connection_accepter.reverse_proxy_internal_compute[0]]
//  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  description              = "Allow nginx reverse proxy to reach Yarn ResourceManager UI"
//  type                     = "egress"
//  from_port                = 8088
//  to_port                  = 8088
//  protocol                 = "tcp"
//  source_security_group_id = data.terraform_remote_state.internal_compute.outputs.aws_emr_cluster.common_sg_id
//  security_group_id        = aws_security_group.reverse_proxy_instance[0].id
//}
//
//resource "aws_security_group_rule" "ingress_rm_endpoint" {
//  depends_on               = [aws_vpc_peering_connection_accepter.reverse_proxy_ingest[0], aws_vpc_peering_connection_accepter.reverse_proxy_internal_compute[0]]
//  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  description              = "Allow Yarn ResourceManager UI to be reached by nginx reverse proxy"
//  type                     = "ingress"
//  from_port                = 8088
//  to_port                  = 8088
//  protocol                 = "tcp"
//  source_security_group_id = aws_security_group.reverse_proxy_instance[0].id
//  security_group_id        = data.terraform_remote_state.internal_compute.outputs.aws_emr_cluster.common_sg_id
//  provider                 = aws.target
//}
//
//resource "aws_security_group_rule" "egress_internet_proxy" {
//  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  description              = "Allow Internet access via the proxy for reverse proxy"
//  type                     = "egress"
//  from_port                = 3128
//  to_port                  = 3128
//  protocol                 = "tcp"
//  source_security_group_id = aws_security_group.internet_proxy_endpoint.id
//  security_group_id        = aws_security_group.reverse_proxy_instance[0].id
//}
//
//resource "aws_security_group_rule" "ingress_internet_proxy" {
//  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  description              = "Allow proxy access from reverse proxy"
//  type                     = "ingress"
//  from_port                = 3128
//  to_port                  = 3128
//  protocol                 = "tcp"
//  source_security_group_id = aws_security_group.reverse_proxy_instance[0].id
//  security_group_id        = aws_security_group.internet_proxy_endpoint.id
//}
//
//resource "aws_security_group_rule" "reverse_proxy_http_ingress" {
//  count             = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  description       = "Reverse Proxy HTTP Rule"
//  type              = "ingress"
//  protocol          = "tcp"
//  from_port         = "80"
//  to_port           = "80"
//  cidr_blocks       = [module.vpc.vpc.cidr_block]
//  security_group_id = aws_security_group.reverse_proxy_instance[0].id
//}
//
//resource "aws_security_group_rule" "reverse_proxy_http_egress" {
//  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  description              = "Allow outbound requests to VPC endpoints (HTTP)"
//  type                     = "egress"
//  protocol                 = "tcp"
//  from_port                = "80"
//  to_port                  = "80"
//  source_security_group_id = module.vpc.interface_vpce_sg_id
//  security_group_id        = aws_security_group.reverse_proxy_instance[0].id
//}
//
//resource "aws_security_group_rule" "vpc_endpoint_http_egress" {
//  count                    = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  description              = "Allow inbound requests to VPC endpoints (HTTP)"
//  type                     = "ingress"
//  protocol                 = "tcp"
//  from_port                = "80"
//  to_port                  = "80"
//  security_group_id        = module.vpc.interface_vpce_sg_id
//  source_security_group_id = aws_security_group.reverse_proxy_instance[0].id
//}
//
//resource "aws_security_group_rule" "reverse_proxy_s3_egress" {
//  count             = local.reverse_proxy_enabled[local.environment] ? 1 : 0
//  description       = "Allow outbound requests to S3 PFL"
//  type              = "egress"
//  protocol          = "tcp"
//  from_port         = "80"
//  to_port           = "80"
//  prefix_list_ids   = [module.vpc.prefix_list_ids.s3]
//  security_group_id = aws_security_group.reverse_proxy_instance[0].id
//}