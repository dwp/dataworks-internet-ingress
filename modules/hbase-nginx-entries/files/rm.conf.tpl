%{ for hbase_master in target_hbase_clusters ~}
server {
    listen      80;
    server_name rm.ui.ingest-hbase${hbase_master.domain};

    error_log   /var/log/nginx/rm-ui.error.log debug;
    access_log  /var/log/nginx/rm-ui.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://${hbase_master.ip_address}:8088;
    }
}
%{ endfor ~}
