module "vpc" {
  source                                   = "dwp/vpc/aws"
  version                                  = "3.0.3"
  vpc_name                                 = "internet-ingress"
  region                                   = var.region
  vpc_cidr_block                           = local.cidr_block[local.environment]["internet-ingress-vpc"]
  interface_vpce_source_security_group_ids = [aws_security_group.reverse_proxy_instance.id]
  interface_vpce_subnet_ids                = aws_subnet.reverse_proxy.*.id
  gateway_vpce_route_table_ids             = aws_route_table.reverse_proxy.*.id

  aws_vpce_services = [
    "logs",
    "s3",
    "ec2",
    "ec2messages",
    "kms",
    "monitoring",
    "ssm",
    "ssmmessages"
  ]
}

resource "aws_route_table" "reverse_proxy" {
  vpc_id = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    { Name = "reverse_proxy" },
  )
}

resource "aws_subnet" "vpc_endpoint" {
  count             = length(data.aws_availability_zones.available.names)
  cidr_block        = cidrsubnet(module.vpc.vpc.cidr_block, 3, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    { Name = "reverse-proxy" }
  )
}

resource "aws_subnet" "internet_proxy" {
  count             = length(data.aws_availability_zones.available.names)
  cidr_block        = cidrsubnet(module.vpc.vpc.cidr_block, 3, count.index + length(aws_subnet.vpc_endpoint))
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    { Name = "reverse-proxy" }
  )
}

resource "aws_subnet" "reverse_proxy" {
  count             = length(data.aws_availability_zones.available.names)
  cidr_block        = cidrsubnet(module.vpc.vpc.cidr_block, 3, count.index + length(aws_subnet.vpc_endpoint) + length(aws_subnet.internet_proxy))
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = module.vpc.vpc.id

  tags = merge(
    local.common_tags,
    { Name = "reverse-proxy" }
  )
}

resource "aws_route_table_association" "reverse_proxy" {
  count          = length(data.aws_availability_zones.available.names)
  subnet_id      = aws_subnet.reverse_proxy.*.id[count.index]
  route_table_id = aws_route_table.reverse_proxy.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = module.vpc.vpc.id

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
  subnet_ids          = aws_subnet.internet_proxy.*.id
  private_dns_enabled = false
}

resource "aws_security_group_rule" "egress_internet_proxy" {
  description              = "Allow Internet access via the proxy"
  type                     = "egress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.internet_proxy_endpoint.id
  security_group_id        = aws_security_group.reverse_proxy_instance.id
}

resource "aws_security_group_rule" "ingress_internet_proxy" {
  description              = "Allow proxy access from app"
  type                     = "ingress"
  from_port                = 3128
  to_port                  = 3128
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.reverse_proxy_instance.id
  security_group_id        = aws_security_group.internet_proxy_endpoint.id
}
