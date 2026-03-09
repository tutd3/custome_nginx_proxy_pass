local cjson = require "cjson.safe"
local http  = require "resty.http"
local str   = require "resty.string"
local sha256 = require "resty.openssl.digest".new("sha256")

local MAX_INLINE = 512 * 1024

local req_body = ngx.ctx.req_body
local resp_body = ngx.ctx.resp_body

local function upload_s3(data)

    local bucket = os.getenv("S3_BUCKET")
    local region = os.getenv("AWS_REGION")

    local key = "audit/" .. ngx.time() .. "-" .. ngx.worker.pid() .. ".json"

    local httpc = http.new()
    httpc:set_timeout(3000)

    local url = "https://"..bucket..".s3."..region..".amazonaws.com/"..key

    local res, err = httpc:request_uri(url, {
        method = "PUT",
        body = data,
        headers = {
            ["Content-Type"] = "application/json"
        }
    })

    if not res then
        ngx.log(ngx.ERR,"S3 upload failed: ",err)
        return nil
    end

    return "s3://"..bucket.."/"..key
end


-- async wrapper untuk S3
local function upload_s3_async(premature, data)

    if premature then
        return
    end

    upload_s3(data)
end


local req_s3 = nil
local resp_s3 = nil

-- request body
if req_body and #req_body > MAX_INLINE then
    ngx.timer.at(0, upload_s3_async, req_body)
    req_s3 = "async_upload"
    req_body = nil
end

-- response body
if resp_body and #resp_body > MAX_INLINE then
    ngx.timer.at(0, upload_s3_async, resp_body)
    resp_s3 = "async_upload"
    resp_body = nil
end


local log = {
    service = os.getenv("SERVICE_NAME"),
    uri = ngx.ctx.req_uri,
    method = ngx.ctx.req_method,
    remote_ip = ngx.ctx.req_ip,
    request_body = req_body,
    response_body = resp_body,
    request_s3 = req_s3,
    response_s3 = resp_s3,
    ts = ngx.now()
}

local payload = cjson.encode(log)

-- function async insert clickhouse
local function send_clickhouse(premature, payload)

    if premature then
        return
    end

    local http  = require "resty.http"

    local ch_host = os.getenv("CLICKHOUSE_HOST")
    local ch_port = os.getenv("CLICKHOUSE_PORT")
    local ch_db   = os.getenv("CLICKHOUSE_DB")
    local ch_tbl  = os.getenv("CLICKHOUSE_TABLE")

    local sql = "INSERT INTO "..ch_db.."."..ch_tbl.." FORMAT JSONEachRow\n"..payload

    local httpc = http.new()
    httpc:set_timeout(2000)

    local res, err = httpc:request_uri(
        "http://"..ch_host..":"..ch_port,
        {
            method = "POST",
            body = sql
        }
    )

    if not res then
        ngx.log(ngx.ERR, "clickhouse insert failed: ", err)
    end

    httpc:set_keepalive()
end


-- async call
local ok, err = ngx.timer.at(0, send_clickhouse, payload)

if not ok then
    ngx.log(ngx.ERR, "failed to create clickhouse timer: ", err)
end
