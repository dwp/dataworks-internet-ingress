%{ for environment, hbase_masters in target_hbase_clusters ~}
%{ for ip_address, domain in hbase_masters ~}
server {
    listen	80;
    server_name	hbase.${domain};

    error_log   /var/log/nginx/hbase-ui.error.log debug;
    access_log	/var/log/nginx/hbase-ui.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://${ip_address}:16010;
    }
}
%{ endfor ~}
%{ endfor ~}