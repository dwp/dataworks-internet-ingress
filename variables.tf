variable "costcode" {
  type    = string
  default = ""
}

variable "assume_role" {
  type        = string
  default     = "ci"
  description = "IAM role assumed by Concourse when running Terraform"
}

variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "ssh_bastion_ami_id" {
  type    = string
  default = ""
}

variable "reverse_proxy_http_port" {
  default = 80
}

variable "reverse_proxy_https_port" {
  default = 443
}
