from .util import assert_access_token
from bottle import Bottle, ConfigDict, LocalRequest, abort

__all__ = ['ResourceProviderMock']


def ResourceProviderMock(access_token):
    app = Bottle()
    request = LocalRequest()

    @app.get('/')
    def get_root():
        abort(200, 'OK')

    @app.get('/ping')
    def get_ping():
        assert_access_token(request, access_token)
        return {'pong': 'ok'}

    @app.error(400)
    @app.error(401)
    def handle_error(error):
        return error.body

    return app
