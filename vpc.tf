module "vpc" {
  source                                   = "dwp/vpc/aws"
  version                                  = "3.0.8"
  vpc_name                                 = "internet-ingress"
  region                                   = var.region
  vpc_cidr_block                           = local.cidr_block[local.environment]["internet-ingress-vpc"]
  interface_vpce_source_security_group_ids = concat(local.reverse_proxy_enabled[local.environment] ? [aws_security_group.reverse_proxy_ecs[0].id] : [], local.ssh_bastion_enabled[local.environment] ? [aws_security_group.ssh_bastion[0].id] : [])
  interface_vpce_subnet_ids                = aws_subnet.vpc_endpoint.*.id
  gateway_vpce_route_table_ids             = aws_route_table.reverse_proxy_private.*.id
  aws_vpce_services = [
    "logs",
    "s3",
    "ec2",
    "ec2messages",
    "kms",
    "monitoring",
    "ssm",
    "ssmmessages",
    "ecr.dkr",
    "ecr.api"
  ]
}

resource "aws_subnet" "vpc_endpoint" {
  count             = length(data.aws_availability_zones.available.names)
  cidr_block        = cidrsubnet(module.vpc.vpc.cidr_block, 4, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    { Name = "vpc-endpoint" }
  )
}

resource "aws_subnet" "ssh_bastion" {
  count = local.ssh_bastion_enabled[local.environment] ? length(data.aws_availability_zones.available.names) : 0
  // start after the reverse_proxy subnets
  cidr_block        = cidrsubnet(module.vpc.vpc.cidr_block, 4, count.index + 3 + 3)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    { Name = "ssh-bastion" }
  )
}

resource "aws_subnet" "reverse_proxy_public" {
  count = length(data.aws_availability_zones.available.names)
  // start after the vpc_endpoint subnets
  cidr_block        = cidrsubnet(module.vpc.vpc.cidr_block, 4, count.index + 3)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    { Name = "reverse-proxy-public" }
  )
}

resource "aws_route_table" "reverse_proxy_public" {
  count  = length(data.aws_availability_zones.available.names)
  vpc_id = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    { Name = "reverse_proxy_public" },
  )
}

resource "aws_route_table_association" "reverse_proxy_public" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = aws_subnet.reverse_proxy_public[count.index].id
  route_table_id = aws_route_table.reverse_proxy_public[count.index].id
}

resource "aws_route" "reverse_proxy_public_default_route" {
  count                  = length(data.aws_availability_zones.available.names)
  route_table_id         = aws_route_table.reverse_proxy_public[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_subnet" "reverse_proxy_private" {
  count = length(data.aws_availability_zones.available.names)
  // start after the vpc_endpoint subnets
  cidr_block        = cidrsubnet(module.vpc.vpc.cidr_block, 4, count.index + 3 + 3 + 3)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    { Name = "reverse-proxy-private" }
  )
}

resource "aws_route_table" "reverse_proxy_private" {
  count  = length(data.aws_availability_zones.available.names)
  vpc_id = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    { Name = "reverse_proxy_private" },
  )
}

resource "aws_route_table_association" "reverse_proxy_private" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = aws_subnet.reverse_proxy_private[count.index].id
  route_table_id = aws_route_table.reverse_proxy_private[count.index].id
}

resource "aws_route" "reverse_proxy_private_default_route" {
  count                  = length(data.aws_availability_zones.available.names)
  route_table_id         = aws_route_table.reverse_proxy_private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    { Name = "internet-ingress" },
  )
}

resource "aws_eip" "nat_gw" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_gw.id
  subnet_id     = aws_subnet.reverse_proxy_public[0].id

  tags = merge(
    local.common_tags,
    { Name = "internet-ingress" },
  )
}

resource "aws_security_group" "internet_proxy_endpoint" {
  name        = "internet_endpoint"
  description = "Control access to the Internet Proxy VPC Endpoint"
  vpc_id      = module.vpc.vpc.id
}

resource "aws_vpc_endpoint" "internet_proxy" {
  vpc_id              = module.vpc.vpc.id
  service_name        = data.terraform_remote_state.internet_egress.outputs.internet_proxy_service.service_name
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.internet_proxy_endpoint.id]
  subnet_ids          = aws_subnet.vpc_endpoint.*.id
  private_dns_enabled = false
}

resource "aws_vpc_peering_connection" "reverse_proxy" {
  count         = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  peer_owner_id = local.account[local.mgmt_account_mapping[local.environment]]
  peer_vpc_id   = data.terraform_remote_state.ingest.outputs.ingestion_vpc.id
  vpc_id        = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    { Name = "reverse-proxy" }
  )
}

resource "aws_route" "reverse_proxy_to_ingest" {
  count                     = local.reverse_proxy_enabled[local.environment] ? length(data.aws_availability_zones.available.names) : 0
  route_table_id            = aws_route_table.reverse_proxy_private[count.index].id
  destination_cidr_block    = data.terraform_remote_state.ingest.outputs.ingestion_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.reverse_proxy[0].id
}

resource "aws_route" "ingest_to_reverse_proxy" {
  count                     = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  route_table_id            = data.terraform_remote_state.ingest.outputs.emr_route_table.id
  destination_cidr_block    = module.vpc.vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.reverse_proxy[0].id
  provider                  = aws.target
}

resource "aws_vpc_peering_connection_accepter" "reverse_proxy_ingest" {
  count                     = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  vpc_peering_connection_id = aws_vpc_peering_connection.reverse_proxy[0].id
  auto_accept               = true

  tags = merge(
    local.common_tags,
    { Name = "reverse-proxy" }
  )

  provider = aws.target
}

resource "aws_vpc_peering_connection" "reverse_proxy_internal_compute" {
  count         = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  peer_owner_id = local.account[local.mgmt_account_mapping[local.environment]]
  peer_vpc_id   = data.terraform_remote_state.internal_compute.outputs.vpc.vpc.vpc.id
  vpc_id        = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    { Name = "reverse-proxy" }
  )
}

resource "aws_route" "reverse_proxy_to_internal_compute" {
  count                     = local.reverse_proxy_enabled[local.environment] ? length(data.aws_availability_zones.available.names) : 0
  route_table_id            = aws_route_table.reverse_proxy_private[count.index].id
  destination_cidr_block    = data.terraform_remote_state.internal_compute.outputs.vpc.vpc.vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.reverse_proxy_internal_compute[0].id
}

resource "aws_route" "internal_compute_to_reverse_proxy" {
  count                     = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  route_table_id            = data.terraform_remote_state.internal_compute.outputs.hbase_emr_route_table.id
  destination_cidr_block    = module.vpc.vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.reverse_proxy_internal_compute[0].id
  provider                  = aws.target
}

resource "aws_vpc_peering_connection_accepter" "reverse_proxy_internal_compute" {
  count                     = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  vpc_peering_connection_id = aws_vpc_peering_connection.reverse_proxy[0].id
  auto_accept               = true

  tags = merge(
    local.common_tags,
    { Name = "reverse-proxy" }
  )

  provider = aws.target
}
