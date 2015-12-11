---------
-- Module for reading/writing request/response cookies.
-- This module exports single function, the module's constructor.
--
-- **Example:**
--     local Cookies = require 'ngx-oauth.Cookies'
--
--     cookies = Cookies(conf)
--     cookies.add_token(token)
--
-- @alias self

local util  = require 'ngx-oauth/util'
local nginx = require 'ngx-oauth/nginx'

local min      = math.min
local imap     = util.imap
local is_empty = util.is_empty
local par      = util.partial
local pipe     = util.pipe
local unless   = util.unless

local ALL_COOKIES = { 'access_token', 'refresh_token', 'username' }


--- Creates a new Cookies "object" with the given configuration.
--
-- @function __call
-- @tparam table conf The configuration (see @{ngx-oauth.config}).
-- @tparam {encrypt=func,decrypt=func} crypto The crypto module to use
--   (default: @{ngx-oauth.crypto}).
-- @return An initialized Cookies module.
return function (conf, crypto)
  if not crypto then
    crypto = require 'ngx-oauth/crypto'
  end

  local self = {}
  local refresh_token = nil  -- cached token after decryption

  local encrypt = par(crypto.encrypt, conf.aes_bits, conf.client_secret)
  local decrypt = par(crypto.decrypt, conf.aes_bits, conf.client_secret)

  local function create_cookie (name, value, max_age)
    return nginx.format_cookie(conf.cookie_prefix..name, value, {
      version = 1, secure = true, path = conf.cookie_path, max_age = max_age
    })
  end

  local function clear_cookie (name)
    return create_cookie(name, 'deleted', 0)
  end

  local function get_cookie(name)
    return nginx.get_cookie(conf.cookie_prefix..name)
  end

  --- Writes access token and refresh token (if provided) cookies to the
  -- *response's* `Set-Cookie` header.
  --
  -- @tparam {access_token=string,expires_in=int,refresh_token=(string|nil)} token
  self.add_token = function(token)
    local cookies = {
      create_cookie('access_token', token.access_token, min(token.expires_in, conf.max_age))
    }
    if token.refresh_token and token.refresh_token ~= self.get_refresh_token() then
      table.insert(cookies,
        create_cookie('refresh_token', encrypt(token.refresh_token), conf.max_age))
    end
    nginx.add_response_cookies(cookies)
  end

  --- Writes username cookie to the *response's* `Set-Cookie` header.
  --
  -- @tparam string username
  self.add_username = function(username)
    nginx.add_response_cookies {
      create_cookie('username', username, conf.max_age)
    }
  end

  --- Clears all cookies managed by this module, i.e. adds them to the
  -- *response's* `Set-Cookie` header with value `deleted` and `Max-Age=0`.
  --
  -- @function clear_all
  self.clear_all = pipe {
    par(imap, clear_cookie, ALL_COOKIES),
    nginx.add_response_cookies
  }

  --- Reads an access token from the *request's* cookies.
  --
  -- @function get_access_token
  -- @treturn string|nil An access token, or `nil` if not set.
  self.get_access_token = par(get_cookie, 'access_token')

  --- Reads a refresh token from the *request's* cookies.
  -- @treturn string|nil A decrypted refresh token, or `nil` if not set.
  self.get_refresh_token = function()
    if not refresh_token then
      refresh_token = unless(is_empty, decrypt, get_cookie('refresh_token'))
    end
    return refresh_token
  end

  --- Reads an username from the *request's* cookies.
  --
  -- @function get_username
  -- @treturn string|nil An username, or `nil` if not set.
  self.get_username = par(get_cookie, 'username')

  return self
end
