# syntax=docker/dockerfile:1.5.2

# {{ cookiecutter.template_file_comment }}

# UPKEEP due: "2023-09-03" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.18.0
# docker image ls --digests alpine
FROM alpine:3.18.0@sha256:02bb6f428431fbc2809c5d1b41eab5a68350194fb508869a33cb1af4444c9b11

RUN <<DEV_USER
addgroup -g 44444 dev
adduser -u 44444 -G dev -s /bin/sh -D dev
DEV_USER

WORKDIR /home/dev/app

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
mkdir -p /home/dev/app
chown -R dev:dev /home/dev/app
su dev -c '/usr/bin/python3 -m venv /home/dev/app/.venv'
PYTHON_VIRTUALENV
# Activate python virtual env by updating the PATH
ENV VIRTUAL_ENV=/home/dev/app/.venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY --chown=dev:dev pip-requirements.txt /home/dev/app/pip-requirements.txt
COPY --chown=dev:dev pyproject.toml /home/dev/app/pyproject.toml
COPY --chown=dev:dev dep /home/dev/app/dep
COPY --chown=dev:dev README.md /home/dev/app/README.md
RUN <<PIP_DOWNLOAD
# Download python packages listed in pyproject.toml
set -o errexit
# Install these first so packages like PyYAML don't have errors with 'bdist_wheel'
python -m pip install wheel
python -m pip install pip
python -m pip install hatchling
python -m pip download --disable-pip-version-check \
    --exists-action i \
    --no-build-isolation \
    --find-links /home/dev/app/dep/ \
    --destination-directory /home/dev/app/dep \
    -r /home/dev/app/pip-requirements.txt
python -m pip download --disable-pip-version-check \
    --exists-action i \
    --no-build-isolation \
    --find-links /home/dev/app/dep/ \
    --destination-directory /home/dev/app/dep \
    .[dev,test]
PIP_DOWNLOAD

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

RUN <<PIP_INSTALL
# Install pip-requirements.txt
set -o errexit
# Install these first so packages like PyYAML don't have errors with 'bdist_wheel'
python -m pip install wheel
python -m pip install pip
python -m pip install hatchling
python -m pip install \
  --no-index \
  --no-build-isolation \
  --find-links /home/dev/app/dep/ \
  -r /home/dev/app/pip-requirements.txt
PIP_INSTALL

COPY --chown=dev:dev requirements.txt /home/dev/app/requirements.txt
COPY --chown=dev:dev requirements-dev.txt /home/dev/app/requirements-dev.txt
COPY --chown=dev:dev requirements-test.txt /home/dev/app/requirements-test.txt
COPY --chown=dev:dev pyproject.toml /home/dev/app/pyproject.toml
COPY --chown=dev:dev README.md /home/dev/app/README.md
RUN <<PIP_INSTALL_APP
# Install the local python packages.
set -o errexit

# Only pip install with the local python packages cache.
python -m pip install --disable-pip-version-check --compile \
  --no-index \
  --no-build-isolation \
  -r /home/dev/app/requirements.txt
python -m pip install --disable-pip-version-check --compile \
  --no-index \
  --no-build-isolation \
  -r /home/dev/app/requirements-dev.txt
python -m pip install --disable-pip-version-check --compile \
  --no-index \
  --no-build-isolation \
  -r /home/dev/app/requirements-test.txt
PIP_INSTALL_APP

COPY --chown=dev:dev src /home/dev/app/src
RUN <<PIP_INSTALL_SRC
# Install app source code in editable mode (-e) for local development.
set -o errexit
python -m pip install --disable-pip-version-check --compile \
  --no-index \
  --no-build-isolation \
  -e /home/dev/app
PIP_INSTALL_SRC

ENV SECRETS_CONFIG=""

# For development the app is installed in 'edit' mode. This requires that the
# script start this way. This value is typically overridden via local.site.json.
ARG RUN_DEV_CMD="python /home/dev/app/src/{{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}/script.py"

RUN <<FILEWATCH_SUPPORT
# Create scripts for file watching.
set -o errexit
cat <<'SLEEP_SH' > /home/dev/app/sleep.sh
#!/usr/bin/env sh
set -o errexit

echo "Sleeping."
while true; do
  printf "."
  sleep 60
done
SLEEP_SH
chmod +x sleep.sh

cat <<DEV_RUN_CMD_SH > /home/dev/app/dev-run-cmd.sh
#!/usr/bin/env sh

set -o errexit

# Override any existing VIRTUAL_ENV_BIN here when running this locally.
export VIRTUAL_ENV_BIN="${VIRTUAL_ENV}/bin"

$RUN_DEV_CMD

DEV_RUN_CMD_SH
chmod +x /home/dev/app/dev-run-cmd.sh

cat <<'RELOADER_SH' > /home/dev/app/reloader.sh
#!/usr/bin/env sh

set -o errexit

tmp_watch_files="$(mktemp)"
cleanup() {
  rm -f "$tmp_watch_files"
}
trap cleanup EXIT INT HUP TERM

watch_files() {
  find "/home/dev/app/src/{{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}" > "$tmp_watch_files"
  cat "$tmp_watch_files" | entr -rdn /home/dev/app/dev-run-cmd.sh
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


CMD ["/home/dev/app/reloader.sh"]
