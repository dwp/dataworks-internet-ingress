data "template_file" "hbase" {
    template = "${file("${path.module}/files/hbase.conf.tpl")}"
    vars = {
        target_hbase_clusters = var.target_hbase_clusters
    }
}

data "template_file" "node_manager" {
    template = "${file("${path.module}/files/nm.conf.tpl")}"
    vars = {
        target_hbase_clusters = var.target_hbase_clusters
    }
}

data "template_file" "resource_manager" {
    template = "${file("${path.module}/files/rm.conf.tpl")}"
    vars = {
        target_hbase_clusters = var.target_hbase_clusters
    }
}

data "template_file" "ganglia" {
    template = "${file("${path.module}/files/ganglia.conf.tpl")}"
    vars = {
        target_hbase_clusters = var.target_hbase_clusters
    }
}