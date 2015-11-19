---------
-- Module for configuration loading.

local util = require 'ngx-oauth.util'

local contains = util.contains
local is_blank = util.is_blank
local map      = util.map
local par      = util.partial

local M = {}

local defaults = {
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
  max_age           = 2592000, -- 30 days
  aes_bits          = 256,
  debug             = false
}

local load_from_ngx = par(map, function(default_value, key)
    return util.default(ngx.var['oauth_'..key], default_value)
  end, defaults)

--- Loads settings from nginx variables and ensure that all required
-- variables are set.
--
-- @treturn {[string]=any,...} Settings
-- @treturn nil|string Validation error, or `false` if no validation
--   error was found.
function M.load ()
  local errors = {}
  local conf = load_from_ngx()
  local server_url = not is_blank(conf.server_url) and conf.server_url

  if is_blank(conf.client_id) then
    table.insert(errors, 'variable $oauth_client_id is not set')
  end

  if is_blank(conf.client_secret) then
    table.insert(errors, 'variable $oauth_client_secret is not set')
  end

  if not contains(conf.aes_bits, {128, 192, 256}) then
    table.insert(errors, '$oauth_aes_bits must be 128, 192, or 256')
  end

  if conf.client_secret:len() < conf.aes_bits / 8 then
    table.insert(errors, '$oauth_client_secret is too short, it must be at least '..
      (conf.aes_bits / 8)..' characters long for $oauth_aes_bits = '..conf.aes_bits)
  end

  for _, key in ipairs {'authorization_url', 'token_url', 'userinfo_url'} do
    if not server_url and conf[key]:find('${server_url}', 1, true) then
      table.insert(errors, 'neither variable $oauth_'..key..' nor $oauth_server_url is set')
    elseif server_url then
      conf[key] = conf[key]:gsub('${server_url}', server_url)
    end
  end

  return conf, #errors ~= 0 and table.concat(errors, ', ')
end

return M
