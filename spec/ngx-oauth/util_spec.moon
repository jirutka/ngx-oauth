require 'moon.all'
util = require 'ngx-oauth.util'

describe 'default', ->

  context 'with nil value or empty string', ->
    it 'returns default value', ->
      assert.same 42, util.default(nil, 42)
      assert.same 42, util.default('', 42)

  context 'with non-empty value', ->
    it 'returns value', ->
      assert.same 'hi', util.default('hi', 42)


describe 'merge', ->

  tab1 = {a: 1, b: 2}
  tab2 = {c: 3, d: 4}

  context 'tables with disjoint keys', ->
    it 'returns table with contents of both given tables', ->
      assert.same {a: 1, b: 2, c: 3, d: 4}, util.merge(tab1, tab2)

  context 'tables with non-disjoint keys', ->
    it 'prefers entries from 2nd table for duplicate keys', ->
      assert.same {a: 1, b: 5, c: 3}, util.merge(tab1, {b: 5, c: 3})

  it 'does not modify given tables', ->
    tab1_orig = copy(tab1)
    tab2_orig = copy(tab2)
    util.merge(tab1, tab2)
    assert.same tab1_orig, tab1
    assert.same tab2_orig, tab2


describe 'partial', ->
  func1 = util.partial(string.find, 'yada yada')
  func2 = util.partial(string.gsub, 'yada yada', 'y')

  context 'with 1 + 1 argument', ->
    it 'invokes wrapped function with 2 arguments', ->
      assert.same 1, func1('yada')

  context 'with 1 + 2 arguments', ->
    it 'invokes wrapped function with 3 arguments', ->
      assert.same 6, func1('yada', 4)

  context 'with 2 + 1 argument', ->
    it 'invokes wrapped function with 3 arguments', ->
      assert.same 'Yada Yada', func2('Y')

  context 'with 2 + 2 arguments', ->
    it 'invokes wrapped function with 4 arguments', ->
      assert.same 'Yada yada', func2('Y', 1)


describe 'get_cookie', ->
  setup ->
    _G.ngx = {
      var: { cookie_foo: 'meh.' }
    }

  context 'existing cookie', ->
    it 'returns cookie value from ngx.var', ->
      assert.same 'meh.', util.get_cookie('foo')

  context 'non-existing cookie', ->
    it 'returns nil', ->
      assert.is_nil util.get_cookie('noop')


describe 'format_cookie', ->
  setup ->
    _G.ngx = mock
      escape_uri: (value) -> string.gsub(value, ' ', '+')

  it 'returns correctly formated cookie with attributes', ->
    actual = util.format_cookie('foo', 'meh', {version: 1, path: '/'})
    assert.is_true 'foo=meh;version=1;path=/' == actual or 'foo=meh;path=/;version=1' == actual

  it 'escapes cookie value using ngx.escape_uri', ->
    assert.same 'foo=chunky+bacon', util.format_cookie('foo', 'chunky bacon', {})
    assert.stub(_G.ngx.escape_uri).called_with 'chunky bacon'

  it "omits attribute's value if it's true", ->
    assert.same 'foo=bar;secure', util.format_cookie('foo', 'bar', {secure: true})
