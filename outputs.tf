output "reverse_proxy" {
  value = {
    sg         = aws_security_group.reverse_proxy_instance[0].id
    s3location = "tbd"
  }
}
