---------
-- Module for OAuth 2.0 authorization.

local http_client = require 'ngx-oauth.http_client'


local function basic_auth_header (username, password)
  return 'Basic '..ngx.encode_base64(username..':'..password)
end

local M = {}

--- Builds an authorization URL for initiation of the authorization code flow.
--
-- @tparam table conf The configuration (see @{ngx-oauth.config}).
-- @tparam ?string state The state parameter.
-- @treturn string An URL.
function M.authorization_url (conf, state)
  local args = ngx.encode_args {
    response_type = 'code',
    client_id     = conf.client_id,
    redirect_uri  = conf.redirect_uri,
    scope         = conf.scope,
    state         = state
  }
  return conf.authorization_url..'?'..args
end

--- Requests an access token from the authorization server.
--
-- @tparam string grant_type The authorization grant to use;
--   `authorization_code`, `refresh_token`, or `client_credentials`.
-- @tparam table conf The configuration (see @{ngx-oauth.config}).
-- @tparam string value The authorization code, refresh token, or nil; depends
--   on the `grant_type`.
-- @treturn Either @{either.Right|Right} with parsed token response as a table,
--   or @{either.Left|Left} with an error message.
function M.request_token (grant_type, conf, value)
  local params = ({
    authorization_code = { code = value, redirect_uri = conf.redirect_uri },
    refresh_token      = { refresh_token = value },
    client_credentials = { scope = conf.scope }
  })[grant_type]

  assert(params, 'grant_type must be authorization_code, refresh_token, or client_credentials')
  params.grant_type = grant_type

  local headers = {
    Authorization = basic_auth_header(conf.client_id, conf.client_secret)
  }
  return http_client.post_form_for_json(headers, conf.token_url, params)
end

return M
