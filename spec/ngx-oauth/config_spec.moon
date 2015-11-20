require 'moon.all'
import merge from require 'ngx-oauth.util'
config = require 'ngx-oauth.config'


describe 'load', ->

  required_vars = {
    client_id: 'abc'
    client_secret: 'thoh5eveeth7thohF7nohY7c'
    authorization_url: 'http://oaas.org/authorize'
    token_url: 'http://oaas.org/token'
    userinfo_url: 'http://oaas.org/userinfo'
  }

  before_each ->
    _G.ngx =
      var: { scheme: 'https', server_name: 'example.org' }


  context 'when all variables are set', ->
    expected = merge {
      scope: 'read'
      redirect_uri: 'https://example.cz/oauth/callback'
      server_url: 'not-used'
      redirect_location: '/callback'
      success_uri: '/app/home'
      cookie_path: '/app'
      cookie_prefix: 'oa_'
      max_age: 600
      aes_bits: 192
      debug: true
    }, required_vars

    before_each ->
      for key, val in pairs expected do
        _G.ngx.var['oauth_'..key] = val

    it 'returns settings built from ngx.var.oauth_* variables, and falsy', ->
      actual, errs = config.load()
      assert.same expected, actual
      assert.is_falsy errs


  context 'when only required variables are set', ->
    expected = merge {
      scope: ''
      server_url: ''
      redirect_uri: 'https://example.org/_oauth/callback'
      redirect_location: '/_oauth/callback'
      success_uri: '/'
      cookie_path: '/'
      cookie_prefix: 'oauth_'
      max_age: 2592000
      aes_bits: 128
      debug: false
    }, required_vars

    before_each ->
      for key, val in pairs required_vars do
        _G.ngx.var['oauth_'..key] = val

    it 'returns settings built from ngx.var.oauth_* variables and defaults, and falsy', ->
      actual, errs = config.load()
      assert.same expected, actual
      assert.is_falsy errs


  context 'when ngx.var.oauth_redirect_uri is not set', ->
    before_each ->
      _G.ngx.var =
        scheme: 'http', server_name: 'example.cz', oauth_redirect_location: '/callme'

    it 'sets redirect_uri built from vars scheme, server_name and oauth_redirect_location', ->
      actual = config.load()
      assert.same 'http://example.cz/callme', actual.redirect_uri


  context 'when ngx.var.oauth_server_url is set', ->
    before_each ->
      _G.ngx.var.oauth_server_url = 'http://example.org'

    for key, default_value in pairs {
      token_url: 'token',
      authorization_url: 'authorize',
      userinfo_url: 'userinfo'
    } do
      context "and ngx.var.#{key} is not set", ->
        it "prefixes default #{key} with server_url", ->
          assert.same "http://example.org/#{default_value}", config.load()[key]


  context 'when ngx.var.oauth_server_url is not set', ->

    for varname in *{'authorization_url', 'token_url', 'userinfo_url'} do
      context "and ngx.var.#{varname} is not set", ->
        it 'returns error message as 2nd value', ->
          _, errs = config.load()
          assert.matches "neither $oauth_#{varname} nor $oauth_server_url is set", errs


  for varname in *{'client_id', 'client_secret'} do
    context "when ngx.var.oauth_#{varname} is not set", ->
      it 'returns error message as 2nd value', ->
        _, errs = config.load()
        assert.matches "$oauth_#{varname} is not set", errs


  context 'when ngx.var.oauth_aes_bits is illegal', ->
    before_each ->
      _G.ngx.var.oauth_aes_bits = 666

    it 'returns error message as 2nd value', ->
      _, errs = config.load()
      assert.matches '$oauth_aes_bits must be 128, 192, or 256', errs


  context 'when ngx.var.oauth_client_secret is too short', ->
    before_each ->
      _G.ngx.var.oauth_client_secret = '123'
      _G.ngx.var.oauth_aes_bits = 128

    it 'returns error message as 2nd value', ->
      _, errs = config.load()
      assert.matches ('$oauth_client_secret is too short, it must be at least '..
        '16 characters long for $oauth_aes_bits = 128'), errs
