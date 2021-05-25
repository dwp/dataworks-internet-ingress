resource "aws_vpc_peering_connection" "ssh_bastion" {
  count         = local.deploy_ithc_infra[local.environment] ? 1 : 0
  peer_owner_id = local.account[local.environment]
  peer_vpc_id   = module.vpc.vpc.id
  vpc_id        = data.terraform_remote_state.management.outputs.networking.vpc.id

  tags = merge(
    local.common_tags,
    { Name = "Crypto to Internet Ingress (${local.environment})" }
  )
}

resource "aws_vpc_peering_connection_accepter" "ssh_bastion" {
  count                     = local.deploy_ithc_infra[local.environment] ? 1 : 0
  provider                  = aws.ssh_bastion
  vpc_peering_connection_id = aws_vpc_peering_connection.ssh_bastion.0.id
  auto_accept               = true

  tags = merge(
    local.common_tags,
    { Name = "Crypto to Internet Ingress (${local.environment})" }
  )
}

resource "aws_route" "crypto_to_ssh_bastion" {
  count                     = local.deploy_ithc_infra[local.environment] ? length(aws_subnet.ssh_bastion.*.cidr_block) : 0
  destination_cidr_block    = aws_subnet.ssh_bastion[count.index].cidr_block
  route_table_id            = data.terraform_remote_state.management.outputs.packer.route_table.id
  vpc_peering_connection_id = aws_vpc_peering_connection.ssh_bastion.0.id
}

resource "aws_route" "ssh_bastion_to_crypto" {
  provider                  = aws.ssh_bastion
  count                     = local.deploy_ithc_infra[local.environment] ? length(data.terraform_remote_state.management.outputs.packer.subnets.id) : 0
  destination_cidr_block    = data.terraform_remote_state.management.outputs.packer.subnets[count.index].cidr_block
  route_table_id            = aws_route_table.ssh_bastion.0.id
  vpc_peering_connection_id = aws_vpc_peering_connection.ssh_bastion.0.id
}

resource "aws_security_group_rule" "kali_allow_ssh_ingress" {
  // cross account SG references require the VPC Peering Connection to be active
  depends_on               = [aws_vpc_peering_connection_accepter.ssh_bastion.0]
  count                    = local.deploy_ithc_infra[local.environment] ? 1 : 0
  description              = "Allow SSH access from bastion hosts"
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ssh_bastion.0.id
  security_group_id        = aws_security_group.kali.0.id
}

resource "aws_security_group_rule" "ssh_bastion_allow_ssh_egress" {
  // cross account SG references require the VPC Peering Connection to be active
  depends_on               = [aws_vpc_peering_connection_accepter.ssh_bastion.0]
  count                    = local.deploy_ithc_infra[local.environment] ? 1 : 0
  provider                 = aws.ssh_bastion
  description              = "Allow SSH access to Crypto"
  type                     = "egress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = data.terraform_remote_state.management.outputs.security_groups.kali.id
  security_group_id        = aws_security_group.ssh_bastion.0.id
}
