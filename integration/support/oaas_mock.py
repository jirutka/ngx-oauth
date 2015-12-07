from base64 import b64decode
from urllib.parse import urlencode

from bottle import Bottle, ConfigDict, HTTPError, LocalRequest, abort, redirect

__all__ = ['OAuthServerMock']


def OAuthServerMock(config):
    conf = ConfigDict().load_dict(config)
    app = Bottle()
    request = LocalRequest()

    @app.get('/')
    def get_root():
        abort(200, 'OK')

    @app.get('/authorize')
    def get_authorize():
        query = request.query

        if query.client_id != conf.client_id:
            raise OAASError(401, 'invalid_client', "Invalid client_id: %s" % query.client_id)

        if query.response_type != 'code':
            raise OAASError(400, 'unsupported_response_type', "Unsupported response type: %s",
                            query.response_type)

        if query.redirect_uri != conf.redirect_uri:
            raise OAASError(400, 'invalid_grant', "Invalid redirect %s does not match %s",
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
            raise OAASError(401, 'unauthorized', 'Bad credentials')

        if grant_type == 'authorization_code':
            return handle_authorization_code()
        elif grant_type == 'refresh_token':
            return handle_refresh_token()
        else:
            raise OAASError(400, 'invalid_request', 'Missing or invalid grant type')

    def handle_authorization_code():
        code = request.forms.code
        redirect_uri = request.forms.redirect_uri

        if code != conf.auth_code:
            raise OAASError(400, 'invalid_grant', "Invalid authorization code: %s" % code)

        return {
            'access_token': conf.access_token,
            'token_type': 'bearer',
            'refresh_token': conf.refresh_token,
            'expires_in': 3600,
            'scope': conf.scope
        }

    def handle_refresh_token():
        refresh_token = request.forms.refresh_token

        if refresh_token != conf.refresh_token:
            raise OAASError(400, 'invalid_grant', "Invalid refresh token: %s" % refresh_token)

        return {
            'access_token': conf.access_token,
            'token_type': 'bearer',
            'expires_in': 3600,
            'scope': conf.scope
        }

    @app.get('/userinfo')
    def get_userinfo():
        auth = get_authorization_header(request)
        token = parse_token_auth(auth)

        if token != conf.access_token:
            raise OAASError(401, 'invalid_token', "Invalid access token: %s" % token)

        return {
            'username': conf.username
        }

    @app.error(400)
    @app.error(401)
    def handle_error(error):
        return error.body

    return app


class OAASError(HTTPError):

    def __init__(self, status, error_code, error_desc):
        super().__init__(status=status, body={
            'error': error_code,
            'error_description': error_desc
        })


def parse_client_auth(header):
    method, credentials = header.split(' ')
    assert method == 'Basic', 'Expected method Basic'
    return tuple(b64decode(credentials).decode().split(':'))


def parse_token_auth(header):
    method, token = header.split(' ')
    assert method == 'Bearer'
    return token


def get_authorization_header(request):
    auth = request.headers.get('Authorization')
    if auth:
        return auth
    raise OAASError(401, 'unauthorized',
                    'Full authentication is required to access this resource')
