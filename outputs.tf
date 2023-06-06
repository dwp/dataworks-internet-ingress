output "reverse_proxy" {
  value = {
    sg           = aws_security_group.reverse_proxy_ecs.id
    route_table  = aws_route_table.reverse_proxy_private
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
