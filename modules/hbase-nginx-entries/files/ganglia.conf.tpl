%{ for environment, hbase_masters in target_hbase_clusters ~}
%{ for ip_address, domain in hbase_masters ~}
server {
    listen       80;
    server_name  ganglia.${domain};

    error_log   /var/log/nginx/ganglia-ui.error.log debug;
    access_log	/var/log/nginx/ganglia-ui.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://${ip_address}/ganglia/;
    }
}
%{ endfor ~}
%{ endfor ~}
