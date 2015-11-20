require 'moon.all'
import _ from require 'luassert.match'
import concat from require 'ngx-oauth.util'
nginx = require 'ngx-oauth.nginx'


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


describe 'fail', ->
  setup ->
    _G.ngx = mock { ERR: 4, WARN: 5, HTTP_OK: 200, header: {}, log: ->, say: ->, exit: -> }

  context 'given valid status', ->
    before_each -> nginx.fail(503, 'Ay, %s!', 'caramba')

    it 'sets ngx.status to given status and ngx.header.content_type to json', ->
      assert.same 503, _G.ngx.status
      assert.same 'application/json', _G.ngx.header.content_type

    it 'calls ngx.say with JSON containing the given message', ->
      assert.stub(_G.ngx.say).called_with '{"error":"Ay, caramba!"}'

    -- This is a workaround to send response body; it will still send
    -- the status set in ngx.status.
    it 'calls ngx.exit with HTTP_OK', ->
      assert.stub(_G.ngx.exit).called_with _G.ngx.HTTP_OK

  context 'given status < 400 or >= 600', ->
    it 'throws error', ->
      for value in *{0, 200, 399, 600, nil, '400'} do
        assert.has_error -> nginx.fail value, 'fail'

  context 'given status >= 500', ->
    it 'logs given message with prefix "[ngx-oauth] " on level ERR', ->
      nginx.fail 500, 'Ay, caramba!'
      assert.stub(_G.ngx.log).called_with _G.ngx.ERR, '[ngx-oauth] Ay, caramba!'

  context 'given status < 500', ->
    it 'logs given message with prefix "[ngx-oauth] " on level WARN', ->
      nginx.fail 400, 'EXTERMINATE!'
      assert.stub(_G.ngx.log).called_with _G.ngx.WARN, '[ngx-oauth] EXTERMINATE!'

  context 'when some format arguments are nil', ->
    it 'substitutes nil with "#nil"', ->
      nginx.fail(500, 'such %s, so %s', 'string', nil)
      assert.stub(_G.ngx.log).called_with _, '[ngx-oauth] such string, so #nil'
      assert.stub(_G.ngx.say).called_with '{"error":"such string, so #nil"}'


describe 'format_cookie', ->
  setup ->
    _G.pairs = spec_helper.sorted_pairs
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
    _G.ngx = mock {
      var: { cookie_plain: 'meh.', cookie_encod: '%2Fping%3F' }
      unescape_uri: spec_helper.unescape_uri
    }

  context 'existing cookie', ->
    it 'returns cookie value from ngx.var', ->
      assert.same 'meh.', nginx.get_cookie('plain')

    it 'decodes uri-encoded cookie value using ngx.unescape_uri', ->
      assert.same '/ping?', nginx.get_cookie('encod')
      assert.spy(_G.ngx.unescape_uri).called_with '%2Fping%3F'

  context 'non-existing cookie', ->
    it 'returns nil', ->
      assert.is_nil nginx.get_cookie('noop')


describe 'log', ->
  before_each ->
    _G.ngx = mock { ERR: 4, WARN: 5, INFO: 7, log: -> }

  it 'calls ngx.log with given level and message prefixed by [ngx-oauth]', ->
    nginx.log(ngx.WARN, 'allons-y!')
    assert.stub(_G.ngx.log).called_with ngx.WARN, '[ngx-oauth] allons-y!'

  context 'with arguments for format', ->
    it 'calls ngx.log with formatted message', ->
      nginx.log(ngx.INFO, 'such %s, so %s', 'string', 'formatted')
      assert.stub(_G.ngx.log).called_with _, '[ngx-oauth] such string, so formatted'

    context 'where some are nil', ->
      it 'substitutes nil with "#nil"', ->
        nginx.log(ngx.INFO, 'such %s, so %s', 'string', nil)
        assert.stub(_G.ngx.log).called_with _, '[ngx-oauth] such string, so #nil'
