#!/bin/sh
set -e

envsubst < /etc/nginx/nginx.conf > /tmp/nginx.conf

nginx -t -c /tmp/nginx.conf

nginx -c /tmp/nginx.conf -g "daemon off;" &
NGINX_PID=$!

exec /usr/local/bin/nginx-prometheus-exporter \
  -nginx.scrape-uri=http://127.0.0.1:8080/stub_status
