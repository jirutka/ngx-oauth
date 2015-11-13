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

local http = require 'resty.http'

-- Allow either cjson, or th-LuaJSON.
local has_cjson, jsonmod = pcall(require, 'cjson')
if not has_cjson then
  jsonmod = require 'json'
end

local config = require 'ngx-oauth.config'
local Cookies = require 'ngx-oauth.cookies'

local util = require 'ngx-oauth.util'
local partial = util.partial


---------- Variables ----------

-- Exit with HTTP 500 when required variables are not set or invalid.
local conf, errs = config.load()
if errs then
  ngx.log(ngx.ERR, unpack(errs))
  return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

local debug          = conf.debug
local ngx_server_url = ngx.var.scheme..'://'..ngx.var.server_name
local request_path   = ngx.var.uri
local request_args   = ngx.req.get_uri_args()

local cookies = Cookies(conf)


---------- Functions ----------

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
    ngx.log(ngx.ERR, ("request to %s has failed with: %s"):format(
                      uri, err or res.status..': '..res.body))
  end
end

--- Sends an HTTP POST request with URL-encoded data, authenticated with the
-- client credentials using HTTP Basic and returns response body parsed
-- as JSON.
--
-- @param request_f the function to perform a request, see #request_uri.
-- @param #string uri
-- @param #map data
-- @return #map a parsed response body, or nil if respond is not HTTP 200.
local function post_form(request_f, uri, data)
  local credentials = conf.client_id..':'..conf.client_secret

  local res = request_f(uri, {
    method = 'POST',
    body = ngx.encode_args(data),
    headers = {
      ['Accept'] = 'application/json',
      ['Authorization'] = 'Basic '..ngx.encode_base64(credentials),
      ['Content-Type'] = 'application/x-www-form-urlencoded'
    }
  })
  if res then
    if debug then ngx.log(ngx.DEBUG, 'received response: '..res.body) end
    return jsonmod.decode(res.body)
  end
end

--- Obtains access token using authorization code (grant client_credentials).
-- @param request_f the function to perform a request, see #request_uri.
-- @param #string auth_code the authorization code obtained from the
--        authorization server.
-- @return #map a parsed response body.
local function request_token_using_code(request_f, auth_code)
  return post_form(request_f, conf.token_url, {
    grant_type = 'authorization_code',
    code = auth_code,
    redirect_uri = ngx_server_url..conf.redirect_path
  })
end

--- Obtains access token using refresh token (grant refresh_token).
-- @param request_f the function to perform a request, see #request_uri.
-- @param #string refresh_token
-- @return #map a parsed response body.
local function request_token_using_refresh(request_f, refresh_token)
  return post_form(request_f, conf.token_url, {
    grant_type = 'refresh_token',
    refresh_token = refresh_token
  })
end

--- Requests info about user that authorized the given access token.
-- @param request_f the function to perform a request, see #request_uri.
-- @param #string access_token
-- @return #map a table with keys "nickname" and "email".
local function request_userinfo(request_f, access_token)
  local json = post_form(request_f, conf.check_token_url, {
    token = access_token
  })
  if json then
    return {
      nickname = json.user_name,
      email    = json.email
    }
  end
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

  if request_args.error then
    ngx.log(ngx.WARN, ("%s: received %s"):format(request_path, request_args.error))
    ngx.exit(ngx.HTTP_UNAUTHORIZED)

  elseif auth_code then
    if debug then ngx.log(ngx.DEBUG, 'requesting token for auth code: '..auth_code) end

    local request_f = partial(request_uri, http.new())

    local token = request_token_using_code(request_f, auth_code)
    if not token then
      return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    local userinfo = request_userinfo(request_f, token.access_token)
    if not userinfo then
      return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    cookies.add_token(token)
    cookies.add_userinfo(userinfo)

    local success_uri = request_args.state
    if conf.success_path then
      success_uri = ngx_server_url..conf.success_path
    end

    ngx.log(ngx.INFO, ("authorized user %s, redirecting to %s"):format(
                       userinfo.nickname, success_uri))
    ngx.redirect(success_uri)

  else
    ngx.exit(ngx.HTTP_BAD_REQUEST)
  end
end

--- Obtains a new access token using the given refresh token, sets it to
-- a cookie and exits with HTTP 204 (No Content).
-- @param #string refresh_token encrypted refresh token.
local function do_refresh_token(refresh_token)
  local request_f = partial(request_uri, http.new())

  local token = request_token_using_refresh(request_f, refresh_token)
  if not token then
    return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end

  cookies.add_token(token)

  ngx.exit(204)
end


---------- Main ----------

-- Got response from the authorization server.
if request_path == conf.redirect_path then
  do_handle_callback()

-- Cookie with access token exists.
elseif cookies.get_access_token() then
  ngx.redirect(ngx_server_url..(conf.success_path or '/'))

-- Cookie with refresh token exists, obtain a new access token.
elseif cookies.get_refresh_token() then
  ngx.log(ngx.INFO, 'refreshing token for user: '..cookies.get_username())
  do_refresh_token(cookies.get_refresh_token())

-- No cookie with access token found, redirecting to the authorization server.
else
  ngx.log(ngx.INFO, 'redirecting to '..conf.authorization_url)
  do_redirect_authorization()
end
