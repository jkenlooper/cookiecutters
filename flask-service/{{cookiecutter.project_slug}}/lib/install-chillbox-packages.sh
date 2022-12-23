#!/usr/bin/env sh

set -o errexit

# This script is isolated so other applications that are being developed locally
# in a container can install the same package dependencies as the chillbox
# server. See the referenced file in https://github.com/jkenlooper/cookiecutters

script_name="$(basename "$0")"

# Support python services and python Pillow
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

# Support for python flask with gunicorn and gevent
apk add --no-cache \
  -q --no-progress \
  py3-gunicorn
