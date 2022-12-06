from gevent import monkey

# Need to monkey patch all before importing other modules. Use 'noqa: E402' to
# ignore flake8 on these.
monkey.patch_all()

from {{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}.app import create_app  # noqa: E402


def main():
    ""
    from gevent import pywsgi, signal_handler
    import signal

    app = create_app()

    # Default to only serving on localhost. Note that if developing locally with
    # a docker container that the host should be set to '0.0.0.0'.
    app.logger.debug(app.config)
    host = app.config.get("HOST", "localhost")
    port = int(str(app.config.get("PORT", 5000)))

    app.logger.info(u"pywsgi.WSGIServer is serving on {host}:{port}".format(**locals()))
    server = pywsgi.WSGIServer((host, port), app)

    def shutdown():
        app.logger.info("shutdown")

        server.stop(timeout=10)

        exit(signal.SIGTERM)

    signal_handler(signal.SIGTERM, shutdown)
    signal_handler(signal.SIGINT, shutdown)
    server.serve_forever(stop_timeout=10)
