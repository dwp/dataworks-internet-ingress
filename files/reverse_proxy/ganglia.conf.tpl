server {
    listen       80;
    server_name  ganglia.${target_domain};

    error_log   /var/log/nginx/ganglia-ui.error.log debug;
    access_log	/var/log/nginx/ganglia-ui.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://${target_ip}/ganglia/;
    }
}