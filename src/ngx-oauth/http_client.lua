---------
-- Adapter for HTTP client.

local util = require 'ngx-oauth.util'
local eith = require 'ngx-oauth.either'
local http = require 'resty.http'

-- Allow either cjson, or th-LuaJSON.
local ok, json = pcall(require, 'cjson')
if not ok then
  json = require 'json'
end

local merge   = util.merge
local encase  = eith.encase
local encase2 = eith.encase2
local Left    = eith.Left
local Right   = eith.Right


local function ensure_status_200 (resp)
  if resp.status ~= 200 then
    return Left(('HTTP %s: %s'):format(resp.status, resp.body))
  else
    return Right(resp)
  end
end


local M = {}

--- Sends an HTTP request and returns a response.
--
-- If the request is successful, response wrapped in `Right` will contain the
-- following fields:
--
--  * status: The status code.
--  * headers: A table of headers.
--  * body: The response body as a string.
--
-- @tparam string method The HTTP method (e.g. GET, POST, HEAD, ...).
-- @tparam {[string]=string,...} headers The request's headers.
-- @tparam string url The request's URL.
-- @tparam string body The request's body as string.
-- @treturn either.Left|either.Right Either a response (`Right`),
--   or an error message (`Left`).
function M.request (method, headers, url, body)

  local init_http = encase2(http.new)
  local request_uri = encase2(http.request_uri)

  local params = {
    method     = method,
    headers    = headers,
    body       = body,
    ssl_verify = true
  }
  return init_http().chain(function(client)
      return request_uri(client, url, params)
    end)
end

--- Sends an HTTP request and returns a parsed JSON body (wrapped in `Right`)
-- if response status is 200; otherwise returns an error message (wrapped
-- in `Left`). This method accepts the same arguments as `request`.
--
-- @treturn either.Left|either.Right Either a response (`Right`),
--   or an error message (`Left`).
function M.request_json (method, headers, url, body)
  return M.request(method, merge({ Accept = 'application/json' }, headers), url, body)
    .chain(ensure_status_200)
    .map(function(resp) return resp.body end)
    .chain(encase(json.decode))
end

--- Sends an HTTP POST request with body encoded as `x-www-form-urlencoded`
-- and returns a parsed JSON body (wrapped in `Right`}) if response status is
-- 200; otherwise returns an error message (wrapped in `Left`).
--
-- @tparam {[string]=string,...} headers The request's headers.
-- @tparam string url The request's URL.
-- @tparam {[string]=string,...} form_data The form data as a table.
-- @treturn either.Left|either.Right Either a parsed JSON as a table (`Right`),
--   or an error message (`Left`).
function M.post_form_for_json (headers, url, form_data)
  return M.request_json('POST',
    merge(headers, { ['Content-Type'] = 'application/x-www-form-urlencoded' }),
    url, ngx.encode_args(form_data))
  -- Note: This function can be simply extracted to reusable decorator, but
  -- it's not needed for now.
end

return M
