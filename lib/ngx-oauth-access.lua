---------
-- Access script for protecting pages with OAuth 2.0.

local config  = require 'ngx-oauth.config'
local Cookies = require 'ngx-oauth.Cookies'
local either  = require 'ngx-oauth.either'
local nginx   = require 'ngx-oauth.nginx'
local oauth   = require 'ngx-oauth.oauth2'

local log     = nginx.log
local min     = math.min

local conf, errs = config.load()
if errs then
  return nginx.fail(500, "OAuth proxy error: %s", errs)
end

local tokens = ngx.shared.oauth_tokens

local cookies = Cookies(conf)
local access_token = cookies.get_access_token()

-- Cookie with access token found; access granted and we're done.
if access_token and tokens:get(access_token) then
  return

-- Cookie with refresh token found; refresh token and save the access token.
elseif cookies.get_refresh_token() then
  log.info('refreshing token for user: %s', cookies.get_username())

  return either (
    function(err)
      return nginx.fail(503, 'Authorization server error: %s', err)
    end,
    function(token)
      cookies.add_token(token)
      tokens:set(token.access_token, true, min(token.expires_in, conf.max_age))
      return  -- access granted
    end,
    oauth.request_token('refresh_token', conf, cookies.get_refresh_token())
  )

-- Neither access token nor refresh token found; redirecting to
-- the authorization endpoint.
else
  log.info('redirecting to authorization endpoint')
  cookies.add_original_uri(ngx.var.request_uri)
  return ngx.redirect(oauth.authorization_url(conf), 303)
end
