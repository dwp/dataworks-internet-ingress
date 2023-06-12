output "reverse_proxy_ecs_sg_id" {
  value = aws_security_group.reverse_proxy_ecs.id
}

output "reverse_proxy_alb_dns_name" {
  value = aws_alb.reverse_proxy.dns_name
}

output "reverse_proxy_alb_zone_id" {
  value = aws_alb.reverse_proxy.zone_id
}