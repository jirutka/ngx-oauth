from .conftest import *
from urllib.parse import quote_plus as url_quote


def test_with_invalid_refresh_token(http):
    del http.cookies['oauth_access_token']
    http.cookies['oauth_refresh_token'] = 'invalid-token'

    # When I make a request to the secured page,
    resp = http.get('/secured/page.txt')

    # then the proxy should redirect me to the OAAS' authorization endpoint.
    assert resp.headers['Location'].startswith(proxy_conf['authorization_url'])


def test_with_unknown_access_token_and_no_refresh_token(http):
    http.cookies['oauth_access_token'] = '0a1e3021-8c69-44a9-a136-0768a0aeb2ad'
    del http.cookies['oauth_refresh_token']

    # When I make a request to the secured page,
    resp = http.get('/secured/page.txt')

    # then the proxy should redirect me to the OAAS' authorization endpoint.
    assert resp.headers['Location'].startswith(proxy_conf['authorization_url'])


def test_login_for_the_first_time(http):
    requested_uri = '/secured/page.txt'

    # When I make a request to the secured page,
    resp = http.get(requested_uri)

    # then the proxy should redirect me to the OAAS' authorization endpoint.
    assert resp.headers['Location'].startswith(proxy_conf['authorization_url'])

    # and the response should set cookie with the original requested URI.
    assert resp.cookies['oauth_original_uri'] == url_quote(requested_uri)

    # When I follow the redirect,
    resp = http.get(resp.headers['Location'])

    # then the OAAS should redirect me to the $oauth_redirect_uri
    # and the Location header should contain a query parameter "code" (authorization code).
    # Note: we omit user authentication and request approval here.
    assert resp.headers['Location'].startswith(proxy_conf['redirect_uri'] + '?code=')

    # When I follow the redirect,
    resp = http.get(resp.headers['Location'])

    # then the proxy should redirect me to the original requested URI
    assert resp.headers['Location'] == requested_uri

    # and the response should set cookies with aaccess token, refresh token and username.
    assert resp.cookies['oauth_access_token'] == access_tokens[0]
    assert resp.cookies['oauth_username'] == oaas_state['username']
    assert resp.cookies['oauth_refresh_token'] != oaas_state['refresh_token'],\
        'refresh_token should be encrypted'

    # When I follow the redirect,
    resp = http.get(resp.headers['Location'])

    # then I should get the requested page.
    assert resp.status_code == 200
    assert resp.text == 'Lorem ipsum\n'


@logged_in
def test_with_valid_access_token(http):
    # Given I'm logged in and all cookies are set.

    # When I make a request to the secured page,
    resp = http.get('/secured/page.txt')

    # then I should get the requested page.
    assert resp.status_code == 200
    assert resp.text == 'Lorem ipsum\n'


@mark.oaas_config(access_token=access_tokens[1])
def test_refresh_token(http):
    # Given valid refresh token cookie, but no access token cookie (it has expired).
    del http.cookies['oauth_access_token']

    # When I make a request to the secured page,
    resp = http.get('/secured/page.txt')

    # then I should get the requested page,
    assert resp.status_code == 200
    assert resp.text == 'Lorem ipsum\n'

    # and the response should set cookie with a new access token.
    assert http.cookies['oauth_access_token'] == access_tokens[1]
