require 'moon.all'
Cookies = require 'ngx-oauth.Cookies'
import concat from require 'ngx-oauth.util'

ALL_COOKIES = {'access_token', 'original_uri', 'refresh_token', 'username'}

set_cookie = (name, value) ->
  ngx.var['cookie_'..name] = value


describe '__call', ->

  conf =
    client_secret: 'super-top-secret-password'
    cookie_path: '/app'
    cookie_prefix: 'oa_'
    max_age: 600
    aes_bits: 128

  prefix = conf.cookie_prefix
  cookie_attrs = "path=#{conf.cookie_path};secure;version=1"

  setup ->
    _G.pairs = spec_helper.sorted_pairs
    export crypto_stub = mock {
      encrypt: (bits, key, value) -> string.reverse(value)
      decrypt: (bits, key, value) -> string.reverse(value)
    }

  before_each ->
    export cookies = Cookies(conf, crypto_stub)
    _G.ngx = spec_helper.ngx_mock!


  describe 'add_token', ->

    access_token_cookie = (token, max_age = token.expires_in) ->
      "#{prefix}access_token=#{token.access_token};max-age=#{max_age};#{cookie_attrs}"

    it 'does not overwrite content of Set-Cookie', ->
      existing = 'foo=42;path=/'
      _G.ngx.header['Set-Cookie'] = existing
      tkn = { access_token: 'acc-token', expires_in: 42 }

      cookies.add_token(tkn)
      assert.same {existing, access_token_cookie(tkn)}, _G.ngx.header['Set-Cookie']

    context 'with expires_in less than conf.max_age', ->
      tkn = { access_token: 'acc-token', expires_in: conf.max_age / 2 }
      expected = { access_token_cookie(tkn) }

      it "writes cookie with access token and Max-Age equal to token's expires_in", ->
        cookies.add_token(tkn)
        assert.same expected, _G.ngx.header['Set-Cookie']

    context 'with expires_in greater than conf.max_age', ->
      tkn = { access_token: 'acc-token', expires_in: conf.max_age * 2 }
      expected = { access_token_cookie(tkn, conf.max_age) }

      it 'writes cookie with access token and Max-Age equals to conf.max_age', ->
        cookies.add_token(tkn)
        assert.same expected, _G.ngx.header['Set-Cookie']

    context 'with both access and refresh token', ->
      tkn = { access_token: 'acc-token', expires_in: conf.max_age / 2, refresh_token: 'reftok-123' }
      expected = {
        access_token_cookie(tkn),
        "#{prefix}refresh_token=321-kotfer;max-age=#{conf.max_age};#{cookie_attrs}"
      }

      it 'writes cookie with access token and encrypted refresh token', ->
        cookies.add_token(tkn)
        assert.same expected, _G.ngx.header['Set-Cookie']
        assert.stub(crypto_stub.encrypt).called_with(conf.aes_bits, conf.client_secret, tkn.refresh_token)

      context 'when cookie with same refresh token exists', ->
        it 'does not write new refresh token cookie', ->
          set_cookie "#{prefix}refresh_token", '321-kotfer'
          cookies.add_token(tkn)
          assert.same { access_token_cookie(tkn) }, _G.ngx.header['Set-Cookie']


  describe 'add_original_uri', ->
    expected = { "#{prefix}original_uri=https%3A%2F%2Fexample.org%2Ffoobar%2F;max-age=600;#{cookie_attrs}" }

    it 'writes cookies with original_uri', ->
      cookies.add_original_uri('https://example.org/foobar/')
      assert.same expected, _G.ngx.header['Set-Cookie']

    it 'does not overwrite existing Set-Cookie', ->
      existing = {'foo=42;path=/', 'bar=55;path=/'}
      _G.ngx.header['Set-Cookie'] = existing

      cookies.add_original_uri('https://example.org/foobar/')
      assert.same concat(existing, expected), _G.ngx.header['Set-Cookie']


  describe 'add_username', ->
    expected = { "#{prefix}username=flynn;max-age=#{conf.max_age};#{cookie_attrs}" }

    it 'writes cookies with username and Max-Age equals to conf.max_age', ->
      cookies.add_username('flynn')
      assert.same expected, _G.ngx.header['Set-Cookie']

    it 'does not overwrite existing Set-Cookie', ->
      existing = {'foo=42;path=/', 'bar=55;path=/'}
      _G.ngx.header['Set-Cookie'] = existing

      cookies.add_username('flynn')
      assert.same concat(existing, expected), _G.ngx.header['Set-Cookie']


  describe 'clear', ->
    name = 'foo'

    it 'sets the specified cookie to "deleted" and max-age 0', ->
      cookies.clear(name)
      assert.same { "#{prefix}#{name}=deleted;max-age=0;#{cookie_attrs}" }, _G.ngx.header['Set-Cookie']


  describe 'clear_all', ->
    expected = [ "#{prefix}#{name}=deleted;max-age=0;#{cookie_attrs}" for name in *ALL_COOKIES ]

    it 'sets access_token, refresh_token and username cookies to "deleted" and max-age 0', ->
      cookies.clear_all()
      assert.same expected, _G.ngx.header['Set-Cookie']


  describe 'get_access_token', ->

    it 'returns value of access_token cookie', ->
      set_cookie "#{prefix}access_token", 'token-123'
      assert.same 'token-123', cookies.get_access_token()


  describe 'get_original_uri', ->

    context 'original_uri cookie exists', ->
      it 'returns value of original_uri cookie', ->
        set_cookie "#{prefix}original_uri", 'https://example.org/foobar/'
        assert.same 'https://example.org/foobar/', cookies.get_original_uri()

    context 'original_uri cookie does not exist', ->
      it 'returns nil', ->
        assert.is_nil cookies.get_original_uri()


  describe 'get_refresh_token', ->

    context 'refresh_token cookie exists', ->
      it 'returns decrypted value of the cookie', ->
        set_cookie "#{prefix}refresh_token", '321-kotfer'

        assert.same 'reftok-123', cookies.get_refresh_token()
        assert.stub(crypto_stub.decrypt).called_with(conf.aes_bits, conf.client_secret, '321-kotfer')

    context 'refresh_token cookie does not exist', ->
      it 'returns nil', ->
        assert.is_nil cookies.get_refresh_token()


  describe 'get_username', ->

    it 'returns value of username cookie', ->
      set_cookie "#{prefix}username", 'flynn'
      assert.same 'flynn', cookies.get_username()
