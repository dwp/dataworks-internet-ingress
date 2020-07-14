locals {
  reverse_proxy_ssmenabled = {
    management-dev = "True"
    management     = "False"
  }

  dns_prefix = {
    management-dev = "mgmt-dev"
    management     = "mgmt"
  }
}
