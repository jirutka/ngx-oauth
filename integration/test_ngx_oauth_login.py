from .conftest import *

# Note: This tests also the ngx-oauth-redirect-handler.


def test_login_for_the_first_time(http):
    # When I make a GET request to the proxy's login endpoint,
    resp = http.get('/_oauth/login')

    # then the proxy should redirect me to the OAAS' authorization endpoint.
    assert resp.headers['Location'].startswith(proxy_conf['authorization_url'])

    # When I follow the redirect,
    resp = http.get(resp.headers['Location'])

    # then the OAAS should redirect me to the $oauth_redirect_uri
    # and the Location header should contain a query parameter "code" (authorization code).
    # Note: we omit user authentication and request approval here.
    assert resp.headers['Location'].startswith(proxy_conf['redirect_uri'] + '?code=')

    # When I follow the redirect,
    resp = http.get(resp.headers['Location'])

    # then the proxy should redirect me to the $oauth_success_uri
    assert resp.headers['Location'] == proxy_conf['success_uri']

    # and the response should set cookies with aaccess token, refresh token and username.
    assert resp.cookies['oauth_access_token'] == access_tokens[0]
    assert resp.cookies['oauth_username'] == oaas_state['username']
    assert resp.cookies['oauth_refresh_token'] != oaas_state['refresh_token'],\
        'refresh_token should be encrypted'


@mark.oaas_config(access_token=access_tokens[1])
def test_login_again_with_access_and_refresh_token(http):
    # Given all cookies from the previous login.

    # When I make a GET request to the proxy's login endpoint,
    resp = http.get('/_oauth/login')

    # then the proxy should redirect me to the $oauth_success_uri
    assert resp.headers['Location'] == proxy_conf['success_uri']

    # and the response should set cookie with a new access token.
    assert resp.cookies['oauth_access_token'] == access_tokens[1]


@mark.oaas_config(access_token=access_tokens[2])
def test_login_with_valid_refresh_token(http):
    # Given cookies from the previous login, except the access token cookie (it has expired).
    del http.cookies['oauth_access_token']

    # When I make a GET request to the proxy's login endpoint,
    resp = http.get('/_oauth/login')

    # then I should be redirected by the proxy to the $oauth_success_uri
    assert resp.headers['Location'] == proxy_conf['success_uri']

    # and the response should set cookie with a new access token.
    assert resp.cookies['oauth_access_token'] == access_tokens[2]


def test_login_with_invalid_refresh_token(http):
    # Given invalid refresh token cookie.
    del http.cookies['oauth_access_token']
    http.cookies['oauth_refresh_token'] = 'invalid-token'

    # When I make a GET request to the proxy's login endpoint,
    resp = http.get('/_oauth/login')

    # then the proxy should redirect me to the OAAS' authorization endpoint.
    assert resp.headers['Location'].startswith(proxy_conf['authorization_url'])


@mark.oaas_config(approve_request=False)
def test_login_and_deny_authorization(http):
    # When I make a GET request to the proxy's login endpoint,
    resp = http.get('/_oauth/login')

    # then the proxy should redirect me to the OAAS' authorization endpoint.
    assert resp.headers['Location'].startswith(proxy_conf['authorization_url'])

    # When I follow the redirect,
    resp = http.get(resp.headers['Location'])

    # then the OAAS should redirect me to the $oauth_redirect_uri,
    # and the Location header should contain a query parameter "error".
    assert resp.headers['Location'] == proxy_conf['redirect_uri'] + '?error=invalid_scope'

    # When I follow the redirect,
    resp = http.get(resp.headers['Location'])

    # then the response status should be 403.
    assert resp.status_code == 403
