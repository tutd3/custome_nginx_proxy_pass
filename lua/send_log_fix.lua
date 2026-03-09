-- send_log.lua (stable S3 v4 PUT + ClickHouse async)
local cjson = require "cjson.safe"
local http  = require "resty.http"
local str   = require "resty.string"
local digest_module = require "resty.openssl.digest"
local hmac_module   = require "resty.openssl.hmac"

local MAX_INLINE = 512 * 1024

-- ambil body dari context
local req_body  = ngx.ctx.req_body
local resp_body = ngx.ctx.resp_body

-- =========================
-- Debug print environment
-- =========================
ngx.log(ngx.ERR, "[DEBUG ENV] S3_BUCKET=", os.getenv("S3_BUCKET"))
ngx.log(ngx.ERR, "[DEBUG ENV] AWS_REGION=", os.getenv("AWS_REGION"))
ngx.log(ngx.ERR, "[DEBUG ENV] AWS_ACCESS_KEY_ID=", os.getenv("AWS_ACCESS_KEY_ID"))
ngx.log(ngx.ERR, "[DEBUG ENV] AWS_SECRET_ACCESS_KEY=****")
ngx.log(ngx.ERR, "[DEBUG ENV] SERVICE_NAME=", os.getenv("SERVICE_NAME"))

-- =========================
-- Helper: SHA256 & HMAC SHA256
-- =========================
local function sha256_bin(msg)
    local d, err = digest_module.new("sha256")
    if not d then return nil, err end
    d:update(msg)
    return d:final()
end

local function hmac_sha256(key, msg)
    local h, err = hmac_module.new(key, "sha256")
    if not h then return nil, err end
    h:update(msg)
    return h:final()
end

-- =========================
-- AWS v4 signing function
-- =========================
local function aws_v4_sign(bucket, region, key, body)
    local access_key = os.getenv("AWS_ACCESS_KEY_ID")
    local secret_key = os.getenv("AWS_SECRET_ACCESS_KEY")
    local service = "s3"
    local method = "PUT"
    local host = bucket..".s3."..region..".amazonaws.com"
    local uri = "/"..key
    local amz_date = os.date("!%Y%m%dT%H%M%SZ")
    local date_stamp = os.date("!%Y%m%d")
    
    local payload_hash = str.to_hex(sha256_bin(body))
    
    local canonical_request = table.concat({
        method,
        uri,
        "",
        "host:"..host,
        "x-amz-content-sha256:"..payload_hash,
        "x-amz-date:"..amz_date,
        "",
        "host;x-amz-content-sha256;x-amz-date",
        payload_hash
    }, "\n")
    
    local canonical_hash = str.to_hex(sha256_bin(canonical_request))
    
    local credential_scope = date_stamp.."/"..region.."/"..service.."/aws4_request"
    local string_to_sign = table.concat({
        "AWS4-HMAC-SHA256",
        amz_date,
        credential_scope,
        canonical_hash
    }, "\n")
    
    local kDate    = hmac_sha256("AWS4"..secret_key, date_stamp)
    local kRegion  = hmac_sha256(kDate, region)
    local kService = hmac_sha256(kRegion, service)
    local kSigning = hmac_sha256(kService, "aws4_request")
    local signature = str.to_hex(hmac_sha256(kSigning, string_to_sign))
    
    local auth_header = table.concat({
        "AWS4-HMAC-SHA256 Credential="..access_key.."/"..credential_scope,
        "SignedHeaders=host;x-amz-content-sha256;x-amz-date",
        "Signature="..signature
    }, ", ")
    
    return {
        ["Authorization"] = auth_header,
        ["x-amz-date"] = amz_date,
        ["x-amz-content-sha256"] = payload_hash,
        ["Content-Type"] = "application/json",
        ["Host"] = host
    }
end

-- =========================
-- S3 Upload async via ngx.timer
-- =========================
local function upload_s3_async(premature, data)
    if premature then return end
    local bucket = os.getenv("S3_BUCKET")
    local region = os.getenv("AWS_REGION")
    local key = "audit/"..ngx.time().."-"..ngx.worker.pid()..".json"
    
    ngx.log(ngx.ERR, "[DEBUG S3] Uploading key=", key, " size=", #data)
    
    local headers = aws_v4_sign(bucket, region, key, data)
    
    local httpc = http.new()
    httpc:set_timeout(5000)
    
    local res, err = httpc:request_uri("https://"..bucket..".s3."..region..".amazonaws.com/"..key, {
        method = "PUT",
        body = data,
        headers = headers
    })
    
    if not res then
        ngx.log(ngx.ERR, "upload_s3_async failed: ", err)
        return
    end
    
    if res.status < 200 or res.status >= 300 then
        ngx.log(ngx.ERR, "S3 upload returned non-2xx status: ", res.status)
        ngx.log(ngx.ERR, "Response body: ", res.body or "nil")
        return
    end
    
    ngx.log(ngx.ERR, "S3 upload successful: s3://"..bucket.."/"..key)
end

-- =========================
-- Trigger async jika body besar
-- =========================
if req_body and #req_body > MAX_INLINE then
    ngx.timer.at(0, upload_s3_async, req_body)
    req_body = nil
end
if resp_body and #resp_body > MAX_INLINE then
    ngx.timer.at(0, upload_s3_async, resp_body)
    resp_body = nil
end

-- =========================
-- Build log dan kirim ke ClickHouse
-- =========================
local log = {
    service       = os.getenv("SERVICE_NAME"),
    uri           = ngx.ctx.req_uri,
    method        = ngx.ctx.req_method,
    remote_ip     = ngx.ctx.req_ip,
    request_body  = req_body,
    response_body = resp_body,
    ts            = ngx.now()
}
local payload = cjson.encode(log)

local function send_clickhouse(premature, payload)
    if premature then return end
    local httpc = http.new()
    httpc:set_timeout(2000)
    local ch_host = os.getenv("CLICKHOUSE_HOST")
    local ch_port = os.getenv("CLICKHOUSE_PORT")
    local ch_db   = os.getenv("CLICKHOUSE_DB")
    local ch_tbl  = os.getenv("CLICKHOUSE_TABLE")
    
    local sql = "INSERT INTO "..ch_db.."."..ch_tbl.." FORMAT JSONEachRow\n"..payload
    local res, err = httpc:request_uri("http://"..ch_host..":"..ch_port, { method="POST", body=sql })
    if not res then
        ngx.log(ngx.ERR, "clickhouse insert failed: ", err)
    end
    httpc:set_keepalive()
end

local ok, err = ngx.timer.at(0, send_clickhouse, payload)
if not ok then
    ngx.log(ngx.ERR, "failed to create clickhouse timer: ", err)
end
