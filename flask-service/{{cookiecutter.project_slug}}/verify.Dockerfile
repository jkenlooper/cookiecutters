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
mkdir -p /home/dev/app
/usr/bin/python3 -m venv /home/dev/app/.venv
# The dev user will need write access since pip install will be adding files to
# the .venv directory.
chown -R dev:dev /home/dev/app/.venv
PYTHON_VIRTUALENV
# Activate python virtual env by updating the PATH
ENV VIRTUAL_ENV=/home/dev/app/.venv
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

# UPKEEP due: "2023-03-23" label: "pip-tools" interval: "+3 months"
# https://pypi.org/project/pip-tools/
ARG PIP_TOOLS_VERSION=6.12.1
RUN <<PIP_TOOLS_INSTALL
# Install pip-tools
set -o errexit
python -m pip install pip-tools=="$PIP_TOOLS_VERSION"
PIP_TOOLS_INSTALL

# UPKEEP due: "2023-03-23" label: "Python auditing tool pip-audit" interval: "+3 months"
# https://pypi.org/project/pip-audit/
ARG PIP_AUDIT_VERSION=2.4.10
RUN <<INSTALL_PIP_AUDIT
# Audit packages for known vulnerabilities
set -o errexit
python -m pip install "pip-audit==$PIP_AUDIT_VERSION"
INSTALL_PIP_AUDIT

# UPKEEP due: "2023-06-23" label: "Python security linter tool: bandit" interval: "+6 months"
# https://pypi.org/project/bandit/
ARG BANDIT_VERSION=1.7.4
RUN <<BANDIT_INSTALL
# Install bandit to find common security issues
set -o errexit
python -m pip install "bandit==$BANDIT_VERSION"
BANDIT_INSTALL

RUN <<SETUP
set -o errexit
cat <<'HERE' > /home/dev/sleep.sh
#!/usr/bin/env sh
while true; do
  printf 'z'
  sleep 60
done
HERE
chmod +x /home/dev/sleep.sh

chown -R dev:dev /home/dev/app
SETUP

COPY --chown=dev:dev setup.py /home/dev/app/setup.py
COPY --chown=dev:dev README.md /home/dev/app/README.md
COPY --chown=dev:dev dep /home/dev/app/dep
# Only the __init__.py is needed when using pip download.
COPY --chown=dev:dev src/{{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}/__init__.py /home/dev/app/src/{{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}/__init__.py

RUN <<PIP_INSTALL_REQ
# Download python packages described in setup.py
set -o errexit
mkdir -p "/home/dev/app/dep"
# Change to the app directory so the find-links can be relative.
cd /home/dev/app
python -m pip download --disable-pip-version-check \
    --exists-action i \
    --destination-directory "./dep" \
    .
PIP_INSTALL_REQ

USER dev

RUN <<UPDATE_REQUIREMENTS
# Generate the hashed requirements.txt file that the main container will use.
set -o errexit
# Change to the app directory so the find-links can be relative.
cd /home/dev/app
pip-compile --generate-hashes \
    --resolver=backtracking \
    --allow-unsafe \
    --no-index --find-links="./dep" \
    --output-file ./requirements.txt \
    ./setup.py
UPDATE_REQUIREMENTS

RUN <<AUDIT
# Audit packages for known vulnerabilities
set -o errexit
# Change to the app directory so the find-links can be relative.
cd /home/dev/app
pip-audit \
    --require-hashes \
    --local \
    --strict \
    --vulnerability-service pypi \
    -r ./requirements.txt
pip-audit \
    --require-hashes \
    --local \
    --strict \
    --vulnerability-service osv \
    -r ./requirements.txt
AUDIT

COPY --chown=dev:dev src/{{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}/ /home/dev/app/src/{{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}/
RUN <<BANDIT
# Use bandit to find common security issues
set -o errexit
bandit \
    --recursive \
    /home/dev/app/src/
BANDIT

CMD ["/home/dev/sleep.sh"]
