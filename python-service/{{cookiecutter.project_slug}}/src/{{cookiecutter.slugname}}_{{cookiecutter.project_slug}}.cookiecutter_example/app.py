import os

from flask import Flask
import click
from flask.cli import with_appcontext
from werkzeug.middleware.proxy_fix import ProxyFix


def create_app(test_config=None):
    # create and configure the app
    app = Flask(
        __name__,
        instance_path="/var/lib/{{ cookiecutter.slugname }}/{{ cookiecutter.project_slug }}/"
        instance_relative_config=False,
    )

    # Set the defaults
    app.config.from_mapping(SERVER_NAME="{{ cookiecutter.slugname }}.test")

    has_secrets_config_file = os.environ.get("SECRETS_CONFIG") and os.path.exists(
        os.environ.get("SECRETS_CONFIG")
    )

    if test_config is None:
        # Override the defaults with the instance config when not testing
        app.config.from_pyfile("config.py", silent=False)

        if has_secrets_config_file:
            # Follow OpenFaaS philosophy and don't set secrets in environment
            # variables. Read secrets from the file system.
            # The SECRETS_CONFIG is set like this:
            # /run/tmp/chillbox_secrets/$SLUGNAME/$service_handler/$service_secrets_config
            app.config.from_envvar("SECRETS_CONFIG", silent=False)
            if not app.config.get("ANSWER1"):
                raise ValueError(
                    f"No ANSWER1 set in {os.environ.get('SECRETS_CONFIG')}."
                )
            if not app.config.get("ANSWER2"):
                raise ValueError(
                    f"No ANSWER2 set in {os.environ.get('SECRETS_CONFIG')}."
                )
            if not app.config.get("ANSWER5"):
                raise ValueError(
                    f"No ANSWER5 set in {os.environ.get('SECRETS_CONFIG')}."
                )

    else:
        # load the test config if passed in
        app.config.from_mapping(test_config)

    # ensure the instance folder exists
    try:
        os.makedirs(app.instance_path)
    except OSError:
        pass

    app.logger.debug("Adding /healthcheck route")

    @app.route("/healthcheck")
    def healthcheck():
        has_secrets = all(
            [
                app.config.get("ANSWER1"),
                app.config.get("ANSWER2"),
                app.config.get("ANSWER5"),
            ]
        )
        return f"Okay. Secrets: {has_secrets}"

    app.cli.add_command(init_db_command)

    # Only apply this middleware if the app is behind a proxy (nginx), and set
    # the correct number of proxies that set each header. It can be a security
    # issue if you get this configuration wrong.
    # https://flask.palletsprojects.com/en/2.2.x/deploying/proxy_fix/
    app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_prefix=1)

    app.logger.debug("Create app done")
    return app


@click.command("init-db")
@with_appcontext
def init_db_command():
    click.echo("fake init-db command")
