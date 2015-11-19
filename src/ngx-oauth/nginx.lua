---------
-- Utilities for nginx.

local util = require 'ngx-oauth.util'

-- Allow either cjson, or th-LuaJSON.
local ok, json = pcall(require, 'cjson')
if not ok then
  json = require 'json'
end

local concat   = util.concat
local is_empty = util.is_empty
local unless   = util.unless


local LOG_PREFIX = '[ngx-oauth] '

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
-- @param ... Arguments for @{string.format} being applied to `message`.
function M.fail (status, message, ...)
  assert(status >= 400 and status < 600, 'status must be >= 400 and < 600')

  message = message:format(...)
  local level = status >= 500 and ngx.ERR or ngx.WARN

  M.log(ngx.WARN, level, message)

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

--- Logs the given `message` on the specified logging `level` (e.g. `ngx.ERR`,
-- `ngx.INFO`), if the `level` is less or equal to the `threshold`.
--
-- @tparam int threshold The logging level threshold (0-8).
-- @tparam int level The logging level (0-8).
-- @tparam string message
-- @param ... Arguments for @{string.format} being applied to `message`.
function M.log (threshold, level, message, ...)
  assert(level >= 0 and level < 9, 'level must be >= 0 and < 9')

  if level <= threshold then
    ngx.log(level, LOG_PREFIX..message:format(...))
  end
end

return M
