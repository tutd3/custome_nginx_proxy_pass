FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    bash \
    git \
    openssl \
    build-essential \
    lua5.1-dev \
    libexpat1-dev \
    libssl-dev \ 
    luarocks \
    nginx \
    libnginx-mod-http-lua \
    libnginx-mod-http-ndk \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# luarocks packages
RUN luarocks install lua-cjson
RUN luarocks install lua-resty-http
RUN luarocks install lua-resty-string
RUN luarocks install lua-resty-openssl
RUN luarocks install lua-resty-aws 0.5.1
RUN luarocks install luatz

# nginx-prometheus-exporter (ambil binary yang benar)
RUN curl -L \
  https://github.com/nginxinc/nginx-prometheus-exporter/releases/download/v1.1.0/nginx-prometheus-exporter_1.1.0_linux_amd64.tar.gz \
  -o /tmp/nginx-exporter.tar.gz && \
  tar -xzf /tmp/nginx-exporter.tar.gz -C /tmp && \
  mv /tmp/nginx-prometheus-exporter /usr/local/bin/nginx-prometheus-exporter && \
  chmod +x /usr/local/bin/nginx-prometheus-exporter && \
  rm -rf /tmp/*

COPY nginx.conf /etc/nginx/nginx.conf
COPY lua/ /etc/nginx/lua/
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 80 8080 9113

ENTRYPOINT ["/entrypoint.sh"]
