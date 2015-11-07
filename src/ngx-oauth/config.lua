---------
-- This module is responsible for configuration loading and validating.

local util = require 'ngx-oauth/util'
local not_blank = util.not_blank

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
  crypto_alg        = 'aes-256-cbc',
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
-- @treturn {[string]=any,...}
-- @raise An error message when some required variable is not set.
function M.load ()
  local conf = load_from_ngx()
  local oaas_url = conf.server_url

  assert(not_blank(conf.client_id), 'Variable $oauth_client_id is not set.')
  assert(not_blank(conf.client_secret), 'Variable $oauth_client_secret is not set.')

  for _, key in ipairs {'authorization_url', 'token_url', 'check_token_url'} do
    if conf[key]:find('${server_url}', 1, true) then
      assert(not_blank(oaas_url), 'Neither variable $oauth_'..key..' nor $oauth_server_url is set.')
      conf[key] = conf[key]:gsub('${server_url}', oaas_url)
    end
  end

  return conf
end

return M
