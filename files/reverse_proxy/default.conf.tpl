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
