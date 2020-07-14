output "reverse_proxy" {
  value = {
    sg = local.reverse_proxy_enabled[local.environment] ? aws_security_group.reverse_proxy_instance[0].id : 0
  }
}
