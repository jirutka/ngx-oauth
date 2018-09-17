---------
-- Utilities for nginx.

local util = require 'ngx-oauth.util'

-- Allow either cjson, or th-LuaJSON.
local ok, json = pcall(require, 'cjson')
if not ok then
  json = require 'json'
end

-- unpack is not global since Lua 5.3
local unpack = table.unpack or unpack  --luacheck: ignore

local concat   = util.concat
local is_empty = util.is_empty
local par      = util.partial
local unless   = util.unless

local LOG_PREFIX = '[ngx-oauth] '


local function sub_vararg_nil (...)
  local result = {}
  for i = 1, select('#', ...) do
    local v = select(i, ...)
    table.insert(result, v == nil and '#nil' or v)
  end
  return unpack(result)
end

local function log_formatted (level, message, ...)
  ngx.log(level, LOG_PREFIX..message:format(sub_vararg_nil(...)))
end

local M = {}

--- Adds table of cookies to the response's `Set-Cookie` header. If the header
-- is already set, then the new cookies are appended to the existing ones.
--
-- @tparam {string,...} cookies The cookies to append.
-- @see format_cookie
function M.add_response_cookies (cookies)
  local set_cookie = ngx.header['Set-Cookie']

  if type(set_cookie) == 'string' then
    cookies = concat({set_cookie}, cookies)

  elseif set_cookie ~= nil then
    cookies = concat(set_cookie, cookies)
  end

  -- Note: This is not a writable Lua table,
  -- we can't insert new item into it directly!
  ngx.header['Set-Cookie'] = cookies
end

--- Interrupts execution of the current request for a failure.
--
-- 1. Logs the given error message with level `ngx.WARN`, if the `status` is
-- less than 500, or `ngx.ERR` otherwise.
--
-- 2. Sends response with the specified HTTP status and JSON body:
--        { "message": "The error message" }
--
-- @tparam int status The HTTP status code to send.
-- @tparam string message The error message to log and send.
-- @param ... Arguments for @{string.format} being applied to `message`. Nil
--   values are replaced with `#nil`.
function M.fail (status, message, ...)
  assert(status >= 400 and status < 600, 'status must be >= 400 and < 600')

  message = message:format(sub_vararg_nil(...))
  local level = status >= 500 and ngx.ERR or ngx.WARN

  M.log(level, message)

  ngx.status = status
  ngx.header.content_type = 'application/json'
  ngx.say(json.encode({ error = message }))

  -- This is a workaround to send response body; it will still send
  -- the status specified above.
  return ngx.exit(ngx.HTTP_OK)
end

--- Formats HTTP cookie from the given arguments.
--
-- @tparam string name
-- @tparam string value
-- @tparam {[string]=string,...} attrs The cookie's attributes. Underscores in
--   the attribute name are implicitly replaced with dashes.
-- @treturn string A cookie string.
function M.format_cookie (name, value, attrs)
  local t = { name..'='..ngx.escape_uri(value) }
  for k, v in pairs(attrs) do
    k = k:gsub('_', '-')
    table.insert(t, v == true and k or k..'='..v)
  end
  return table.concat(t, ';')
end

--- Returns URI-decoded value of the specified request's cookie.
--
-- @tparam string name The name of the cookie to get.
-- @treturn string|nil The cookie's value, or nil if doesn't exist.
function M.get_cookie (name)
  return unless(is_empty, ngx.unescape_uri, ngx.var['cookie_'..name])
end

--- Returns URI-decoded value of the specified request's URI argument
-- (query parameter).
--
-- @tparam string name The name of the argument to get.
-- @treturn string|nil The argument's value, or nil if doesn't exist.
function M.get_uri_arg (name)
  return unless(is_empty, ngx.unescape_uri, ngx.var['arg_'..name])
end

--- Logs the given (formatted) `message` on the specified logging `level`.
-- There are 8 levels defined by ngx's constants (you can find list of them
-- [here](https://github.com/openresty/lua-nginx-module/#nginx-log-level-constants)).
--
-- This module also defines convenient functions for most common levels:
-- `log.err()`, `log.warn()`, `log.info()`, and `log.debug()`.
--
-- @function log
-- @tparam int level The logging level (0-8).
-- @tparam string message
-- @param ... Arguments for @{string.format} being applied to `message`. Nil
--   values are replaced with `#nil`.
M.log = setmetatable({
  err   = par(log_formatted, ngx.ERR),
  warn  = par(log_formatted, ngx.WARN),
  info  = par(log_formatted, ngx.INFO),
  debug = par(log_formatted, ngx.DEBUG),
}, {
  __call = function(_, level, message, ...)
    assert(level >= 0 and level < 9, 'level must be >= 0 and < 9')
    log_formatted(level, message, ...)
  end
})

return M
