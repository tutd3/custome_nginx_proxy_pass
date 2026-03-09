# custome_nginx_proxy_pass
# How to build 
docker build -t nginx-custom:local . 

# how to run
docker run --rm \
  --network clickhouse_default \
  -p 8080:80 \
  -p 9113:9113 \
  -e DAPI_HOST=dapi.mobee.com \
  -e DFR_HOST=dfr.mobee.com \
  -e CLICKHOUSE_HOST=clickhouse \
  -e CLICKHOUSE_PORT=8123 \
  -e CLICKHOUSE_DB=logs \
  -e CLICKHOUSE_TABLE=http_logs \
  -e SERVICE_NAME=nginx-custom \
  -e AWS_REGION=ap-southeast-3 \
  -e S3_BUCKET=bucket-tutde-test \
  -e AWS_ACCESS_KEY_ID=xxx \
  -e AWS_SECRET_ACCESS_KEY=xxxx \
  nginx-custom-new:local

  
