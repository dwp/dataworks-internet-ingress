%{ for hbase_master in target_hbase_clusters ~}
server {
    listen       80;
    server_name  ganglia.ui.ingest-hbase${hbase_master.target_env}.${hbase_master.node_identifier}.${hbase_master.domain};

    error_log   /var/log/nginx/ganglia-ui.error.log debug;
    access_log	/var/log/nginx/ganglia-ui.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://${hbase_master.ip_address}/ganglia/;
    }
}
%{ endfor ~}
