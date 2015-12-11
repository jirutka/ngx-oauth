from base64 import b64decode
from urllib.parse import urlencode

from .util import OAuthError, assert_access_token, get_authorization_header
from bottle import Bottle, ConfigDict, LocalRequest, abort, redirect

__all__ = ['OAuthServerMock']


def OAuthServerMock(config):
    conf = ConfigDict().load_dict(config)
    app = Bottle()
    request = LocalRequest()

    token = {
        'access_token': conf.access_token,
        'token_type': 'bearer',
        'refresh_token': conf.refresh_token,
        'expires_in': 3600,
        'scope': conf.scope
    }

    @app.get('/')
    def get_root():
        abort(200, 'OK')

    @app.get('/authorize')
    def get_authorize():
        query = request.query

        if query.client_id != conf.client_id:
            raise OAuthError(401, 'invalid_client', "Invalid client_id: %s" % query.client_id)

        if query.response_type != 'code':
            raise OAuthError(400, 'unsupported_response_type', "Unsupported response type: %s",
                             query.response_type)

        if query.redirect_uri != conf.redirect_uri:
            raise OAuthError(400, 'invalid_grant', "Invalid redirect %s does not match %s",
                             query.redirect_uri, conf.redirect_uri)

        if conf.get('approve_request', True) and query.scope in conf.scope.split(' '):
            params = {'code': conf.auth_code}
        else:
            params = {'error': 'invalid_scope'}
        if query.state:
            params['state'] = query.state

        redirect(query.redirect_uri + '?' + urlencode(params))

    @app.post('/token')
    def post_token():
        auth = get_authorization_header(request)
        grant_type = request.forms.grant_type

        if parse_client_auth(auth) != (conf.client_id, conf.client_secret):
            raise OAuthError(401, 'unauthorized', 'Bad credentials')

        if grant_type == 'authorization_code':
            return handle_authorization_code()
        elif grant_type == 'refresh_token':
            return handle_refresh_token()
        else:
            raise OAuthError(400, 'invalid_request', 'Missing or invalid grant type')

    def handle_authorization_code():
        code = request.forms.code
        redirect_uri = request.forms.redirect_uri

        if code != conf.auth_code:
            raise OAuthError(400, 'invalid_grant', "Invalid authorization code: %s" % code)

        return token

    def handle_refresh_token():
        refresh_token = request.forms.refresh_token

        if refresh_token != conf.refresh_token:
            raise OAuthError(400, 'invalid_grant', "Invalid refresh token: %s" % refresh_token)

        return token

    @app.get('/userinfo')
    def get_userinfo():
        assert_access_token(request, conf.access_token)

        return {
            'username': conf.username
        }

    @app.error(400)
    @app.error(401)
    def handle_error(error):
        return error.body

    return app


def parse_client_auth(header):
    method, credentials = header.split(' ')
    assert method == 'Basic', 'Expected method Basic'
    return tuple(b64decode(credentials).decode().split(':'))
