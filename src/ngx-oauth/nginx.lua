---------
-- Utilities for nginx.

local util = require 'ngx-oauth.util'
local concat = util.concat

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

--- Returns value of the specified request's cookie.
--
-- @tparam string name The name of the cookie to get.
-- @treturn string|nil The cookie's value, or nil if doesn't exist.
function M.get_cookie (name)
  return ngx.var['cookie_'..name]
end

return M
