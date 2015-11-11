require 'moon.all'
basexx = require 'basexx'
crypto = require 'ngx-oauth.crypto'


describe 'encrypt/decrypt', ->
  key = 'veeSae0ooquibeil1epheo3iFerah3shai'
  plain = 'allons-y!'

  setup ->
    _G.ngx = mock
      encode_base64: (value) -> basexx.to_base64(value)
      decode_base64: (value) -> basexx.from_base64(value)

  it 'encrypts and decryptes string', ->
    encrypted = crypto.encrypt(128, key, plain)
    assert.is_nil encrypted\find(plain, 1, true)
    assert.same plain, crypto.decrypt(128, key, encrypted)

