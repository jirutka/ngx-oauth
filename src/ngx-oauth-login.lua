---------
-- User login script for OAuth 2.0 grant authorization code.

local config  = require 'ngx-oauth.config'
local Cookies = require 'ngx-oauth.Cookies'
local ethr    = require 'ngx-oauth.either'
local nginx   = require 'ngx-oauth.nginx'
local oauth   = require 'ngx-oauth.oauth2'
local util    = require 'ngx-oauth.util'

local log     = nginx.log
local par     = util.partial
local either  = ethr.either

local fail_with_oaas_error = par(nginx.fail, 503, "Authorization server error: %s")


local conf, err = config.load()
if err then
  return nginx.fail(500, "OAuth proxy error: %s", err)
end

local cookies = Cookies(conf)

-- Cookie with refresh token found, requesting a new access token.
if cookies.get_refresh_token() then
  log.info("refreshing token for user: %s", cookies.get_username())

  util.pipe({
    cookies.get_refresh_token,
    par(oauth.request_token, 'refresh_token', conf),
    par(either, fail_with_oaas_error, util.id),
    cookies.add_token
  })()

  return ngx.redirect(conf.success_uri)

-- Cookie with refresh token not found, redirecting to the authorization endpoint.
else
  log.info('redirecting to authorization endpoint')
  return ngx.redirect(oauth.authorization_url(conf))
end
