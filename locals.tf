locals {
  reverse_proxy_ssmenabled = {
    management-dev = "True"
    management     = "False"
  }

  reverse_proxy_enabled = {
    management-dev = true
    management     = false
  }
}
