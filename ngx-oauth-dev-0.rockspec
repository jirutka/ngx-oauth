-- vim: set ft=lua:

package = 'ngx-oauth'
version = 'dev-0'

source = {
  url = 'git://github.com/jirutka/ngx-oauth.git',
  branch = 'master'
}

description = {
  summary = 'OAuth 2.0 proxy for nginx',
  homepage = 'https://github.com/jirutka/ngx-oauth',
  maintainer = 'Jakub Jirutka <jakub@jirutka.cz>',
  license = 'MIT'
}

dependencies = {
  'lua >= 5.1',
  'lua-cjson ~> 2',  -- or luajson
  'lua-resty-http ~> 0.06',
  'luaossl'
}

build = {
  type = 'builtin',
  modules = {
    ['ngx-oauth.config']      = 'src/ngx-oauth/config.lua',
    ['ngx-oauth.Cookies']     = 'src/ngx-oauth/Cookies.lua',
    ['ngx-oauth.crypto']      = 'src/ngx-oauth/crypto.lua',
    ['ngx-oauth.either']      = 'src/ngx-oauth/either.lua',
    ['ngx-oauth.http_client'] = 'src/ngx-oauth/http_client.lua',
    ['ngx-oauth.nginx']       = 'src/ngx-oauth/nginx.lua',
    ['ngx-oauth.oauth2']      = 'src/ngx-oauth/oauth2.lua',
    ['ngx-oauth.util']        = 'src/ngx-oauth/util.lua'
  },
  install = {
    lua = {
      'src/ngx-oauth-login.lua',
      'src/ngx-oauth-logout.lua',
      'src/ngx-oauth-proxy.lua',
      'src/ngx-oauth-redirect-handler.lua'
    }
  },
  copy_directories = { 'spec' }
}
