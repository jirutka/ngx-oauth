from . import *

import os
from os.path import join as pathjoin
import shlex
from subprocess import Popen
import sys
from time import sleep, time

import requests
from requests import ConnectionError
from retry import retry


class NginxServer:

    def __init__(self, nginx_conf, check_url, temp_dir='.'):
        conf_path = pathjoin(temp_dir, 'nginx.conf')
        write_file(conf_path, nginx_conf)

        self._command = "nginx -c %s" % conf_path
        self._ngx_process = None
        self.check_url = check_url

    def start(self):
        self._ngx_process = Popen(shlex.split(self._command))

        try:  # sanity check
            resp = self._request_check_url()
        except ConnectionError as e:
            self.stop()
            raise e

        if resp.status_code != 200:
            raise IOError("Nginx returned %s for GET %s" % (resp.status_code, self.check_url))

    def stop(self):
        if self._ngx_process is None:
            return
        try:
            self._ngx_process.terminate()
            sleep(0.2)
        finally:
            os.kill(self._ngx_process.pid, 9)

    @retry(ConnectionError, tries=20, delay=0.1)
    def _request_check_url(self):
        return requests.get(self.check_url, verify=False)
