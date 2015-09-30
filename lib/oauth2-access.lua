-- The MIT License
--
-- Copyright 2015 Jakub Jirutka <jakub@jirutka.cz>.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

local http = require('resty.http')

-- Allow either cjson, or th-LuaJSON.
local has_cjson, jsonmod = pcall(require, 'cjson')
if not has_cjson then
  jsonmod = require('json')
end


---------- Variables ----------

local COOKIE_ACCESS_TOKEN = 'oauth_access_token'
local COOKIE_NICKNAME     = 'oauth_nickname'
local COOKIE_EMAIL        = 'oauth_email'

local debug    = ngx.var.oauth_debug or false
local oaas_url = ngx.var.oauth_server_url

local conf = {
  client_id          = ngx.var.oauth_client_id,
  client_secret      = ngx.var.oauth_client_secret,
  scope              = ngx.var.oauth_scope,
  grant_type         = ngx.var.oauth_grant_type        or "authorization_code",
  redirect_path      = ngx.var.oauth_redirect_path     or "/_oauth/callback",
  authorization_url  = ngx.var.oauth_authorization_url or oaas_url.."/oauth/authorize",
  token_url          = ngx.var.oauth_token_url         or oaas_url.."/oauth/token",
  userinfo_url       = ngx.var.oauth_userinfo_url      or oaas_url.."/api/v1/tokeninfo",
  cookie_path        = ngx.var.oauth_cookie_path       or "/",
  set_header         = ngx.var.oauth_set_header        or ngx.var.oauth_set_header == nil
}

local ngx_server_url = ngx.var.scheme.."://"..ngx.var.server_name
local request_path   = ngx.var.uri
local request_args   = ngx.req.get_uri_args()


---------- Functions ----------

--- Returns a partially applied function.
local function partial(func, ...)
  local args = ...
  return function(...) return func(args, ...) end
end

--- Rewrites nginx variable if defined, otherwise do nothing.
local function rewrite_var(name, value)
  if ngx.var[name] ~= nil then
    ngx.var[name] = value
  end
end

--- Returns value of the specified cookie, or nil of doesn't exist.
local function get_cookie(name)
  return ngx.var['cookie_'..name]
end

--- Formats HTTP cookie from the given arguments.
-- @param #string name
-- @param #string value
-- @param #map attrs a map of additional attributes.
-- @return #string a cookie.
local function format_cookie(name, value, attrs)
  local t = { name.."="..ngx.escape_uri(value) }
  for k, v in pairs(attrs) do
    t[#t+1] = k.."="..v
  end
  return table.concat(t, ";")
end

--- Sends an HTTP request and returns respond if has status 200.
-- This function just wraps resty.http#request_uri for simpler error handling.
--
-- @param resty.http#http an instance of resty http client.
-- @param #string uri
-- @param #map params
-- @return #map a response, or nil if an error occured or server didn't return
--         status 200.
local function request_uri(http_client, uri, params)
  local res, err = http_client:request_uri(uri, params)

  if res and res.status == 200 then
    return res
  else
    local msg = err or res.status..": "..res.body
    ngx.log(ngx.ERR, "request to "..uri.." has failed with: "..msg)
  end
end

---
-- @param request_f the function to perform a request, see #request_uri.
-- @param #string grant_type "authorization_code", or "client_credentials".
-- @param #string auth_code the authorization code obtained from the
--        authorization server (only for grant_type authorization_code).
-- @return #map token
local function request_token(request_f, grant_type, auth_code)

  local credentials = conf.client_id..":"..conf.client_secret
  local body = { grant_type = grant_type }

  if grant_type == 'authorization_code' then
    body['code'] = auth_code
    body['redirect_uri'] = ngx_server_url..conf.redirect_path
  end

  local res = request_f(conf.token_url, {
    method = 'POST',
    body = ngx.encode_args(body),
    headers = {
      ['Accept'] = "application/json",
      ['Authorization'] = "Basic "..ngx.encode_base64(credentials),
      ['Content-Type'] = "application/x-www-form-urlencoded"
    }
  })
  if res then
    if debug then ngx.log(ngx.DEBUG, "received token: "..res.body) end
    return jsonmod.decode(res.body)
  end
end

--- Requests info about user that authorized the given access token.
-- @param request_f the function to perform a request, see #request_uri.
-- @param #string access_token
-- @return #map
local function request_userinfo(request_f, access_token)

  local res = request_f(conf.userinfo_url.."?token="..access_token, {
    headers = {
      ['Accept'] = "application/json",
      ['Authorization'] = "Bearer "..access_token,
    }
  })
  if res then
    local json = jsonmod.decode(res.body)
    return {
      nickname = json.user_id,
      email    = json.user_email
    }
  end
end

---
-- @param #map token
-- @param #map userinfo
-- @return #list a list of cookies.
local function build_cookies(token, userinfo)
  local args = {
    version = 1,
    path = conf.cookie_path,
    ['Max-Age'] = token.expires_in
  }
  return {
    format_cookie(COOKIE_ACCESS_TOKEN, token.access_token, args),
    format_cookie(COOKIE_NICKNAME,     userinfo.nickname,  args),
    format_cookie(COOKIE_EMAIL,        userinfo.email,     args)
  }
end

--- Issue a redirect to the authorization endpoint.
-- Note: Calling this method terminates processing of the current request.
local function do_redirect_authorization()
  local args = ngx.encode_args({
    response_type = 'code',
    client_id     = conf.client_id,
    redirect_uri  = ngx_server_url..conf.redirect_path,
    scope         = conf.scope,
    state         = ngx.var.request_uri
  })
  ngx.redirect(conf.authorization_url..'?'..args)
end

--- Handles callback from the authorization server.
-- Note: Calling this method terminates processing of the current request.
local function do_handle_callback()

  local auth_code = request_args.code
  local intended_uri = request_args.state

  if request_args.error then
    ngx.log(ngx.ERR, request_path..": received "..request_args.error)
    ngx.exit(ngx.HTTP_UNAUTHORIZED)

  elseif auth_code then
    if debug then ngx.log(ngx.DEBUG, "requesting token for auth code: "..auth_code) end

    local request_f = partial(request_uri, http.new())

    local token = request_token(request_f, 'authorization_code', auth_code)
    if not token then
      return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    local userinfo = request_userinfo(request_f, token.access_token)
    if not userinfo then
      return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    ngx.log(ngx.INFO, "authorized user "..userinfo.nickname..", redirecting to "..intended_uri)

    ngx.header['Set-Cookie'] = build_cookies(token, userinfo)
    ngx.redirect(intended_uri)

  else
    ngx.exit(ngx.HTTP_BAD_REQUEST)
  end
end


---------- Main ----------

-- Exit with HTTP 500 when required variables are not set.
if conf.client_id == '' or conf.client_secret == '' then
  ngx.log(ngx.ERR, "variables $oauth_client_id and $oauth_client_secret must be set!")
  return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

local access_token = get_cookie(COOKIE_ACCESS_TOKEN)

-- Cookie with access token exists.
if access_token then
  local user_id = get_cookie(COOKIE_NICKNAME)

  ngx.log(ngx.INFO, "found access token for user: "..user_id)

  rewrite_var('oauth_access_token', access_token)
  rewrite_var('oauth_user_id', user_id)

  if conf.set_header then
    ngx.req.set_header('Authorization', "Bearer "..access_token)
  end

-- Response from the authorization server.
elseif request_path == conf.redirect_path then
  do_handle_callback()

-- No cookie with access token found, redirecting to the authorization server.
else
  ngx.log(ngx.INFO, "redirecting to "..conf.authorization_url)
  do_redirect_authorization()
end
