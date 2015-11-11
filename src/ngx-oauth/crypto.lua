---------
-- Cryptographic utilities.

-- luaossl lib
local rand = require 'openssl.rand'
local cipher = require 'openssl.cipher'

local IV_BYTES = 16


local function get_cipher (bits)
  return cipher.new('aes-'..bits..'-cbc')
end

local function align_key (bits, key)
  return key:sub(1, bits / 8)
end

local M = {}

--- Encrypts the given string using AES.
--
-- @tparam int bits The AES block size in bits: 128, 192, or 256.
-- @tparam string key The secret key to use for encryption. It must be greater
--   or equal than `bits / 8`.
-- @tparam string value The string to encrypt.
-- @treturn string A pair of IV and encrypted string encoded in Base64.
function M.encrypt (bits, key, value)
  local iv = rand.bytes(IV_BYTES)

  local encrypted = get_cipher(bits):encrypt(align_key(bits, key), iv):final(value)
  return ngx.encode_base64(iv..encrypted)
end

--- Decrypts the given value using AES.
--
-- @tparam int bits The AES block size in bits: 128, 192, or 256.
-- @tparam string key The secret key to use for decryption. It must be greater
--   or equal than `bits / 8`.
-- @tparam string value The pair of IV and encrypted string encoded in Base64.
-- @treturn string A decrypted string.
function M.decrypt (bits, key, value)
  value = ngx.decode_base64(value)
  local iv = value:sub(1, IV_BYTES)
  local encrypted = value:sub(17)

  return get_cipher(bits):decrypt(align_key(bits, key), iv):final(encrypted)
end

return M
