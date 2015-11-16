require 'moon.all'
nginx = require 'ngx-oauth.nginx'
import concat from require 'ngx-oauth.util'


describe 'add_response_cookies', ->
  before_each ->
    _G.ngx = { header: {} }

  set_resp_cookie = (value) ->
    _G.ngx.header['Set-Cookie'] = value

  context 'when Set-Cookie is nil', ->
    it 'sets ngx.header[Set-Cookie] to the given cookies', ->
      new_cookies = {'first=1;path=/', 'second=2;path=/'}
      nginx.add_response_cookies(new_cookies)
      assert.same new_cookies, _G.ngx.header['Set-Cookie']

  context 'when Set-Cookie is string', ->
    old_cookie = 'first=1;path=/'
    new_cookies = {'second=2;path=/', 'third=3;path=/'}

    it 'converts ngx.header[Set-Cookie] to table and appends the given cookies', ->
      set_resp_cookie old_cookie
      nginx.add_response_cookies(new_cookies)
      assert.same concat({old_cookie}, new_cookies), _G.ngx.header['Set-Cookie']

  context 'when Set-Cookie is table', ->
    old_cookies = {'first=1;path=/', 'second=2;path=/'}
    new_cookies = {'third=3;path=/'}

    it 'appends given cookies to ngx.header[Set-Cookie]', ->
      set_resp_cookie old_cookies
      nginx.add_response_cookies(new_cookies)
      assert.same concat(old_cookies, new_cookies), _G.ngx.header['Set-Cookie']


describe 'format_cookie', ->
  setup ->
    _G.pairs = sorted_pairs
    _G.ngx = mock
      escape_uri: (value) -> string.gsub(value, ' ', '+')

  it 'returns correctly formated cookie with attributes', ->
    actual = nginx.format_cookie('foo', 'meh', version: 1, path: '/')
    assert.same 'foo=meh;path=/;version=1', actual

  it 'escapes cookie value using ngx.escape_uri', ->
    assert.same 'foo=chunky+bacon', nginx.format_cookie('foo', 'chunky bacon', {})
    assert.stub(_G.ngx.escape_uri).called_with 'chunky bacon'

  it "omits attribute's value if it's true", ->
    assert.same 'foo=bar;secure', nginx.format_cookie('foo', 'bar', secure: true)

  it 'replaces underscore in attribute name with a dash', ->
    assert.same 'foo=bar;max-age=60', nginx.format_cookie('foo', 'bar', max_age: 60)


describe 'get_cookie', ->
  setup ->
    _G.ngx = {
      var: { cookie_foo: 'meh.' }
    }

  context 'existing cookie', ->
    it 'returns cookie value from ngx.var', ->
      assert.same 'meh.', nginx.get_cookie('foo')

  context 'non-existing cookie', ->
    it 'returns nil', ->
      assert.is_nil nginx.get_cookie('noop')
