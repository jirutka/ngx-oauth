---------
-- Proxy script for OAuth 2.0.

local config  = require 'ngx-oauth.config'
local Cookies = require 'ngx-oauth.Cookies'
local either  = require 'ngx-oauth.either'
local nginx   = require 'ngx-oauth.nginx'
local oauth   = require 'ngx-oauth.oauth2'

local log    = nginx.log

local function write_auth_header (access_token)
  ngx.req.set_header('Authorization', 'Bearer '..access_token)
end


local conf, errs = config.load()
if errs then
  return nginx.fail(500, 'OAuth proxy error: %s', errs)
end

local cookies = Cookies(conf)
local access_token = cookies.get_access_token()

-- Cookie with access token found; set Authorization header and we're done.
if access_token then
  write_auth_header(access_token)

-- Cookie with refresh token found; refresh token and set Authorization header.
elseif cookies.get_refresh_token() then
  log.info('refreshing token for user: %s', cookies.get_username())

  either (
    function(err)
      nginx.fail(503, 'Authorization server error: %s', err)
    end,
    function(token)
      cookies.add_token(token)
      write_auth_header(token.access_token)
    end,
    oauth.request_token('refresh_token', conf, cookies.get_refresh_token())
  )

-- Neither access token nor refresh token found; bad luck, return HTTP 401.
else
  ngx.header['WWW-Authenticate'] = 'Bearer error="unauthorized"'
  nginx.fail(401, 'No access token provided.')
end
