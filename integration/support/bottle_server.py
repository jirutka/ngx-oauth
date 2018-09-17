from multiprocessing import Process

from .util import free_tcp_port
import requests
from requests import ConnectionError
from retry import retry

__all__ = ['BottleServer']


class BottleServer(Process):

    def __init__(self, bottle_app, port=free_tcp_port(), server='waitress',
                 check_url=None, bottle_opts={}):
        opts = dict(port=port, server=server, **bottle_opts)

        super().__init__(target=bottle_app.run, kwargs=opts, daemon=True)
        self._check_url = check_url or "http://%s:%d" % (opts.get('host', 'localhost'), port)

    def start(self):
        super().start()

        try:  # sanity check
            self._request_check_url()
        except ConnectionError as e:
            self.terminate()
            raise e

    @retry(ConnectionError, tries=20, delay=0.1)
    def _request_check_url(self):
        return requests.get(self._check_url)
