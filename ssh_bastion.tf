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

resource "aws_instance" "ssh_bastion" {
  count                  = local.ssh_bastion_enabled[local.environment] ? 1 : 0
  ami                    = var.ssh_bastion_ami_id
  instance_type          = "t2.medium"
  vpc_security_group_ids = [aws_security_group.ssh_bastion.0.id]
  subnet_id              = element(aws_subnet.ssh_bastion.*.id, count.index)
  iam_instance_profile   = aws_iam_instance_profile.ssh_bastion[0].name
  user_data              = templatefile("${path.module}/ssh_bastion_users.cloud-cfg.tmpl", { users = local.ssh_bastion_users })

  tags = merge(
    local.common_tags,
    { Name = "ssh-bastion" }
  )
}

resource "aws_eip" "ssh_bastion" {
  count    = local.ssh_bastion_enabled[local.environment] ? length(aws_instance.ssh_bastion.*.id) : 0
  vpc      = true
  instance = aws_instance.ssh_bastion[count.index].id

  tags = merge(
    local.common_tags,
    { Name = "ssh-bastion" }
  )

}

resource "aws_route53_record" "ssh_bastion" {
  count    = local.ssh_bastion_enabled[local.environment] ? 1 : 0
  zone_id  = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id
  name     = "bastion.${local.dw_domain}"
  type     = "A"
  ttl      = "60"
  records  = [aws_eip.ssh_bastion[0].public_ip]
  provider = aws.management_dns
}
