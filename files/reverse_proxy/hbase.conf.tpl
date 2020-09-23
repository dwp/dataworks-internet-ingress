server {
    listen	80;
    server_name	hbase.${target_domain_1};

    error_log   /var/log/nginx/hbase-ui.error.log debug;
    access_log	/var/log/nginx/hbase-ui.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://${target_ip_1}:16010;
    }
}

server {
    listen	80;
    server_name	hbase.${target_domain_2};

    error_log   /var/log/nginx/hbase-ui.error.log debug;
    access_log	/var/log/nginx/hbase-ui.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://${target_ip_2}:16010;
    }
}

server {
    listen	80;
    server_name	hbase.${target_domain_3};

    error_log   /var/log/nginx/hbase-ui.error.log debug;
    access_log	/var/log/nginx/hbase-ui.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://${target_ip_3}:16010;
    }
}
