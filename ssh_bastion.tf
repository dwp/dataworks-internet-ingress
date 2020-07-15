resource "aws_security_group" "ssh_bastion" {
  count       = local.ssh_bastion_enabled[local.environment] ? 1 : 0
  name        = "ssh-bastion"
  description = "SSH Bastion Hosts"
  vpc_id      = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    { Name = "ssh-bastion" }
  )
}

resource "aws_security_group_rule" "bastion_ssh_ingress" {
  count             = local.ssh_bastion_enabled[local.environment] ? 1 : 0
  description       = "Allow SSH access"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = concat(local.ssh_bastion_whitelisted_ranges, [local.team_cidr_block])
  security_group_id = aws_security_group.ssh_bastion.0.id
}

resource "aws_security_group_rule" "bastion_nlb_healthcheck_ingress" {
  count             = local.ssh_bastion_enabled[local.environment] ? 1 : 0
  description       = "Allow LB Healthcheck access"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [module.vpc.vpc.cidr_block]
  security_group_id = aws_security_group.ssh_bastion.0.id
}

resource "aws_route_table" "ssh_bastion" {
  count  = local.ssh_bastion_enabled[local.environment] ? 1 : 0
  vpc_id = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    { Name = "ssh_bastion" },
  )
}

resource "aws_route" "ssh_bastion_igw" {
  count                  = local.ssh_bastion_enabled[local.environment] ? 1 : 0
  route_table_id         = aws_route_table.ssh_bastion[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "ssh_bastion" {
  count          = local.ssh_bastion_enabled[local.environment] ? length(data.aws_availability_zones.available.names) : 0
  subnet_id      = aws_subnet.ssh_bastion.*.id[count.index]
  route_table_id = aws_route_table.ssh_bastion[0].id
}

data "aws_iam_policy_document" "ssh_bastion_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "ec2.amazonaws.com",
      ]
    }

    actions = [
      "sts:AssumeRole",
    ]
  }
}

resource "aws_iam_role" "ssh_bastion" {
  count              = local.ssh_bastion_enabled[local.environment] ? 1 : 0
  name               = "ssh_bastion"
  assume_role_policy = data.aws_iam_policy_document.ssh_bastion_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssh_bastion_ssm_role" {
  count      = local.ssh_bastion_enabled[local.environment] ? 1 : 0
  role       = aws_iam_role.ssh_bastion[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssh_bastion_cw_role" {
  count      = local.ssh_bastion_enabled[local.environment] ? 1 : 0
  role       = aws_iam_role.ssh_bastion[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ssh_bastion" {
  count = local.ssh_bastion_enabled[local.environment] ? 1 : 0
  name  = "ssh_bastion"
  role  = aws_iam_role.ssh_bastion[0].name
}

resource "aws_launch_configuration" "ssh_bastion" {
  count                = local.ssh_bastion_enabled[local.environment] ? 1 : 0
  name_prefix          = "ssh-bastion-"
  image_id             = var.ssh_bastion_ami_id
  instance_type        = "t2.medium"
  security_groups      = [aws_security_group.ssh_bastion[0].id]
  iam_instance_profile = aws_iam_instance_profile.ssh_bastion[0].arn
  user_data            = templatefile("${path.module}/ssh_bastion_users.cloud-cfg.tmpl", { users = local.ssh_bastion_users })

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 50
    delete_on_termination = true
    encrypted             = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "ssh_bastion" {
  count                     = local.ssh_bastion_enabled[local.environment] ? 1 : 0
  name                      = aws_launch_configuration.ssh_bastion[0].name
  min_size                  = 3
  desired_capacity          = 3
  max_size                  = 3
  health_check_grace_period = 180
  health_check_type         = "EC2"
  force_delete              = true
  launch_configuration      = aws_launch_configuration.ssh_bastion[0].name
  vpc_zone_identifier       = aws_subnet.ssh_bastion.*.id
  target_group_arns         = [aws_lb_target_group.ssh_bastion[0].arn]

  dynamic "tag" {
    for_each = merge(
      local.common_tags,
      { Name         = "ssh-bastion",
        Persistence  = "Ignore",
        AutoShutdown = "False",
        SSMEnabled   = local.ssh_bastion_ssmenabled[local.environment]
      },
    )

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "ssh_bastion" {
  count              = local.ssh_bastion_enabled[local.environment] ? 1 : 0
  name               = "ssh-bastion"
  internal           = false
  load_balancer_type = "network"
  depends_on         = [aws_internet_gateway.igw]
  subnets = [aws_subnet.ssh_bastion[0].id,
    aws_subnet.ssh_bastion[1].id,
  aws_subnet.ssh_bastion[2].id]

  tags = merge(
    local.common_tags,
    { Name = "ssh-bastion" }
  )
}

resource "aws_lb_target_group" "ssh_bastion" {
  count       = local.ssh_bastion_enabled[local.environment] ? 1 : 0
  name        = "ssh-bastion"
  port        = 22
  protocol    = "TCP"
  target_type = "instance"
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
    { Name = "ssh-bastion" },
  )
}

resource "aws_lb_listener" "ssh" {
  count             = local.ssh_bastion_enabled[local.environment] ? 1 : 0
  load_balancer_arn = aws_lb.ssh_bastion[0].arn
  port              = 22
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ssh_bastion[0].arn
  }
}
