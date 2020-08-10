server {
    listen	80;
    server_name	hbase.${target_domain};

    error_log   /var/log/nginx/hbase-ui.error.log debug;
    access_log	/var/log/nginx/hbase-ui.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://${target_ip}:16010;
    }
}
