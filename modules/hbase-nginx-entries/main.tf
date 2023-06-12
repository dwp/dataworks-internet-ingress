locals {
    hbase            = templatefile("${path.module}/files/hbase.conf.tpl", { target_hbase_clusters = var.target_hbase_clusters })
    node_manager     = templatefile("${path.module}/files/nm.conf.tpl", { target_hbase_clusters = var.target_hbase_clusters })
    resource_manager = templatefile("${path.module}/files/rm.conf.tpl", { target_hbase_clusters = var.target_hbase_clusters })
    ganglia          = templatefile("${path.module}/files/ganglia.conf.tpl", { target_hbase_clusters = var.target_hbase_clusters })
}