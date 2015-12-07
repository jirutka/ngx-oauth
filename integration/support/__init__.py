from socket import socket
from string import Template

from bottle import HTTPError


class OAuthError(HTTPError):

    def __init__(self, status, error_code, error_desc):
        super().__init__(status=status, body={
            'error': error_code,
            'error_description': error_desc
        })


def free_tcp_port():
    sock = socket()
    try:
        sock.bind(('', 0))
        return sock.getsockname()[1]
    finally:
        sock.close()


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
