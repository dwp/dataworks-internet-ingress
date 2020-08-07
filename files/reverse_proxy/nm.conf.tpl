server {
    listen      80;
    server_name nm.${target_domain};

    error_log   /var/log/nginx/nm-ui.error.log debug;
    access_log  /var/log/nginx/nm-ui.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://${target_ip}:8042;
    }
}