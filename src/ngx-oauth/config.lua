---------
-- This module is responsible for configuration loading and validating.

local util = require 'ngx-oauth.util'
local is_blank = util.is_blank

local M = {}

local defaults = {
  client_id         = '',
  client_secret     = '',
  scope             = '',
  redirect_path     = '/_oauth/callback',
  server_url        = '',  -- used only as a shorthand for setting these 3 below
  authorization_url = '${server_url}/authorize',
  token_url         = '${server_url}/token',
  check_token_url   = "${server_url}/check_token",
  success_path      = '',
  cookie_path       = '/',
  max_age           = 2592000, -- 30 days
  aes_bits          = 256,
  debug             = false
}

local function load_from_ngx ()
  local conf = {}

  for key, default_value in pairs(defaults) do
    conf[key] = util.default(ngx.var['oauth_'..key], default_value)
  end

  return conf
end

--- Loads settings from nginx variables and ensure that all required
-- variables are set.
--
-- @treturn {[string]=any,...} Settings
-- @treturn nil|{string, ...} Validation messages, or `nil` if no validation
--   error was found.
function M.load ()
  local errors = {}
  local conf = load_from_ngx()
  local server_url = not is_blank(conf.server_url) and conf.server_url

  if is_blank(conf.client_id) then
    table.insert(errors, 'Variable $oauth_client_id is not set.')
  end
  if is_blank(conf.client_secret) then
    table.insert(errors, 'Variable $oauth_client_secret is not set.')
  end

  for _, key in ipairs {'authorization_url', 'token_url', 'check_token_url'} do
    if not server_url and conf[key]:find('${server_url}', 1, true) then
      table.insert(errors, 'Neither variable $oauth_'..key..' nor $oauth_server_url is set.')
    elseif server_url then
      conf[key] = conf[key]:gsub('${server_url}', server_url)
    end
  end

  return conf, #errors ~= 0 and errors
end

return M
