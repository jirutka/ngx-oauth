---------
-- Module for configuration loading.

local util = require 'ngx-oauth.util'

local contains = util.contains
local is_blank = util.is_blank
local map      = util.map
local par      = util.partial

local DEFAULTS = {
  client_id         = '',
  client_secret     = '',
  scope             = '',
  redirect_path     = '/_oauth/callback',
  server_url        = '',  -- used only as a shorthand for setting these 3 below
  authorization_url = '${server_url}/authorize',
  token_url         = '${server_url}/token',
  userinfo_url      = "${server_url}/userinfo",
  success_path      = '/',
  cookie_path       = '/',
  cookie_prefix     = 'oauth_',
  max_age           = 2592000, -- 30 days
  aes_bits          = 128,
  debug             = false
}

local OAAS_ENDPOINT_VARS = {'authorization_url', 'token_url', 'userinfo_url'}


local load_from_ngx = par(map, function(default_value, key)
    return util.default(ngx.var['oauth_'..key], default_value)
  end, DEFAULTS)

local function validate (conf)
  local errors = {}

  if is_blank(conf.client_id) then
    table.insert(errors, '$oauth_client_id is not set')
  end

  if is_blank(conf.client_secret) then
    table.insert(errors, '$oauth_client_secret is not set')
  end

  if not contains(conf.aes_bits, {128, 192, 256}) then
    table.insert(errors, '$oauth_aes_bits must be 128, 192, or 256')
  end

  if conf.client_secret:len() < conf.aes_bits / 8 then
    table.insert(errors, ('$oauth_client_secret is too short, it must be at least %.0f'..
      ' characters long for $oauth_aes_bits = %.0f'):format(conf.aes_bits / 8, conf.aes_bits))
  end

  for _, key in ipairs(OAAS_ENDPOINT_VARS) do
    if conf[key]:find('${server_url}', 1, true) then
      table.insert(errors, 'neither $oauth_'..key..' nor $oauth_server_url is set')
    end
  end

  return errors
end

local M = {}

--- Loads settings from nginx variables and ensure that all required
-- variables are set.
--
-- @treturn {[string]=any,...} Settings
-- @treturn nil|string Validation error, or `false` if no validation
--   error was found.
function M.load ()
  local conf = load_from_ngx()

  if not is_blank(conf.server_url) then
    for _, key in ipairs(OAAS_ENDPOINT_VARS) do
      conf[key] = conf[key]:gsub('${server_url}', conf.server_url)
    end
  end

  local errors = validate(conf)
  return conf, #errors ~= 0 and table.concat(errors, '; ')
end

return M
