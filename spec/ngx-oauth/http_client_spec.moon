require 'moon.all'
import _ from require 'luassert.match'
import merge, mtype from require 'ngx-oauth.util'
import Left, Right from require 'ngx-oauth.either'

HTTP_INST = '<fake-http-instance>'

http_stub = {}
url = 'https://example.org'
accept_json_header = { Accept: 'application/json' }

-- Trick Lua to require our fake table instead of resty.http module
-- into http_client.
setup ->
  package.loaded['resty.http'] = http_stub
  export client = require 'ngx-oauth.http_client'

-- Unload fake resty.http.
teardown ->
  package.loaded['resty.http'] = nil

before_each ->
  export response = {
    status: 200,
    headers: {}
    body: '{ "msg": "hi!" }'
  }
  http_stub.new = mock -> HTTP_INST
  http_stub.request_uri = mock (self, uri, params) ->
    assert.same HTTP_INST, self
    response


describe 'request', ->

  context 'when http.new succeed', ->
    params = {
      method: 'POST'
      body: '<body>'
      headers: accept_json_header
      ssl_verify: true
    }

    it 'calls http.request_uri with correct arguments', ->
      http_stub.request_uri = (self, actual_uri, actual_params) ->
        assert.same HTTP_INST, self
        assert.same url, actual_uri
        assert.same params, actual_params
        response

      client.request(params.method, params.headers, url, params.body)

    context 'when http.request_uri succeed', ->

      it 'returns Right with response', ->
        resp = client.request(params.method, params.headers, url, params.body)
        assert.equal Right(response), resp

    context 'when http.request_uri failed', ->
      before_each ->
        http_stub.request_uri = (self, uri, params) ->
          assert.same HTTP_INST, self
          nil, 'request failed!'

      it 'returns Left with error message', ->
        resp = client.request('POST', {}, url, 'body')
        assert.equal Left('request failed!'), resp

  context 'when http.new failed', ->
    resp = nil

    before_each ->
      http_stub.new = -> nil, 'new failed!'
      resp = client.request('POST', {}, url, 'body')

    it 'does not call http.request_uri', ->
      assert.stub(http_stub.request_uri).was_not_called!

    it 'returns Left with error message', ->
      assert.equal Left('new failed!'), resp


-- Shared contexts for request_json and derived functions.
contexts_json_response = (exec_request) ->
  context 'when response status is 200 and body is valid JSON', ->

    it 'returns Right with parsed JSON body', ->
      body = exec_request!

      assert.same { msg: 'hi!' }, body.value
      assert.same 'Right', mtype(body)

  context 'when response status is not 200', ->

    it 'returns Left with error message', ->
      response.status = 404
      body = exec_request!
      assert.equal Left('HTTP 404: { "msg": "hi!" }'), body

  context 'when failed to parse JSON', ->

    it 'returns Left with error message', ->
      response.body = '{ 666 }'
      body = exec_request!

      assert.matches 'Expected object key string.*', body.value
      assert.same 'Left', mtype(body)


describe 'request_json', ->

  headers = { Cookie: 'foo=42;path=/' }
  request_json = -> client.request_json('PUT', headers, url, '<body>')

  setup -> spy.on(client, 'request')
  teardown -> client.request\revert!

  it 'calls request() with given method, url and body', ->
    request_json!
    assert.spy(client.request).called_with('PUT', _, url, '<body>')

  it 'calls request() with given headers plus Accept header', ->
    expected_headers = merge(headers, accept_json_header)
    request_json!
    assert.spy(client.request).called_with(_, expected_headers, _, _)

  contexts_json_response -> request_json!


describe 'get_for_json', ->

  setup -> spy.on(client, 'request')
  teardown -> client.request\revert!

  it 'calls request() with GET method, given url and no body', ->
    client.get_for_json(url)
    assert.spy(client.request).called_with('GET', _, url, nil)

  context 'without bearer_token', ->

    it 'calls request() with Accept header application/json', ->
      client.get_for_json(url)
      assert.spy(client.request).called_with(_, accept_json_header, _, _)

  context 'with bearer_token', ->

    it 'calls request() with Accept header and token in Authorization header', ->
      token = '8e7e1f47-8992-42e8-a3bb-b7b6526bca71'
      headers = merge(accept_json_header, { Authorization: 'Bearer '..token })

      client.get_for_json(url, token)
      assert.spy(client.request).called_with(_, headers, _, _)

  contexts_json_response -> client.get_for_json(url)


describe 'post_form_for_json', ->

  headers = { Cookie: 'foo=42;path=/' }
  body = {colour: '#004b7e'}
  post_form_for_json = -> client.post_form_for_json(headers, url, body)

  setup ->
    spy.on(client, 'request')

  teardown ->
    client.request\revert!

  it 'calls request() with method "POST"', ->
    post_form_for_json!
    assert.spy(client.request).called_with('POST', _, _, _)

  it 'calls request() with given headers plus Accept and ContentType', ->
    expected_headers = merge {
      ['Content-Type']: 'application/x-www-form-urlencoded',
      ['Accept']: 'application/json'
    }, headers

    post_form_for_json!
    assert.spy(client.request).called_with(_, expected_headers, _, _)

  it 'calls request() with given url', ->
    post_form_for_json!
    assert.spy(client.request).called_with(_, _, url, _)

  it 'calls request() with body encoded using ngx.encode_args', ->
    post_form_for_json!
    assert.stub(_G.ngx.encode_args).called_with body
    assert.spy(client.request).called_with(_, _, _, 'colour=%23004b7e')

  contexts_json_response -> post_form_for_json!
