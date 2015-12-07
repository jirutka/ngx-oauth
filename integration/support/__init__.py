from socket import socket
from string import Template

from bottle import HTTPError


class OAuthError(HTTPError):

    def __init__(self, status, error_code, error_desc):
        super().__init__(status=status, body={
            'error': error_code,
            'error_description': error_desc
        })


def assert_access_token(request, access_token):
    header = get_authorization_header(request)
    method, token = header.split(' ')

    if method != 'Bearer':
        raise OAuthError(400, 'invalid_request', "Invalid authorization method: %s" % method)

    if token != access_token:
        raise OAuthError(401, 'invalid_token', "Invalid access token: %s" % token)


def free_tcp_port():
    sock = socket()
    try:
        sock.bind(('', 0))
        return sock.getsockname()[1]
    finally:
        sock.close()


def get_authorization_header(request):
    auth = request.headers.get('Authorization')
    if auth:
        return auth
    raise OAuthError(401, 'unauthorized',
                     'Full authentication is required to access this resource')


def merge_dicts(*dicts):
    result = {}
    for d in dicts:
        result.update(d)
    return result


def render_template(tmpl_path, **kwargs):
    with open(tmpl_path, 'r') as f:
        return Template(f.read()).substitute(**kwargs)


def write_file(filepath, content):
    with open(filepath, 'w') as f:
        f.write(content)
