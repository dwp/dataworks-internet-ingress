server {
    listen       80;
    server_name  ganglia.${target_domain_1};

    error_log   /var/log/nginx/ganglia-ui.error.log debug;
    access_log	/var/log/nginx/ganglia-ui.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://${target_ip_1}/ganglia/;
    }
}

server {
    listen       80;
    server_name  ganglia.${target_domain_2};

    error_log   /var/log/nginx/ganglia-ui.error.log debug;
    access_log	/var/log/nginx/ganglia-ui.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://${target_ip_2}/ganglia/;
    }
}

server {
    listen       80;
    server_name  ganglia.${target_domain_3};

    error_log   /var/log/nginx/ganglia-ui.error.log debug;
    access_log	/var/log/nginx/ganglia-ui.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://${target_ip_3}/ganglia/;
    }
}
