require 'moon.all'
import mtype from require 'ngx-oauth.util'
import Left, Right, either, encase, encase2 from require 'ngx-oauth.either'


shared_either = (ttype) ->
  other = ttype == Right and Left or Right

  describe 'metatable.__eq', ->
    context 'same Either types with same value', ->
      it 'returns true', -> assert.is_true ttype(42) == ttype(42)

    context 'same Either types with different value', ->
      it 'returns false', -> assert.is_false ttype(42) == ttype(66)

    context 'different Either types with same value', ->
      it 'returns false', -> assert.is_false ttype(42) == other(42)

    context 'Either with non-Either', ->
      it 'returns false', -> assert.is_false ttype(66) == 66


describe 'Left', ->
  left = Left(66)

  for func_name in *{'ap', 'map', 'chain'} do
    describe func_name, ->
      it 'returns self', ->
        assert.equal left, left[func_name](Right(42))

  describe 'metatable.__type', ->
    it 'is Left', -> getmetatable(left).__type

  shared_either Left


describe 'Right', ->
  right = Right(42)

  describe 'ap', ->
    fright = Right((x) -> x * 2)

    context 'given Right', ->
      it "returns Right which value is result of applying this Right's value to given Right's value", ->
        given = Right(42)
        result = fright.ap(given)
        assert.equal Right(84), result

    context 'given Left', ->
      it 'returns given Left', ->
        given = Left(66)
        assert.equal given, fright.ap(given)

    context 'neither Left, nor Right', ->
      it 'throws error', ->
        assert.has_error -> fright.ap(66)

    context 'when this value is not a function', ->
      it 'throws error', ->
        assert.has_error -> right.ap(Left(66))

  describe 'map', ->
    it "returns Right which value is result of applying given function to this Right's value", ->
      result = right.map((x) -> x * 2)
      assert.equal Right(84), result

  describe 'chain', ->
    it "returns result of applying given function to this Right's value", ->
      assert.same 84, right.chain((x) -> x * 2)

  describe 'metatable.__type', ->
    it 'is Right', -> getmetatable(right).__type

  shared_either Right


describe 'either', ->

  before_each ->
    export onleft = mock(->)
    export onright = mock(->)

  context 'given Left', ->
    it "calls onleft handler with Left's value", ->
      either(onleft, onright, Left(66))
      assert.stub(onleft).called_with(66)
      assert.stub(onright).not_called()

  context 'given Right', ->
    it "calls onright handler with Right's value", ->
      either(onleft, onright, Right(42))
      assert.stub(onleft).not_called()
      assert.stub(onright).called_with(42)

  context 'given neither Left, nor Right', ->
    it 'throws error and does not call any handler', ->
      assert.has_error -> either(->, ->, {})
      assert.stub(onleft).not_called()
      assert.stub(onright).not_called()


shared_encase = (encase_func) ->
  it 'returns a function that wraps the given func and passes its arguments to it', ->
    func = mock(->)
    func2 = encase_func(func)
    assert.is_function func2
    func2(1, 2, 3)
    assert.stub(func).called_with(1, 2, 3)


describe 'encase', ->

  shared_encase encase

  context 'when given func has not raised error', ->
    it "nested function returns Right with the func's return value", ->
      result = encase(-> 'hai!')()
      assert.equal Right('hai!'), result

  context 'when given func has raised error', ->
    it 'nested function returns Left with an error message', ->
      result = encase(table.insert)()
      assert.same 'Left', mtype(result)
      assert.match 'bad argument.*', result.value


describe 'encase2', ->

  shared_encase encase2

  context 'when given func returned non-nil value', ->
    func = -> 'OK!', nil

    it "nested function returns Right with the func's 1st result value", ->
      result = encase2(func)()
      assert.equal Right('OK!'), result

  context 'when func returns nil and a value', ->
    func = -> nil, 'FAIL!'

    it "nested function returns Left with the func's 2nd result value", ->
      result = encase2(func)()
      assert.equal Left('FAIL!'), result
