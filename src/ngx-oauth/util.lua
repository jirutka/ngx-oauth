---------
-- General utility functions.

-- unpack is not global since Lua 5.3
local unpack = table.unpack or unpack


--- Calls the function `func` with the given arguments. This is equivalent to:
--
--     func(unpack(args), ...)
--
-- but in a form that can be highly optimized by LuaJIT (~20x faster) when
-- called with less than 4 arguments in the `args` table. If `#args > 3`, then
-- it fallbacks to `unpack` (that is not JIT-compiled in LuaJIT 2.0).
local function call (func, args, ...)
  local n = #args

  if n == 1 then
    return func(args[1], ...)
  elseif n == 2 then
    return func(args[1], args[2], ...)
  elseif n == 3 then
    return func(args[1], args[2], args[3], ...)
  else
    return func(unpack(args), ...)
  end
end

local M = {}

--- Returns a new table with items concatenated from the given tables.
-- Tables are iterated using @{ipairs}, so this function is intended for tables
-- that represent *indexed arrays*.
--
-- @tparam {table,...} ... The tables to concatenate.
-- @treturn table A new table.
-- @see merge
function M.concat (...)
  local result = {}

  for _, tab in ipairs {...} do
    for _, val in ipairs(tab) do
      table.insert(result, val)
    end
  end

  return result
end

--- Returns true if the table `tab` contains the specified `item`; otherwise
-- returns false.
--
-- @param item The item to search.
-- @tparam table tab The table to test.
-- @treturn bool Whether the `tab` contains the `item`.
function M.contains (item, tab)
  for _, val in pairs(tab) do
    if val == item then
      return true
    end
  end
  return false
end

--- Returns the `value` if not nil or empty, otherwise returns the
-- `default_value`.
function M.default (value, default_value)
  if M.is_empty(value) then
    return default_value
  end
  return value
end

--- Returns the given value. That's it, this is an identity function.
function M.id (value)
  return value
end

--- Returns true if the `value` is nil or empty string.
-- @treturn bool
function M.is_empty (value)
  return value == nil or value == ''
end

--- Returns a new table with the results of running `func(value, key)` once
-- for every key-value pair in the `tab`. Tables are iterated using @{pairs},
-- so this function is intended for tables that represent *associative arrays*.
--
-- @tparam function func The function that accepts at least one argument and
--   returns a value.
-- @tparam table tab The table to map over.
-- @treturn table A new table.
-- @see imap
function M.map (func, tab)
  local result = {}
  for key, val in pairs(tab) do
    result[key] = func(val, key)
  end
  return result
end

--- Returns a new table with the results of running `func(value, index)` once
-- for every item in the `tab`. Tables are iterated using @{ipairs}, so this
-- function is intended for tables that represent *indexed arrays*.
--
-- @tparam function func The function that accepts at least one argument and
--   returns a value.
-- @tparam table tab The table to map over.
-- @treturn table A new table.
-- @see map
function M.imap (func, tab)
  local result = {}
  for i, val in ipairs(tab) do
    table.insert(result, func(val, i))
  end
  return result
end

--- Returns a new table containing the contents of all the given tables.
-- Tables are iterated using @{pairs}, so this function is intended for tables
-- that represent *associative arrays*. Entries with duplicate keys are
-- overwritten with the values from a later table.
--
-- @tparam {table,...} ... The tables to merge.
-- @treturn table A new table.
-- @see concat
function M.merge (...)
  local result = {}

  for _, tab in ipairs {...} do
    for key, val in pairs(tab) do
      result[key] = val
    end
  end

  return result
end

--- Returns type of the given value. If `value` has a metatable with key
-- `__type`, then returns its value; otherwise returns Lua's raw type.
--
-- @param value
-- @treturn string A type of the `value`.
function M.mtype (value)
  local meta = getmetatable(value)

  if meta and meta.__type then
    return meta.__type
  else
    return type(value)
  end
end

--- Partial application.
-- Takes a function `func` and arguments, and returns a function *func2*.
-- When applied, *func2* returns the result of applying `func` to the arguments
-- provided initially followed by the arguments provided to *func2*.
--
-- @param func
-- @param ... Arguments to pass to the `func`.
-- @treturn func A partially applied function.
function M.partial (func, ...)
  local args1 = {...}

  return function(...)
    return call(func, args1, ...)
  end
end

--- Performs left-to-right function composition.
--
-- @tparam {function,...} ... The functions to compose; as multiple arguments,
--   or in a single table.
-- @treturn function A composition of the given functions.
function M.pipe (...)
  local funcs = {...}

  if #funcs == 1 and type(funcs[1]) == 'table' then
    funcs = funcs[1]
  end

  local n = #funcs
  local function pipe_inner (i, ...)
    if i == n then
      return funcs[i](...)
    end
    return pipe_inner(i + 1, funcs[i](...))
  end

  return function(...)
    return pipe_inner(1, ...)
  end
end

--- Returns true if the string `str` starts with the `prefix`.
--
-- @tparam prefix string
-- @tparam str string
-- @treturn bool
function M.starts_with (prefix, str)
  return string.sub(str or '', 1, prefix:len()) == prefix
end

--- Returns the result of calling `when_false` with the `value` if `pred`
-- function returns falsy for the `value`; otherwise returns the `value` as is.
--
-- @tparam function pred The predicate function.
-- @tparam function when_false The function to invoke when the `pred` evaluates
--   to a falsy value.
-- @param value The value to test with the `pred` function and pass to the
--   `when_false` if necessary.
-- @return The `value`, or the result of applying `value` to `when_false`.
function M.unless (pred, when_false, value)
  if pred(value) then
    return value
  end
  return when_false(value)
end

return M
