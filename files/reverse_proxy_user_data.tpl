#!/bin/bash

# Some bits
touch /var/log/rev-proxy.log

# Required for nginx plus integration with Cognito
# yum install -y nginx-plus-module-njs
yum install -y nginx

# Replace the nginx config file
cat > /etc/nginx/nginx.conf <<"NGINX_CFG"
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

#load_module modules/ngx_http_js_module.so;

events {
    worker_connections  1024;
}


http {
    real_ip_header X-Forwarded-For;
    set_real_ip_from 0.0.0.0/0;
    server_names_hash_bucket_size	128;
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;
}
NGINX_CFG

# Replace various nginx config files with our own
rm -fr /etc/nginx/conf.d/*

cat > /etc/nginx/conf.d/default.conf <<"DEFAULT_NGINX_CFG"
server {
    listen       80 default_server;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    error_page  404              /404.html;
    error_page  500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

    # enable /api/ location with appropriate access control in order
    # to make use of NGINX Plus API
    #
    #location /api/ {
    #    api write=on;
    #    allow 127.0.0.1;
    #    deny all;
    #}

    # enable NGINX Plus Dashboard; requires /api/ location to be
    # enabled and appropriate access control for remote access
    #
    #location = /dashboard.html {
    #    root /usr/share/nginx/html;
    #}
}
DEFAULT_NGINX_CFG

cat > /etc/nginx/conf.d/ganglia.conf <<"GANGLIA_NGINX_CFG"
server {
    listen       80;
    server_name  ganglia.ui.ingest-hbase.dev.dataworks.dwp.gov.uk;

    error_log   /var/log/nginx/ganglia-ui.error.log debug;
    access_log	/var/log/nginx/ganglia-ui.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://${target_ip}/ganglia/;
    }
}
GANGLIA_NGINX_CFG

cat > /etc/nginx/conf.d/ganglia.conf <<"HBASE_NGINX_CFG"
server {
    listen	80;
    server_name	hbase.ui.ingest-hbase.dev.dataworks.dwp.gov.uk;

    error_log   /var/log/nginx/hbase-ui.error.log debug;
    access_log	/var/log/nginx/hbase-ui.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://${target_ip}:16010;
    }
}
HBASE_NGINX_CFG

cat > /etc/nginx/conf.d/ganglia.conf <<"NM_NGINX_CFG"
server {
    listen      80;
    server_name nm.ui.ingest-hbase.dev.dataworks.dwp.gov.uk;

    error_log   /var/log/nginx/nm-ui.error.log debug;
    access_log  /var/log/nginx/nm-ui.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://${target_ip}:8042;
    }
}
NM_NGINX_CFG

cat > /etc/nginx/conf.d/ganglia.conf <<"RM_NGINX_CFG"
server {
    listen      80;
    server_name rm.ui.ingest-hbase.dev.dataworks.dwp.gov.uk;

    error_log   /var/log/nginx/rm-ui.error.log debug;
    access_log  /var/log/nginx/rm-ui.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://${target_ip}:8088;
    }
}
RM_NGINX_CFG

service nginx stop
nginx -t >> /var/log/rev-proxy.log
service nginx start >> /var/log/rev-proxy.log
