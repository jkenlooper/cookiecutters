# syntax=docker/dockerfile:1.4.3

# {{ cookiecutter.template_file_comment }}

# UPKEEP due: "2023-04-21" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.17.1
# docker image ls --digests alpine
FROM alpine:3.17.1@sha256:f271e74b17ced29b915d351685fd4644785c6d1559dd1f2d4189a5e851ef753a

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
# TODO
# tar x -f "$tmp_tar_gz" -z -C /etc/chillbox --strip-components 3 ./src/chillbox/pip-requirements.txt
chown root:root /etc/chillbox/bin/install-chillbox-packages.sh
rm -f "$tmp_tar_gz"
CHILLBOX_PACKAGES

RUN <<SERVICE_DEPENDENCIES
set -o errexit

apk update
/etc/chillbox/bin/install-chillbox-packages.sh

SERVICE_DEPENDENCIES

RUN  <<PYTHON_VIRTUALENV
# Setup for python virtual env
set -o errexit
mkdir -p /usr/local/src/app
chown -R dev:dev /usr/local/src/app
su dev -c '/usr/bin/python3 -m venv /usr/local/src/app/.venv'
PYTHON_VIRTUALENV
# Activate python virtual env by updating the PATH
ENV VIRTUAL_ENV=/usr/local/src/app/.venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# TODO
COPY --chown=dev:dev pip-requirements.txt /etc/chillbox/pip-requirements.txt

RUN <<PIP_INSTALL
# Install pip and wheel
set -o errexit
su dev -c "python -m pip install -r /etc/chillbox/pip-requirements.txt"
PIP_INSTALL

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

RUN <<FILEWATCH_SUPPORT
# Support for doing local development
set -o errexit
apk update
apk add --no-cache \
  entr
FILEWATCH_SUPPORT

USER dev

# The dep directory should include the wheels and other source packages
# created from running the verify.sh script.
COPY --chown=dev:dev dep /usr/local/src/app/dep

COPY --chown=dev:dev requirements.txt /usr/local/src/app/requirements.txt
COPY --chown=dev:dev requirements-dev.txt /usr/local/src/app/requirements-dev.txt
COPY --chown=dev:dev requirements-test.txt /usr/local/src/app/requirements-test.txt
COPY --chown=dev:dev pyproject.toml /usr/local/src/app/pyproject.toml
COPY --chown=dev:dev README.md /usr/local/src/app/README.md
RUN <<PIP_INSTALL_APP
# Install app in editable mode and use the local python packages.
set -o errexit
set -x

# Only pip install with the local python packages cache.
python -m pip install --disable-pip-version-check --compile \
  --no-index \
  --no-build-isolation \
  -r /usr/local/src/app/requirements.txt
python -m pip install --disable-pip-version-check --compile \
  --no-index \
  --no-build-isolation \
  -r /usr/local/src/app/requirements-dev.txt
python -m pip install --disable-pip-version-check --compile \
  --no-index \
  --no-build-isolation \
  -r /usr/local/src/app/requirements-test.txt
# Install app source code in editable mode (-e) for local development.
python -m pip install --disable-pip-version-check --compile \
  --no-index \
  --no-build-isolation \
  -e /usr/local/src/app
PIP_INSTALL_APP

COPY --chown=dev:dev src /usr/local/src/app/src

ENV SECRETS_CONFIG=""

ENV API_PORT=8100

ENV SERVER_NAME="localhost"

# For development the app is installed in 'edit' mode. This requires that the
# script start this way. This value is typically overridden via local.site.json.
ARG RUN_DEV_CMD="python /usr/local/src/app/src/{{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}/script.py"

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

cat <<DEV_RUN_CMD_SH > /usr/local/src/app/dev-run-cmd.sh
#!/usr/bin/env sh

set -o errexit

# VIRTUAL_ENV_BIN can be used by gunicorn.conf.py when running commands like
# 'flask' and others that are part of the Python virtual environment.
# Override any existing VIRTUAL_ENV_BIN here when running this locally.
export VIRTUAL_ENV_BIN="${VIRTUAL_ENV}/bin"

$RUN_DEV_CMD

DEV_RUN_CMD_SH
chmod +x /usr/local/src/app/dev-run-cmd.sh

cat <<'RELOADER_SH' > /usr/local/src/app/reloader.sh
#!/usr/bin/env sh

set -o errexit

tmp_watch_files="$(mktemp)"
cleanup() {
  rm -f "$tmp_watch_files"
}
trap cleanup EXIT INT HUP TERM

watch_files() {
  find "/usr/local/src/app/src/{{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}" > "$tmp_watch_files"
  cat "$tmp_watch_files" | entr -rdn /usr/local/src/app/dev-run-cmd.sh
}

while true; do
  set +o errexit
  watch_files
  exit_wf="$?"
  set -o errexit
  if [ "$exit_wf" = "0" ]; then
    echo "INFO $script_name: Exiting."
    exit "$exit_wf"
  elif [ "$exit_wf" = "1" ] || [ "$exit_wf" = "2" ]; then
    echo "INFO $script_name: waiting 2 seconds before watching files again. Hit Ctrl-C to exit."
    sleep 2
  else
    echo "INFO $script_name: Unhandled entr exit status."
    exit "$exit_wf"
  fi
done

RELOADER_SH

chmod +x reloader.sh
FILEWATCH_SUPPORT


CMD ["/usr/local/src/app/reloader.sh"]
