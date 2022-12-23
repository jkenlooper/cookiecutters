# syntax=docker/dockerfile:1.4.3

# {{ cookiecutter.template_file_comment }}

# UPKEEP due: "2023-01-10" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.16.2
# docker image ls --digests alpine
FROM alpine:3.16.2@sha256:bc41182d7ef5ffc53a40b044e725193bc10142a1243f395ee852a8d9730fc2ad

RUN <<DEV_USER
addgroup -g 44444 dev
adduser -u 44444 -G dev -s /bin/sh -D dev
DEV_USER

WORKDIR /usr/local/src/app/

COPY lib/install-chillbox-packages.sh /home/dev/install-chillbox-packages.sh
RUN <<SERVICE_DEPENDENCIES
set -o errexit

apk update
"/home/dev/install-chillbox-packages.sh"

ln -s /usr/bin/python3 /usr/bin/python
SERVICE_DEPENDENCIES

RUN  <<PYTHON_VIRTUALENV
# Setup for python virtual env
set -o errexit
mkdir -p /usr/local/src/app
/usr/bin/python3 -m venv /usr/local/src/app/.venv
# The dev user will need write access since pip install will be adding files to
# the .venv directory.
chown -R dev:dev /usr/local/src/app/.venv
PYTHON_VIRTUALENV
# Activate python virtual env by updating the PATH
ENV VIRTUAL_ENV=/usr/local/src/app/.venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

ARG FLASK_INSTANCE_PATH=/var/lib/{{ cookiecutter.slugname }}/
ENV FLASK_INSTANCE_PATH=$FLASK_INSTANCE_PATH
RUN <<FLASK_SETUP
set -o errexit
mkdir -p /usr/local/src/app
mkdir -p $FLASK_INSTANCE_PATH
chown -R dev:dev $FLASK_INSTANCE_PATH

mkdir -p /usr/local/src/app
chown -R dev:dev /usr/local/src/app
FLASK_SETUP

ARG LOCAL_PYTHON_PACKAGES=/var/lib/chillbox/python
ENV LOCAL_PYTHON_PACKAGES=$LOCAL_PYTHON_PACKAGES

# The dist/python directory should include the wheels and other source packages
# created from running the verify.sh script.
COPY dist/python $LOCAL_PYTHON_PACKAGES

COPY setup.py /usr/local/src/app/setup.py
COPY README.md /usr/local/src/app/README.md
COPY src /usr/local/src/app/src
RUN <<PIP_INSTALL_APP
# Install app in editable mode and use the local python packages.
set -o errexit

# Only pip install with the local python packages cache.
# This uses the setup.py instead of the requirements.txt since this is for
# development.
pip install --disable-pip-version-check --compile \
    --no-index --find-links="$LOCAL_PYTHON_PACKAGES" \
    -e /usr/local/src/app
PIP_INSTALL_APP

ENV FLASK_APP={{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}.app
ENV FLASK_DEBUG=false

ENV SECRETS_CONFIG=""

ENV API_PORT=8100

ENV SERVER_NAME="localhost"


RUN <<FILEWATCH_SUPPORT
# Create scripts for file watching.
set -o errexit
cat <<'SLEEP_SH' > /usr/local/src/app/sleep.sh
#!/usr/bin/env sh
set -o errexit

echo "Sleeping."
while true; do
  printf "."
  sleep 60
done
SLEEP_SH
chmod +x sleep.sh

cat <<'FLASK_RUN_SH' > /usr/local/src/app/flask-run.sh
#!/usr/bin/env sh

set -o errexit

flask init-db

# Setting host to 0.0.0.0 (externally visible) to work with docker network.
gunicorn \
    --reload \
    --name {{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}_app \
    --workers 2 \
    --worker-class gevent \
    --max-requests 50 \
    --max-requests-jitter 10 \
    --log-level debug \
    --bind "0.0.0.0:$API_PORT" \
    "{{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}.app:create_app()"

FLASK_RUN_SH

chmod +x flask-run.sh
FILEWATCH_SUPPORT

USER dev

CMD ["/usr/local/src/app/flask-run.sh"]
