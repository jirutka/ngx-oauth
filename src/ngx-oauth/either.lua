---------
-- The Either monad.
--
-- The Either type represents values with two possibilities: a value of type
-- `Either a b` is either a Left, whose value is of type `a`, or a Right, whose
-- value is of type `b`. The `Either` itself is not needed in this
-- implementation, so you find only `Left` and `Right` here.
--
-- This implementation (hopefully) satisfies [Monad](https://github.com/fantasyland/fantasy-land#monad)
-- specification from the Fantasy Land Specification, except the `of` method.
-- Instead of `Left.of(a)` and `Right.of(a)`, use `Left(a)` and `Right(a)`.

local util = require 'ngx-oauth.util'

local contains = util.contains
local mtype    = util.mtype


local function either_eq (op1, op2)
  return mtype(op1) == mtype(op2) and op1.value == op2.value
end

local function Either (ttype, value)
  return setmetatable({
    value = value
  }, {
    -- __eq must be a non-anonymous function, to have the same identity for each
    -- instance of Either, otherwise it doesn't work on Lua 5.1 and LuaJIT 2.0.
    __eq = either_eq,
    __tostring = function(a)
      return ttype..'('..a.value..')'
    end,
    __type = ttype
  })
end

--- Returns a `Left` with the given `value`.
-- @param value The value of any type to wrap.
-- @treturn Left
local function Left (value)
  local self = Either('Left', value)

  --- Returns self.
  -- @function Left.ap
  -- @treturn Left self
  self.ap = function() return self end

  --- Returns self.
  -- @function Left.map
  -- @treturn Left self
  self.map = function() return self end

  --- Returns self.
  -- @function Left.chain
  -- @treturn Left self
  self.chain = function() return self end

  return self
end

--- Returns a `Right` with the given `value`.
-- @param value The value of any type to wrap.
-- @treturn Right
local function Right (value)
  local self = Either('Right', value)

  --- Returns a `Right` whose value is the result of applying self's value to
  -- the given Right's value, if it's `Right`; otherwise returns the given `Left`.
  --
  -- @function Right.map
  -- @tparam Left|Right either
  -- @treturn any
  -- @raise Error if self's value is not a function or if _either_ is not
  --   `Left`, nor `Right`.
  self.ap = function(either)
    assert(mtype(value) == 'function',
      'Could not apply this value to given Either; this value is not a function')
    assert(contains(mtype(either), {'Right', 'Left'}), 'Expected Left or Right')

    return either.map(value)
  end

  --- Returns a `Right` whose value is the result of applying the `func` to
  -- this Right's value.
  --
  -- @function Right.map
  -- @tparam function func
  -- @treturn Right
  self.map = function(func)
    return Right(func(value))
  end

  --- Returns the result of applying the given function to self's value.
  --
  -- @function Right.chain
  -- @tparam function func
  -- @treturn any
  self.chain = function(func)
    return func(value)
  end

  return self
end

--- Returns the result of applying the `on_left` function to the Left's value,
-- if the `teither` is a `Left`, or the result of applying the `on_right`
-- function to the Right's value, if the `teither` is a `Right`.
--
-- @tparam function on_left The Left's handler.
-- @tparam function on_right The Right's handler.
-- @tparam Left|Right teither
-- @raise Error when `teither` is not `Left`, nor `Right`.
local function either (on_left, on_right, teither)
  if mtype(teither) == 'Left' then
    return on_left(teither.value)

  elseif mtype(teither) == 'Right' then
    return on_right(teither.value)

  else
    return error 'Expected Left or Right as 3rd argument'
  end
end

--- Adapts the given function, that may throw an error, to return *either*
-- `Left` with the error message, or `Right` with the result.
--
-- @tparam function func The function to adapt.
-- @treturn function An adapted `func` that accepts the same arguments as
--   `func`, but returns `Left` on an error and `Right` on a success.
local function encase (func)
  return function(...)
    local ok, val = pcall(func, ...)
    return ok and Right(val) or Left(val)
  end
end

--- Adapts the given function, that returns `nil,err` on failure and `res,nil`
-- on success, to return *either* `Left` with `err`, or `Right` with `res`.
--
-- @tparam function func The function to adapt.
-- @treturn function An adapted `func` that accepts the same arguments as
--   `func`, but returns `Left` on an error and `Right` on a success.
local function encase2 (func)
  return function(...)
    local res, err = func(...)
    return err and Left(err) or Right(res)
  end
end

--- @export
return {
  Left = Left,
  Right = Right,
  either = either,
  encase = encase,
  encase2 = encase2
}
