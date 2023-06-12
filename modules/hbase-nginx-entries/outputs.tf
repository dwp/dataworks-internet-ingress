output "hbase_nginx_config" {
    value = local.hbase
}

output "node_manager_nginx_config" {
    value = local.node_manager
}

output "resource_manager_nginx_config" {
    value = local.resource_manager
}

output "ganglia_nginx_config" {
    value = local.ganglia
}