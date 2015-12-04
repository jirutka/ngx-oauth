from .support import *
from .support.oaas_mock import *
from .support.nginx_server import *

import os
from os.path import dirname, join as pathjoin, realpath
from time import sleep
from urllib.parse import urljoin

from pytest import fixture, mark
import requests


DIR = dirname(realpath(__file__))
TEMP_DIR = os.environ.get('TEMP_DIR') or pathjoin(DIR, '../.tmp')

nginx_port = free_tcp_port()
oaas_port = free_tcp_port()
nginx_base_uri = "https://127.0.0.1:%d" % nginx_port
oaas_base_uri = "http://127.0.0.1:%d" % oaas_port

access_tokens = [
    '00f8aadb-78d8-4f6b-aa20-1212dc656b7c',
    '11feaa17-4083-487c-a8f5-3c57b6173dae',
    '22f636da-f340-435e-8038-11145edca174'
]

proxy_conf = {
    'client_id': 'd3a7c1d6-fdeb-4280-ad63-8459849f2b5f',
    'client_secret': 'IetaeFaeni8aif2hee1OomailoiGh8ue',
    'scope': 'read',
    'redirect_uri': "%s/_oauth/callback" % nginx_base_uri,
    'oaas_uri': oaas_base_uri,
    'authorization_url': "%s/authorize" % oaas_base_uri,
    'success_uri': '/success',
}

oaas_state = {
    'access_token': access_tokens[0],
    'refresh_token': '4f22e6c7-f8d6-48b0-8f2e-64f08fe0b5a6',
    'auth_code': 'Moh3uag5',
    'username': 'flynn',
    'approve_request': True
}


@fixture(scope='module', autouse=True)
def nginx(request):
    nginx_conf = render_template(pathjoin(DIR, 'nginx.conf.tmpl'), port=nginx_port, **proxy_conf)

    nginx = NginxServer(nginx_conf, nginx_base_uri, temp_dir=TEMP_DIR)
    nginx.start()
    request.addfinalizer(nginx.stop)


@fixture(scope='function', autouse=True)
def oaas(request):
    marker = request.node.get_marker('oaas_config')
    extra_conf = marker.kwargs if marker else {}
    config = merge_dicts(proxy_conf, oaas_state, extra_conf)

    process = BottleServer(OAuthServerMock(config), port=oaas_port)
    process.start()
    request.addfinalizer(process.terminate)


@fixture(scope='module')
def http():
    class HttpClient(requests.Session):
        def request(self, method, uri, **kwargs):
            url = urljoin(nginx_base_uri, uri)
            defaults = {'allow_redirects': False, 'verify': False}
            return super().request(method, url, **merge_dicts(defaults, kwargs))

        # Original get method sets allow_redirects to True, so we must override it.
        def get(self, url, **kwargs):
            return self.request('GET', url, **kwargs)

    return HttpClient()


@fixture
def logged_in_fixture(http):
    http.post('/_oauth/login', allow_redirects=True)
    assert len(http.cookies) == 3

logged_in = mark.usefixtures('logged_in_fixture')
