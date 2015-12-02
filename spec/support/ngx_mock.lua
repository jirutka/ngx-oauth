---------
-- Mock for global ngx table. This implementation is not complete, it contains
-- just subset of variables and functions we need.

local basexx = require 'basexx'
local spy    = require 'luassert.spy'
local stub   = require 'luassert.stub'


local function escape_uri (str)
  return tostring(str):gsub('\n', '\r\n'):gsub('([^%w%-_.~ ])', function(ch)
    return string.format('%%%02X', string.byte(ch))
  end):gsub(' ', '+')
end

local function encode_args (tab)
  local list = {}
  for k, v in pairs(tab) do
    table.insert(list, escape_uri(k)..'='..escape_uri(v))
  end
  return table.concat(list, '&')
end

local function unescape_uri (str)
  return tostring(str):gsub('+', ' '):gsub('\r\n', '\n'):gsub('%%(%x%x)', function(b)
    return string.char(tonumber(b, 16))
  end)
end

return function()
  return {
    -- Log constants
    STDERR = 0,
    EMERG  = 1,
    ALERT  = 2,
    CRIT   = 3,
    ERR    = 4,
    WARN   = 5,
    NOTICE = 6,
    INFO   = 7,
    DEBUG  = 8,

    -- Tables
    var = {},
    header = {},

    -- Spied functions

    -- nginx's implementation returns nil when input can't be decoded.
    decode_base64 = spy(function(...)
      local ok, ret = pcall(basexx.from_base64, ...)
      if ok then return ret end
    end),

    encode_args   = spy(encode_args),
    encode_base64 = spy(basexx.to_base64),
    escape_uri    = spy(escape_uri),
    unescape_uri  = spy(unescape_uri),

    -- Stubs for functions without any return value
    log           = stub(),
    say           = stub(),
    exit          = stub()
  }
end
