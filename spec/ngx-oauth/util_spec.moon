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


describe 'concat', ->
  tab1 = {2, 6, 8}
  tab2 = {1, 7}
  tab3 = {3, 8}

  it 'returns concatenation of the given tables', ->
    assert.same {2, 6, 8, 1, 7, 3, 8}, util.concat(tab1, tab2, tab3)

  it 'does not modify given tables', ->
    tab1_orig = copy(tab1)
    tab2_orig = copy(tab2)

    util.concat(tab1, tab2)
    assert.same tab1_orig, tab1
    assert.same tab2_orig, tab2


describe 'is_blank', ->

  it 'returns true for nil', ->
    assert.is_true util.is_blank(nil)

  it 'returns true for empty string', ->
    assert.is_true util.is_blank('')

  it 'returns true for string with whitespaces only', ->
    for value in *{'  ', '\t\t', '\t'} do
      assert.is_true util.is_blank(value)

  it 'returns false for string with any non-whitespace char', ->
    for value in *{'foo', ' foo ', '\tfoo'} do
      assert.is_false util.is_blank(value)

  it 'returns false for other types than nil and string', ->
    for value in *{42, true, false, {}, util.is_blank}
      assert.is_false util.is_blank(value)


describe 'map', ->

  context 'with 1-argument func', ->
    it 'applies the func over each key-value pair, calls it with value', ->
      assert.same {a: 2, b: 4}, util.map ((v) -> v * 2), {a: 1, b: 2}

  context 'with 2-arguments func', ->
    it 'applies the func over each key-value pair, calls it with value and key', ->
      assert.same {a: 'a1', b: 'b2'}, util.map ((v, k) -> k..v), {a: 1, b: 2}

  it 'does not modify given table', ->
    tab = {a: 1, b: 2, c: 3}
    tab_orig = copy(tab)
    util.map ((v) -> v *2), tab
    assert.same tab_orig, tab


describe 'imap', ->

  context 'with 1-argument func', ->
    it 'applies the func over each item, calls it with value', ->
      assert.same {4, 8, 12}, util.imap(((v) -> v * 2), {2, 4, 6})

  context 'with 2-arguments func', ->
    it 'applies the func over each item, calls it with value and index', ->
      assert.same {'a1', 'b2', 'c3'}, util.imap ((v, i) -> v..i), {'a', 'b', 'c'}

  it 'does not modify given table', ->
    tab = {1, 2, 3}
    tab_orig = copy(tab)
    util.map ((v) -> v *2), tab
    assert.same tab_orig, tab


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
    actual = util.format_cookie('foo', 'meh', version: 1, path: '/')
    assert.is_true 'foo=meh;version=1;path=/' == actual or 'foo=meh;path=/;version=1' == actual

  it 'escapes cookie value using ngx.escape_uri', ->
    assert.same 'foo=chunky+bacon', util.format_cookie('foo', 'chunky bacon', {})
    assert.stub(_G.ngx.escape_uri).called_with 'chunky bacon'

  it "omits attribute's value if it's true", ->
    assert.same 'foo=bar;secure', util.format_cookie('foo', 'bar', secure: true)

  it 'replaces underscore in attribute name with a dash', ->
    assert.same 'foo=bar;max-age=60', util.format_cookie('foo', 'bar', max_age: 60)
