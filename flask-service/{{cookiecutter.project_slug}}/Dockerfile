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

# UPKEEP due: "2023-03-23" label: "Chillbox cli shared scripts" interval: "+3 months"
# https://github.com/jkenlooper/chillbox
ARG CHILLBOX_CLI_VERSION="0.0.1-beta.30"
RUN <<CHILLBOX_PACKAGES
# Download and extract shared scripts from chillbox.
set -o errexit
# The /etc/chillbox/bin/ directory is a hint that the
# install-chillbox-packages.sh script is the same one that chillbox uses.
mkdir -p /etc/chillbox/bin
tmp_tar_gz="$(mktemp)"
wget -q -O "$tmp_tar_gz" \
  "https://github.com/jkenlooper/chillbox/releases/download/$CHILLBOX_CLI_VERSION/chillbox-cli.tar.gz"
tar x -f "$tmp_tar_gz" -z -C /etc/chillbox/bin --strip-components 4 ./src/chillbox/bin/install-chillbox-packages.sh
chown root:root /etc/chillbox/bin/install-chillbox-packages.sh
rm -f "$tmp_tar_gz"
CHILLBOX_PACKAGES

RUN <<SERVICE_DEPENDENCIES
set -o errexit

apk update
/etc/chillbox/bin/install-chillbox-packages.sh

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

# UPKEEP due: "2023-03-23" label: "Python pip" interval: "+3 months"
# https://pypi.org/project/pip/
ARG PIP_VERSION=22.3.1
# UPKEEP due: "2023-03-23" label: "Python wheel" interval: "+3 months"
# https://pypi.org/project/wheel/
ARG WHEEL_VERSION=0.38.4
RUN <<PIP_INSTALL
# Install pip and wheel
set -o errexit
python -m pip install \
    "pip==$PIP_VERSION" \
    "wheel==$WHEEL_VERSION"
PIP_INSTALL

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

# The dep directory should include the wheels and other source packages
# created from running the verify.sh script.
COPY dep /usr/local/src/app/dep

COPY requirements.txt /usr/local/src/app/requirements.txt
COPY setup.py /usr/local/src/app/setup.py
COPY README.md /usr/local/src/app/README.md
COPY gunicorn.conf.py /usr/local/src/app/gunicorn.conf.py
COPY src /usr/local/src/app/src
RUN <<PIP_INSTALL_APP
# Install app in editable mode and use the local python packages.
set -o errexit

# Only pip install with the local python packages cache.
# This uses the setup.py instead of the requirements.txt since this is for
# development.
pip install --disable-pip-version-check --compile \
    --no-index \
    --find-links /var/lib/chillbox/python \
    gunicorn[gevent,setproctitle]
pip install --disable-pip-version-check --compile \
    --no-index \
    -r /usr/local/src/app/requirements.txt
pip install --disable-pip-version-check --compile \
    --no-index \
    -e /usr/local/src/app
PIP_INSTALL_APP

ENV FLASK_APP={{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}.app
ENV FLASK_DEBUG=false
# Default to 1 worker and set worker-class to sync to match the default in chillbox.
ENV GUNICORN_CMD_ARGS="--workers=1 --worker-class=sync --max-requests=50 --max-requests-jitter=10 --log-level=debug"

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

cat <<'RELOADER_SH' > /usr/local/src/app/reloader.sh
#!/usr/bin/env sh

set -o errexit

# Setting host to 0.0.0.0 (externally visible) to work with docker network.
# The gunicorn command will use gunicorn.conf.py if it is in the same directory
# by default. Setting it explicitly here to help show how it is being used.
# The GUNICORN_CMD_ARGS will also be applied here if they are set. See gunicorn
# documentation on how these configurations are applied.
# https://docs.gunicorn.org/en/stable/settings.html
gunicorn \
    --config ./gunicorn.conf.py \
    --chdir /usr/local/src/app \
    --reload \
    --name {{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}_app \
    --access-logfile - \
    --bind "0.0.0.0:$PORT" \
    "{{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}.app:create_app()"

RELOADER_SH

chmod +x reloader.sh
FILEWATCH_SUPPORT

RUN <<SUPPORT_LOCAL_S3
# Create symbolic link for /home/dev/.aws/credentials
set -o errexit

# This credentials file will be replaced by a mount point.
mkdir -p /var/lib/chillbox-local-shared/chillbox-minio/{{ cookiecutter.slugname }}-local-s3
touch /var/lib/chillbox-local-shared/chillbox-minio/{{ cookiecutter.slugname }}-local-s3/local-chillbox_object_storage-credentials

mkdir -p /home/dev/.aws
ln -s /var/lib/chillbox-local-shared/chillbox-minio/{{ cookiecutter.slugname }}-local-s3/local-chillbox_object_storage-credentials /home/dev/.aws/credentials
chmod 0600 /home/dev/.aws/credentials
chown dev:dev /home/dev/.aws/credentials
SUPPORT_LOCAL_S3

USER dev

CMD ["/usr/local/src/app/reloader.sh"]
