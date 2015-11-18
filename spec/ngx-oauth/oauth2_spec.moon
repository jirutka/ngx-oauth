require 'moon.all'
import to_base64 from require 'basexx'
import Right from require 'ngx-oauth.either'

conf = {
  client_id: 'client123'
  client_secret: 'top-secret'
  redirect_uri: 'http://example.org'
  scope: 'email'
  token_url: 'https://oaas.org/token'
  authorization_url: 'https://oaas.org/authorize'
}
authorization_header = 'Basic '..to_base64(conf.client_id..':'..conf.client_secret)

http_client_stub = { post_form_for_json: -> }


setup ->
  _G.ngx = { encode_args: spec_helper.url_encode, encode_base64: to_base64 }
  -- Trick Lua to require our fake http_client instead of ngx-oauth.http_client module.
  package.loaded['ngx-oauth.http_client'] = http_client_stub
  export oauth = require 'ngx-oauth.oauth2'

teardown ->
  -- Unload fake ngx-oauth.http_client.
  package.loaded['ngx-oauth.http_client'] = nil


describe 'authorization_url', ->
  expected = 'https://oaas.org/authorize?client_id=client123&redirect_uri='..
    'http%3A%2F%2Fexample%2Eorg&response_type=code&scope=email&state=xyz'

  it 'returns encoded authorization url with correct query parameters', ->
    actual = oauth.authorization_url(conf, 'xyz')
    assert.same expected, actual


describe 'request_token', ->

  expected_data = {}
  response_body = Right('ok!')

  before_each ->
    http_client_stub.post_form_for_json = (headers, url, form_data) ->
      assert.same { Authorization: authorization_header }, headers
      assert.same conf.token_url, url
      assert.same expected_data, form_data
      response_body

  context 'with grant_type authorization_code', ->
    auth_code = 'xyz'
    expected_data =
      grant_type: 'authorization_code'
      code: auth_code
      redirect_uri: conf.redirect_uri

    it 'calls http_client.post_form_for_json with correct arguments and returns result', ->
      assert.equal response_body, oauth.request_token('authorization_code', conf, auth_code)

  context 'with grant_type refresh_token', ->
    refresh_token = 'token123'
    expected_data =
      grant_type: 'refresh_token',
      refresh_token: refresh_token

    it 'calls http_client.post_form_for_json with correct arguments and returns result', ->
      assert.equal response_body, oauth.request_token('refresh_token', conf, refresh_token)

  context 'with grant_type client_credentials', ->
    expected_data =
      grant_type: 'client_credentials',
      scope: conf.scope

    it 'calls http_client.post_form_for_json with correct arguments and returns result', ->
      assert.equal response_body, oauth.request_token('client_credentials', conf)

  context 'with invalid grant_type', ->
    it 'throws error', ->
      assert.has_error -> oauth.request_token('implicit', conf)
