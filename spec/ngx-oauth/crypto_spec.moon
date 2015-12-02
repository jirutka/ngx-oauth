require 'moon.all'
basexx = require 'basexx'
crypto = require 'ngx-oauth.crypto'

key = 'veeSae0ooquibeil1eph'
plain = 'allons-y!'
encrypted = 'I6u7/Lp5vS+APJJtBjVRGdteDmq0Fxt45xzrEb7Q9ag='


describe 'encrypt/decrypt', ->

  it 'encrypts and decryptes string', ->
    encrypted = crypto.encrypt(128, key, plain)
    assert.is_nil encrypted\find(plain, 1, true)
    assert.same plain, crypto.decrypt(128, key, encrypted)


describe 'decrypt', ->

  context 'given correct key and encrypted value', ->
    it 'returns decrypted value', ->
      assert.same plain, crypto.decrypt(128, key, encrypted)

  context 'given unsupported bits', ->
    it 'throws error', ->
      assert.error_matches (-> crypto.decrypt(66, key, 'atleastsixteencharslong')),
                           '.*invalid cipher type'

  context 'given too short key', ->
    it 'throws error "invalid key length"', ->
      assert.error_matches (-> crypto.decrypt(128, 'meh.', 'atleastsixteencharslong')),
                           '.*invalid key length.*'

  context 'given wrong key', ->
    it 'returns nil', ->
      assert.is_nil crypto.decrypt(128, 'misied5vaTh3mai2', encrypted)

  context 'given too short value', ->
    it 'returns nil', ->
      assert.is_nil crypto.decrypt(128, key, 'tooshortbro')

  context 'given invalid base64 value', ->
    it 'returns nil', ->
      assert.is_nil crypto.decrypt(128, key, '%invalid%')
