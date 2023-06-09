variable "target_hbase_clusters" {
  type = list(object({
    ip_address = string
    node_identifier = string
    domain = string
    target_env = string
  }))
}