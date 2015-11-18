require 'moon.all'
Cookies = require 'ngx-oauth.Cookies'
import concat from require 'ngx-oauth.util'

ALL_COOKIES = {'oauth_access_token', 'oauth_refresh_token', 'oauth_username', 'oauth_email'}

set_cookie = (name, value) ->
  ngx.var['cookie_'..name] = value


describe '__call', ->

  conf =
    client_secret: 'super-top-secret-password'
    cookie_path: '/app'
    max_age: 600
    aes_bits: 128

  cookie_attrs = "path=#{conf.cookie_path};secure;version=1"

  setup ->
    _G.pairs = spec_helper.sorted_pairs
    export crypto_stub = mock {
      encrypt: (bits, key, value) -> "<ENC[#{value}]>"
      decrypt: (bits, key, value) -> "<DEC[#{value}]>"
    }

  before_each ->
    export cookies = Cookies(conf, crypto_stub)
    _G.ngx =
      var: {}
      header: {}
      escape_uri: (value) -> value\gsub(' ', '+')


  describe 'add_token', ->

    access_token_cookie = (token, max_age = token.expires_in) ->
      "oauth_access_token=#{token.access_token};max-age=#{max_age};#{cookie_attrs}"

    it 'does not overwrite content of Set-Cookie', ->
      existing = 'foo=42;path=/'
      _G.ngx.header['Set-Cookie'] = existing
      tkn = { access_token: 'acc-token', expires_in: 42 }

      cookies.add_token(tkn)
      assert.same {existing, access_token_cookie(tkn)}, _G.ngx.header['Set-Cookie']

    context 'token with expires_in less than conf.max_age', ->
      tkn = { access_token: 'acc-token', expires_in: conf.max_age / 2 }
      expected = { access_token_cookie(tkn) }

      it "writes cookie with access token and Max-Age equal to token's expires_in", ->
        cookies.add_token(tkn)
        assert.same expected, _G.ngx.header['Set-Cookie']

    context 'token with expires_in greater than conf.max_age', ->
      tkn = { access_token: 'acc-token', expires_in: conf.max_age * 2 }
      expected = { access_token_cookie(tkn, conf.max_age) }

      it 'writes cookie with access token and Max-Age equals to conf.max_age', ->
        cookies.add_token(tkn)
        assert.same expected, _G.ngx.header['Set-Cookie']

    context 'token with both access and refresh token', ->
      tkn = { access_token: 'acc-token', expires_in: conf.max_age / 2, refresh_token: 'ref-token' }
      expected = {
        access_token_cookie(tkn),
        "oauth_refresh_token=<ENC[#{tkn.refresh_token}]>;max-age=#{conf.max_age};#{cookie_attrs}"
      }

      it 'writes cookie with access token and encrypted refresh token', ->
        cookies.add_token(tkn)
        assert.same expected, _G.ngx.header['Set-Cookie']
        assert.stub(crypto_stub.encrypt).called_with(conf.aes_bits, conf.client_secret, tkn.refresh_token)


  describe 'add_userinfo', ->
    expected = {
      "oauth_username=flynn;max-age=#{conf.max_age};#{cookie_attrs}",
      "oauth_email=flynn@encom.com;max-age=#{conf.max_age};#{cookie_attrs}"
    }

    it 'writes cookies with username and email from userinfo', ->
      cookies.add_userinfo(username: 'flynn', email: 'flynn@encom.com')
      assert.same expected, _G.ngx.header['Set-Cookie']

    it 'does not overwrite existing Set-Cookie', ->
      existing = {'foo=42;path=/', 'bar=55;path=/'}
      _G.ngx.header['Set-Cookie'] = existing

      cookies.add_userinfo(username: 'flynn', email: 'flynn@encom.com')
      assert.same concat(existing, expected), _G.ngx.header['Set-Cookie']


  describe 'clear_all', ->
    expected = [ "#{name}=deleted;max-age=0;#{cookie_attrs}" for name in *ALL_COOKIES ]

    it 'sets all oauth_* cookies to "deleted" and max-age 0', ->
      cookies.clear_all()
      assert.same expected, _G.ngx.header['Set-Cookie']


  describe 'get_access_token', ->

    it 'returns value of cookie oauth_access_token', ->
      set_cookie 'oauth_access_token', 'token-123'
      assert.same 'token-123', cookies.get_access_token()


  describe 'get_refresh_token', ->

    context 'cookie oauth_refresh_token exists', ->
      it 'returns decrypted value of the cookie', ->
        set_cookie 'oauth_refresh_token', 'token-123'

        assert.same '<DEC[token-123]>', cookies.get_refresh_token()
        assert.stub(crypto_stub.decrypt).called_with(conf.aes_bits, conf.client_secret, 'token-123')

    context 'cookie oauth_refresh_token does not exist', ->
      it 'returns nil', ->
        assert.is_nil cookies.get_refresh_token()


  describe 'get_username', ->

    it 'returns value of cookie oauth_username', ->
      set_cookie 'oauth_username', 'flynn'
      assert.same 'flynn', cookies.get_username()
