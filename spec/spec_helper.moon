luassert = require 'luassert'
say = require 'say'

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
