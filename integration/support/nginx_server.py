from . import *

import os
from os.path import join as pathjoin
import shlex
from subprocess import Popen
import sys
from time import sleep, time

import requests
from requests import ConnectionError


class NginxServer:

    def __init__(self, nginx_conf, check_url, temp_dir='.'):
        conf_path = pathjoin(temp_dir, 'nginx.conf')
        write_file(conf_path, nginx_conf)

        self._command = "nginx -c %s" % conf_path
        self._ngx_process = None
        self.check_url = check_url

    def start(self):
        self._ngx_process = Popen(shlex.split(self._command))

        # sanity check
        start = time()
        resp = None
        while time() - start < 2:
            try:
                resp = requests.get(self.check_url, verify=False)
                break
            except ConnectionError:
                sleep(0.1)

        if resp is None or resp.status_code != 200:
            self.stop()
            if resp is None:
                raise IOError('Failed to start Nginx')
            else:
                raise IOError("Nginx failed with: %s" % resp)

    def stop(self):
        if self._ngx_process is None:
            return
        try:
            self._ngx_process.terminate()
            sleep(0.2)
        finally:
            os.kill(self._ngx_process.pid, 9)
