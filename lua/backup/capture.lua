local cjson = require "cjson.safe"
local http  = require "resty.http"

ngx.req.read_body()

local body = ngx.req.get_body_data()

if not body then
    local body_file = ngx.req.get_body_file()
    if body_file then
        local f = io.open(body_file, "rb")
        body = f:read("*all")
        f:close()
    end
end

local headers = ngx.req.get_headers()

local data = {
    service   = os.getenv("SERVICE_NAME"),
    host      = ngx.var.host,
    uri       = ngx.var.request_uri,
    method    = ngx.req.get_method(),
    body      = body,
    headers   = headers,
    remote_ip = ngx.var.remote_addr,
    ts        = ngx.now()
}

local payload = cjson.encode(data)

local ch_host = os.getenv("CLICKHOUSE_HOST")
local ch_port = os.getenv("CLICKHOUSE_PORT")
local ch_db   = os.getenv("CLICKHOUSE_DB")
local ch_tbl  = os.getenv("CLICKHOUSE_TABLE")
if not ch_tbl then
    ngx.log(ngx.ERR, "CLICKHOUSE_TABLE is not set")
    return
end

local sql = "INSERT INTO " .. ch_db .. "." .. ch_tbl .. " FORMAT JSONEachRow\n" .. payload

local httpc = http.new()
httpc:set_timeout(2000)

local res, err = httpc:request_uri(
    "http://" .. ch_host .. ":" .. ch_port,
    {
        method = "POST",
        body   = sql
    }
)

if not res then
    ngx.log(ngx.ERR, "clickhouse insert failed: ", err)
end
