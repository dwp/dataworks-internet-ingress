output "hbase_nginx_config" {
    value = data.template_file.hbase.rendered
}

output "node_manager_nginx_config" {
    value = data.template_file.node_manager.rendered
}

output "resource_manager_nginx_config" {
    value = data.template_file.resource_manager.rendered
}

output "ganglia_nginx_config" {
    value = data.template_file.ganglia.rendered
}