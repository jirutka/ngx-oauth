from .conftest import *


@logged_in
def test_logout(http):
    # Given I'm logged in and all cookies are set.

    # When I make a POST request to the proxy's logout endpoint,
    resp = http.post('/_oauth/logout')

    # then the response status should be 204,
    assert resp.status_code == 204

    # and all OAuth cookies should be gone.
    assert len(http.cookies) == 0


@logged_in
def test_logout_using_get_method(http):
    # Given I'm logged in and all cookies are set.

    # When I make a GET request to the proxy's logout endpoint,
    resp = http.get('/_oauth/logout')

    # then the response status should be 405,
    assert resp.status_code == 405

    # and cookies should be still here.
    assert len(http.cookies) == 3
