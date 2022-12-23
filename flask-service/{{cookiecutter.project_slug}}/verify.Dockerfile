# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-01-10" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.16.2
# docker image ls --digests alpine
FROM alpine:3.16.2@sha256:bc41182d7ef5ffc53a40b044e725193bc10142a1243f395ee852a8d9730fc2ad

RUN <<DEV_USER
addgroup -g 44444 dev
adduser -u 44444 -G dev -s /bin/sh -D dev
DEV_USER

WORKDIR /home/dev/app

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
mkdir -p /home/dev/app
/usr/bin/python3 -m venv /home/dev/app/.venv
# The dev user will need write access since pip install will be adding files to
# the .venv directory.
chown -R dev:dev /home/dev/app/.venv
PYTHON_VIRTUALENV
# Activate python virtual env by updating the PATH
ENV VIRTUAL_ENV=/home/dev/app/.venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"


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

ARG LOCAL_PYTHON_PACKAGES=/var/lib/chillbox/python
ENV LOCAL_PYTHON_PACKAGES=$LOCAL_PYTHON_PACKAGES

COPY --chown=dev:dev setup.py /home/dev/app/setup.py
COPY --chown=dev:dev README.md /home/dev/app/README.md
# Only the __init__.py is needed when using pip download.
COPY --chown=dev:dev src/{{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}/__init__.py /home/dev/app/src/{{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}/__init__.py

# UPKEEP due: "2023-03-23" label: "Python pip" interval: "+3 months"
# https://pypi.org/project/pip/
ARG PIP_VERSION=22.3.1
# UPKEEP due: "2023-03-23" label: "Python wheel" interval: "+3 months"
# https://pypi.org/project/wheel/
ARG WHEEL_VERSION=0.38.4
RUN <<PIP_INSTALL_REQ
# Download python packages described in setup.py
set -o errexit
mkdir -p "$LOCAL_PYTHON_PACKAGES"
python -m pip download \
    --destination-directory "$LOCAL_PYTHON_PACKAGES" \
    "pip==$PIP_VERSION" \
    "wheel==$WHEEL_VERSION"
python -m pip download --disable-pip-version-check \
    --destination-directory "$LOCAL_PYTHON_PACKAGES" \
    /home/dev/app
PIP_INSTALL_REQ

USER dev

# UPKEEP due: "2023-03-23" label: "pip-tools" interval: "+3 months"
# https://pypi.org/project/pip-tools/
ARG PIP_TOOLS_VERSION=6.12.1
RUN <<PIP_TOOLS_INSTALL
# Install pip-tools
set -o errexit
python -m pip install pip-tools=="$PIP_TOOLS_VERSION"
PIP_TOOLS_INSTALL

RUN <<UPDATE_REQUIREMENTS
# Generate the hashed requirements.txt file that the main container will use.
set -o errexit
pip-compile --generate-hashes \
    --resolver=backtracking \
    --allow-unsafe \
    --no-index --find-links="$LOCAL_PYTHON_PACKAGES" \
    --output-file /home/dev/app/requirements.txt \
    /home/dev/app/setup.py
UPDATE_REQUIREMENTS


# UPKEEP due: "2023-03-23" label: "Python auditing tool pip-audit" interval: "+3 months"
# https://pypi.org/project/pip-audit/
ARG PIP_AUDIT_VERSION=2.4.10
RUN <<AUDIT
# Audit packages for known vulnerabilities
set -o errexit
python -m pip install "pip-audit==$PIP_AUDIT_VERSION"
pip-audit \
    --require-hashes \
    --local \
    --strict \
    --vulnerability-service pypi \
    -r /home/dev/app/requirements.txt
pip-audit \
    --require-hashes \
    --local \
    --strict \
    --vulnerability-service osv \
    -r /home/dev/app/requirements.txt
AUDIT

# UPKEEP due: "2023-06-23" label: "Python security linter tool: bandit" interval: "+6 months"
# https://pypi.org/project/bandit/
ARG BANDIT_VERSION=1.7.4
RUN <<BANDIT_INSTALL
# Install bandit to find common security issues
set -o errexit
python -m pip install "bandit==$BANDIT_VERSION"
BANDIT_INSTALL

COPY --chown=dev:dev src/{{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}/ /home/dev/app/src/{{ cookiecutter.slugname }}_{{ cookiecutter.project_slug }}/
RUN <<BANDIT
# Use bandit to find common security issues
set -o errexit
bandit \
    --recursive \
    /home/dev/app/src/
BANDIT

CMD ["/home/dev/sleep.sh"]
