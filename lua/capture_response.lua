local chunk = ngx.arg[1]
local eof   = ngx.arg[2]

ngx.ctx.resp_body = (ngx.ctx.resp_body or "") .. (chunk or "")

if eof then
    ngx.ctx.resp_complete = true
end
