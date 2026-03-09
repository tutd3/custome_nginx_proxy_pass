local cjson = require "cjson.safe"

ngx.req.read_body()

local body = ngx.req.get_body_data()

ngx.ctx.req_body = body
ngx.ctx.req_headers = ngx.req.get_headers()
ngx.ctx.req_method = ngx.req.get_method()
ngx.ctx.req_uri = ngx.var.request_uri
ngx.ctx.req_ip = ngx.var.remote_addr
ngx.ctx.start_ts = ngx.now()
