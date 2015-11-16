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

local function istype (ttype, value)
  return type(value) == 'table' and value._type == ttype
end

local either_meta = {
  __eq = function(a, b)
    return a._type == b._type and a.value == b.value
  end
}

--- Returns a `Left` with the given `value`.
-- @param value The value of any type to wrap.
-- @treturn Left
local function Left (value)
  local self = {
    _type  = Left,
    value = value,
  }

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

  return setmetatable(self, either_meta)
end

--- Returns a `Right` with the given `value`.
-- @param value The value of any type to wrap.
-- @treturn Right
local function Right (value)
  local self = {
    _type = Right,
    value = value
  }

  --- Returns a `Right` whose value is the result of applying self's value to
  -- the given Right's value, if it's `Right`; otherwise returns the given `Left`.
  --
  -- @function Right.map
  -- @tparam Left|Right either
  -- @treturn any
  -- @raise Error if self's value is not a function or if _either_ is not
  --   `Left`, nor `Right`.
  self.ap = function(either)
    assert(type(value) == 'function',
      'Could not apply this value to given Either; this value is not a function')
    assert(istype(Right, either) or istype(Left, either),
      'Expected Left or Right')
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

  return setmetatable(self, either_meta)
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
  if istype(Left, teither) then
    return on_left(teither.value)

  elseif istype(Right, teither) then
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
