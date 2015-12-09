---------
-- User logout script for OAuth 2.0 grant authorization code..

local config  = require 'ngx-oauth.config'
local Cookies = require 'ngx-oauth.Cookies'
local nginx   = require 'ngx-oauth.nginx'

local log     = nginx.log
local method  = ngx.var.request_method

if method ~= 'POST' then
  return nginx.fail(405, "This resource supports only POST, but you've sent %s.", method)
end

local conf, errs = config.load()
if errs then
  return nginx.fail(500, "OAuth proxy error: %s", errs)
end

local cookies = Cookies(conf)

cookies.clear_all()
log.debug("user %s has been logged out", cookies.get_username())

return ngx.exit(204)
