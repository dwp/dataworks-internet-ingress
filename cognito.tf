resource "aws_cognito_user_pool_client" "reverse_proxy_ganglia" {
  count                                = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name                                 = "reverse-proxy-ganglia"
  user_pool_id                         = data.terraform_remote_state.aws_concourse.outputs.cognito.user_pool.id
  generate_secret                      = true
  callback_urls                        = ["https://${aws_route53_record.reverse_proxy_ganglia_ui[0].fqdn}/oauth2/idpresponse"]
  logout_urls                          = ["https://${aws_route53_record.reverse_proxy_ganglia_ui[0].fqdn}"]
  explicit_auth_flows                  = ["ALLOW_CUSTOM_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid"]
  supported_identity_providers         = ["COGNITO"]
}

resource "aws_cognito_user_group" "reverse_proxy_ganglia" {
  count        = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name         = "reverse-proxy-ganglia"
  user_pool_id = data.terraform_remote_state.aws_concourse.outputs.cognito.user_pool.id
  description  = "Reverse Proxy - Ganglia"
}

resource "aws_cognito_user_pool_client" "reverse_proxy_hbaseui" {
  count                                = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name                                 = "reverse-proxy-hbaseui"
  user_pool_id                         = data.terraform_remote_state.aws_concourse.outputs.cognito.user_pool.id
  generate_secret                      = true
  callback_urls                        = ["https://${aws_route53_record.reverse_proxy_hbase_ui[0].fqdn}/oauth2/idpresponse"]
  logout_urls                          = ["https://${aws_route53_record.reverse_proxy_hbase_ui[0].fqdn}"]
  explicit_auth_flows                  = ["ALLOW_CUSTOM_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid"]
  supported_identity_providers         = ["COGNITO"]
}

resource "aws_cognito_user_group" "reverse_proxy_hbaseui" {
  count        = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name         = "reverse-proxy-hbaseui"
  user_pool_id = data.terraform_remote_state.aws_concourse.outputs.cognito.user_pool.id
  description  = "Reverse Proxy - Hbase UI"
}

resource "aws_cognito_user_pool_client" "reverse_proxy_nm" {
  count                                = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name                                 = "reverse-proxy-nm"
  user_pool_id                         = data.terraform_remote_state.aws_concourse.outputs.cognito.user_pool.id
  generate_secret                      = true
  callback_urls                        = ["https://${aws_route53_record.reverse_proxy_nm_ui[0].fqdn}/oauth2/idpresponse"]
  logout_urls                          = ["https://${aws_route53_record.reverse_proxy_nm_ui[0].fqdn}"]
  explicit_auth_flows                  = ["ALLOW_CUSTOM_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid"]
  supported_identity_providers         = ["COGNITO"]
}

resource "aws_cognito_user_group" "reverse_proxy_nm" {
  count        = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name         = "reverse-proxy-nm"
  user_pool_id = data.terraform_remote_state.aws_concourse.outputs.cognito.user_pool.id
  description  = "Reverse Proxy - NM"
}

resource "aws_cognito_user_pool_client" "reverse_proxy_rm" {
  count                                = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name                                 = "reverse-proxy-rm"
  user_pool_id                         = data.terraform_remote_state.aws_concourse.outputs.cognito.user_pool.id
  generate_secret                      = true
  callback_urls                        = ["https://${aws_route53_record.reverse_proxy_rm_ui[0].fqdn}/oauth2/idpresponse"]
  logout_urls                          = ["https://${aws_route53_record.reverse_proxy_rm_ui[0].fqdn}"]
  explicit_auth_flows                  = ["ALLOW_CUSTOM_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid"]
  supported_identity_providers         = ["COGNITO"]
}

resource "aws_cognito_user_group" "reverse_proxy_rm" {
  count        = local.reverse_proxy_enabled[local.environment] ? 1 : 0
  name         = "reverse-proxy-rm"
  user_pool_id = data.terraform_remote_state.aws_concourse.outputs.cognito.user_pool.id
  description  = "Reverse Proxy - RM"
}