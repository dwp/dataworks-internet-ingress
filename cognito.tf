resource "aws_cognito_user_pool" "reverse-proxy" {
  name = "reverse-proxy"
  admin_create_user_config {
    allow_admin_create_user_only = true
  }
}

resource "aws_cognito_user_pool_client" "reverse-proxy" {
  name         = "reverse-proxy"
  user_pool_id = aws_cognito_user_pool.reverse-proxy.id
}

resource "aws_cognito_user_pool_domain" "reverse-proxy" {
  domain       = "reverse-proxy.auth.${var.region}.amazoncognito.com"
  user_pool_id = aws_cognito_user_pool.reverse-proxy.id
}