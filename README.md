# custome_nginx_proxy_pass
#first neet to run clickhouse
cd clickhouse
docker-compose up -d / docker compose up -d 

# check 
curl http://localhost:8123 >> make sure response Ok. 

# login ke clickhose
docker exec -it clickhouse clickhouse-client

# Step 5 – Table ClickHouse 
# create database 
CREATE DATABASE IF NOT EXISTS logs;
# create table

## stukture table baru kl menggunakna s3
CREATE TABLE logs.http_logs
(
    service String,
    host String,
    uri String,
    method String,

    headers String,
    remote_ip String,

    body String,

    request_body Nullable(String),
    response_body Nullable(String),

    request_s3 Nullable(String),
    response_s3 Nullable(String),

    ts Float64
)
ENGINE = MergeTree
ORDER BY ts;

# checking data clickhouse
SHOW TABLES FROM logs;
DESCRIBE TABLE logs.http_logs;
SHOW CREATE TABLE logs.http_logs;


# How to build cusome nginx proxy pass
docker build -t nginx-custom:local . 

# how to run after build this was test not permanent
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


# test create file for generate dumy data increase it to 500000 the code will reject body file more then 100Kb you can check on send_log.lua script
head -c 50000 /dev/urandom > largex.json


# test post data 
curl -v -X POST --data-binary @large.json http://localhost:8080/test-upload

# other test real endpoint
### test access 
curl -X POST "http://localhost:8080/dapi/dukcapil/get_json/990042424050002/CALL_VERIFY_BY_ELEMEN" \
  -H "Content-Type: application/json" \
  -d '{
    "USER_ID": "2412202xxxx",
    "PASSWORD": "xxx,
    "IP_USER": "10.162.x.x",
    "TRESHOLD": "85",
    "NIK": "510303xxx",
    "NAMA_LGKP": "Zinedine xxx",
    "TGL_LHR": "1998-12-03",
    "JENIS_KLMIN": "LAKI-LAKI",
    "NO_PROP": "xxx",
    "PROP_NAME": "JAWA BARAT",
    "NO_KAB": "",
    "KAB_NAME": "BOGOR",
    "NO_KEC": "010",
    "KEC_NAME": "BOGOR TENGAH",
    "NO_KEL": "001",
    "KEL_NAME": "PALEDANG",
    "ALAMAT": "JL. SUDIRMAN xxx",
    "NO_RT": "000",
    "NO_RW": "000"
  }'
  
# test metric 
curl http://localhost:9113/metrics

  
