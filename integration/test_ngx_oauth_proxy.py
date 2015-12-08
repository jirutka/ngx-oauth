from .conftest import *


def test_without_access_and_refresh_tokens(http, rp):
    # Given I'm not logged in, i.e. no cookies are set.

    # When I make a request to the resource provider through the proxy,
    resp = http.get('/_proxy/ping')

    # then the response status should be 401.
    assert resp.status_code == 401


@logged_in
def test_with_access_token(http, rp):
    # Given I'm logged in and all cookies are set.

    # When I make a request to the resource provider through the proxy,
    resp = http.get('/_proxy/ping')

    # then I should get response from the resource provider.
    assert resp.status_code == 200
    assert resp.json()['pong'] == 'ok'


def test_refresh_token(http, rp):
    # Given valid refresh token cookie, but no access token cookie (it has expired).
    del http.cookies['oauth_access_token']

    # When I make a request to the resource provider through the proxy,
    resp = http.get('/_proxy/ping')

    # then I should get response from the resource provider.
    assert resp.status_code == 200
    assert resp.json()['pong'] == 'ok'

    # and the response should set cookie with a new access token.
    assert http.cookies['oauth_access_token'] == access_tokens[0]
