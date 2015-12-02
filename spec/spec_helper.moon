luassert = require 'luassert'
ngx_mock = require 'ngx_mock'
say      = require 'say'

_G.ngx = ngx_mock!

-- Assertions

contains = (state, args) ->
  {expected, table} = args
  for value in *table do
    return true if value == expected
  return false

say\set_namespace 'en'
say\set 'assertion.contains.positive', 'Expected item %s in:\n%s'
say\set 'assertion.contains.negative', 'Expected item %s to not be in:\n%s'

luassert\register 'assertion', 'contains', contains,
  'assertion.contains.positive', 'assertion.contains.negative'

-- Helpers

orig_pairs = pairs

sorted_pairs = (tab) ->
  keys = [ k for k, _ in orig_pairs tab ]

  table.sort keys, (a, b) ->
    return a < b if type(a) == type(b)
    tostring(a) < tostring(b)

  i = 0
  return ->
    i += 1
    key = keys[i]
    key, tab[key] if key


export spec_helper = {
  :sorted_pairs
  :ngx_mock
}
