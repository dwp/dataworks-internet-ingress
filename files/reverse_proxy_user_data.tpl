#!/bin/bash

export AWS_DEFAULT_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | cut -d'"' -f4)
export INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)

export http_proxy="${internet_proxy}"
export HTTP_PROXY="$http_proxy"

export https_proxy="${internet_proxy}"
export HTTPS_PROXY="$https_proxy"

export no_proxy="${no_proxy}"
export NO_PROXY="${no_proxy}"

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

    #error_page  404              /404.html;
    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
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

cat > /etc/nginx/conf.d/reverse.conf <<"REVERSE_NGINX_CFG"
# Custom log format to include the 'sub' claim in the REMOTE_USER field
log_format main_jwt '$remote_addr - $jwt_claim_sub [$time_local] "$request" $status '
                    '$body_bytes_sent "$http_referer" "$http_user_agent" "$http_x_forwarded_for"';

server {
    #include	 conf.d/openid_connect.server_conf;

    listen       80;
    server_name  ganglia.ui.ingest-hbase.dev.dataworks.dwp.gov.uk;

    error_log   /var/log/nginx/error.log debug;
    access_log	/var/log/nginx/host.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://{{TARGET_SERVER_IP}}/ganglia/;
	    access_log /var/log/nginx/access.log main;

        #access_log /var/log/nginx/access.log main_jwt;
        #auth_jwt "" token=$session_jwt;
        #error_page 401 = @do_oidc_flow;
        #set $oidc_jwt_keyfile ./.well-known/jwks.json;
        #auth_jwt_key_file $oidc_jwt_keyfile;
        #auth_jwt_key_request /_jwks_uri;
        #proxy_set_header username $jwt_claim_sub;
    }
}

server {
    listen	80;
    server_name	spark.ui.ingest-hbase.dev.dataworks.dwp.gov.uk;

    error_log   /var/log/nginx/error.log debug;
    access_log	/var/log/nginx/host.access.log main;

    location / {
        proxy_set_header Host $host;
        proxy_pass http://{{TARGET_SERVER_IP}}:18080;
    }
}
REVERSE_NGINX_CFG

service nginx stop
nginx -t >> /var/log/rev-proxy.log
service nginx start >> /var/log/rev-proxy.log