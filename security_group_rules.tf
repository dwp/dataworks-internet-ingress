# resource "aws_security_group_rule" "egress_internet_proxy" {
#   description              = "Allow Internet access via the proxy for reverse proxy container"
#   type                     = "egress"
#   from_port                = 3128
#   to_port                  = 3128
#   protocol                 = "tcp"
#   source_security_group_id = aws_security_group.internet_proxy_endpoint.id
#   security_group_id        = module.reverse_proxy.reverse_proxy_ecs_id
# }

# resource "aws_security_group_rule" "ingress_internet_proxy" {
#   description              = "Allow proxy access from reverse proxy container"
#   type                     = "ingress"
#   from_port                = 3128
#   to_port                  = 3128
#   protocol                 = "tcp"
#   source_security_group_id = module.reverse_proxy.reverse_proxy_ecs_id
#   security_group_id        = aws_security_group.internet_proxy_endpoint.id
# }

# resource "aws_security_group_rule" "reverse_proxy_http_ingress" {
#   description       = "Reverse Proxy Container HTTP Rule"
#   type              = "ingress"
#   protocol          = "tcp"
#   from_port         = "80"
#   to_port           = "80"
#   cidr_blocks       = [module.vpc.vpc.cidr_block]
#   security_group_id = module.reverse_proxy.reverse_proxy_ecs_id
# }

# resource "aws_security_group_rule" "reverse_proxy_http_egress" {
#   description              = "Allow outbound requests to VPC endpoints (HTTP) from reverse-proxy container"
#   type                     = "egress"
#   protocol                 = "tcp"
#   from_port                = "80"
#   to_port                  = "80"
#   source_security_group_id = module.vpc.interface_vpce_sg_id
#   security_group_id        = module.reverse_proxy.reverse_proxy_ecs_id
# }

# resource "aws_security_group_rule" "vpc_endpoint_http_egress" {
#   description              = "Allow inbound requests to VPC endpoints (HTTP) from reverse-proxy container"
#   type                     = "ingress"
#   protocol                 = "tcp"
#   from_port                = "80"
#   to_port                  = "80"
#   security_group_id        = module.vpc.interface_vpce_sg_id
#   source_security_group_id = module.reverse_proxy.reverse_proxy_ecs_id
# }

# resource "aws_security_group_rule" "reverse_proxy_s3_egress" {
#   description       = "Allow outbound requests to S3 PFL from reverse-proxy container"
#   type              = "egress"
#   protocol          = "tcp"
#   from_port         = "80"
#   to_port           = "80"
#   prefix_list_ids   = [module.vpc.prefix_list_ids.s3]
#   security_group_id = module.reverse_proxy.reverse_proxy_ecs_id
# }

# resource "aws_security_group_rule" "reverse_proxy_s3_https_egress" {
#   description       = "Allow HTTPS outbound requests to S3 PFL from reverse-proxy container"
#   type              = "egress"
#   protocol          = "tcp"
#   from_port         = "443"
#   to_port           = "443"
#   prefix_list_ids   = [module.vpc.prefix_list_ids.s3]
#   security_group_id = module.reverse_proxy.reverse_proxy_ecs_id
# }