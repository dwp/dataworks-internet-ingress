variable "target_hbase_clusters" {
  type = list(object({
    domain = string
    ip_address = string
  }))
}