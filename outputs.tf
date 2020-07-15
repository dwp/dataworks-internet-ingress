output "reverse_proxy" {
  value = {
    sg = local.reverse_proxy_enabled[local.environment] ? aws_security_group.reverse_proxy_instance[0].id : 0
  }
}

output "vpc" {
  value = module.vpc.vpc
}

output "ssh_bastion" {
  value = {
    sg          = aws_security_group.ssh_bastion
    subnets     = aws_subnet.ssh_bastion
    route_table = aws_route_table.ssh_bastion
  }
}
