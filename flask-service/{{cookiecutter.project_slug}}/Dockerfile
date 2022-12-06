# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-01-10" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.16.2
# docker image ls --digests alpine
FROM alpine:3.16.2@sha256:bc41182d7ef5ffc53a40b044e725193bc10142a1243f395ee852a8d9730fc2ad as build

## Build dependencies
WORKDIR /usr/local/src/app-venv
COPY requirements.txt ./
RUN <<BUILD_DEPENDENCIES
set -o errexit
apk update
apk add --no-cache \
  gcc \
  python3 \
  python3-dev \
  libffi-dev \
  build-base \
  musl-dev

ln -s /usr/bin/python3 /usr/bin/python
python -m venv .
/usr/local/src/app-venv/bin/pip install --upgrade pip wheel
/usr/local/src/app-venv/bin/pip install --disable-pip-version-check --compile -r requirements.txt
apk --purge del \
  gcc \
  python3-dev \
  libffi-dev \
  build-base \
  musl-dev
BUILD_DEPENDENCIES

WORKDIR /usr/local/src/app
#TODO need to copy all of it here?
COPY . ./
RUN <<PIP_INSTALL_APP
set -o errexit
/usr/local/src/app-venv/bin/pip install --disable-pip-version-check --compile .
export PATH=/usr/local/src/app-venv/bin/:$PATH
PIP_INSTALL_APP

## Stage 2

# UPKEEP due: "2023-01-10" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.16.2
# docker image ls --digests alpine
FROM alpine:3.16.2@sha256:bc41182d7ef5ffc53a40b044e725193bc10142a1243f395ee852a8d9730fc2ad

RUN <<DEV_USER
addgroup -g 44444 dev
adduser -u 44444 -G dev -s /bin/sh -D dev
DEV_USER

WORKDIR /usr/local/src/
COPY --from=build --chown=dev /usr/local/src/app-venv /usr/local/src/app-venv
COPY --from=build --chown=dev /usr/local/src/app /usr/local/src/app

ENV PATH=/usr/local/src/app-venv/bin/:$PATH

ARG FLASK_INSTANCE_PATH=/var/lib/{{ cookiecutter.slugname }}/
ENV FLASK_INSTANCE_PATH=$FLASK_INSTANCE_PATH

RUN <<APP_DEPENDENCIES
set -o errexit
apk update
# Support python services and python Pillow
# Should match the list from chillbox install-service-dependencies.sh
apk add --no-cache \
  -q --no-progress \
  build-base \
  freetype \
  freetype-dev \
  fribidi \
  fribidi-dev \
  gcc \
  harfbuzz \
  harfbuzz-dev \
  jpeg \
  jpeg-dev \
  lcms2 \
  lcms2-dev \
  libffi-dev \
  libjpeg \
  musl-dev \
  openjpeg \
  openjpeg-dev \
  py3-pip \
  python3 \
  python3-dev \
  sqlite \
  tcl \
  tcl-dev \
  tiff \
  tiff-dev \
  tk \
  tk-dev \
  zlib \
  zlib-dev

ln -s /usr/bin/python3 /usr/bin/python

mkdir -p $FLASK_INSTANCE_PATH
chown -R dev:dev $FLASK_INSTANCE_PATH

mkdir -p /usr/local/src/app
chown -R dev:dev /usr/local/src/app

APP_DEPENDENCIES

ENV FLASK_APP={{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}.app
ENV FLASK_ENV=production

# TODO set secrets for local
ENV SECRETS_CONFIG="/var/lib/chillbox-shared-secrets/{{ cookiecutter.slugname }}/{{ cookiecutter.project_slug }}.cfg"

ENV {{ cookiecutter.project_slug_upper }}_PORT=8100

ENV SERVER_NAME="localhost"

WORKDIR /usr/local/src/app/

RUN <<FILEWATCH_SUPPORT

cat <<'FLASK_RUN_SH' > flask-run.sh
#!/usr/bin/env sh

set -o errexit

current_user="$(id -un)"
echo "current user = $current_user or $USER"
if [ "${current_user}" != "root" ]; then
  echo "ERROR: Must run $0 as the 'root' user because this uses bind mount of the src/{{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}/ directory."
  exit 1
fi

# pip install in editable mode
/usr/local/src/app-venv/bin/pip install --disable-pip-version-check -e .

export FLASK_ENV=development

/usr/local/src/app-venv/bin/flask init-db

# Setting host to 0.0.0.0 (externally visible) to work with docker network.
/usr/local/src/app-venv/bin/flask run \
  --port "${{ cookiecutter.project_slug_upper }}_PORT" \
  --host "0.0.0.0"

# /usr/local/src/app-venv/bin/pytest

# /usr/local/src/app-venv/bin/coverage run -m pytest

# /usr/local/src/app-venv/bin/coverage report

FLASK_RUN_SH

chmod +x flask-run.sh
FILEWATCH_SUPPORT

USER dev

CMD ["/usr/local/src/app-venv/bin/start"]
