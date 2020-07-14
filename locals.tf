locals {
  reverse_proxy_ssmenabled = {
    management-dev = "True"
    management     = "False"
  }

  route53_zone_id_name = {
    management-dev = "wip.dataworks.dwp.gov.uk."
    management     = "dataworks.dwp.gov.uk."
  }
}
