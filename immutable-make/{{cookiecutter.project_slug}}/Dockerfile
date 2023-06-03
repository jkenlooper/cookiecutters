# syntax=docker/dockerfile:1.5.2

# {{ cookiecutter.template_file_comment }}
# Version: {{ cookiecutter._version }}

# UPKEEP due: "2023-09-03" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.18.0
# docker image ls --digests alpine
FROM alpine:3.18.0@sha256:02bb6f428431fbc2809c5d1b41eab5a68350194fb508869a33cb1af4444c9b11 as build

WORKDIR /build
ARG LOCAL_CONTAINER=yes
ENV LOCAL_CONTAINER=$LOCAL_CONTAINER

RUN <<DEV_USER
# Create an unprivileged user that will only have access to /build directory.
set -o errexit
addgroup -g 44444 dev
adduser -u 44444 -G dev -s /bin/sh -D dev
chown -R dev:dev /build
DEV_USER

RUN <<INSTALL
set -o errexit
apk update
apk add --no-cache \
  mandoc man-pages docs \
  make

# The .tmp/ directory is for storing intermediate files from other *.mk files.
mkdir -p .tmp

# The dist/ directory will contain the generated files.
mkdir -p dist

chown -R dev:dev /build/dist .tmp
INSTALL

RUN <<FILEWATCH_SUPPORT
# Support for doing local development
set -o errexit
apk update
apk add --no-cache \
  thttpd \
  tree \
  gettext \
  entr
FILEWATCH_SUPPORT

COPY --chown=dev:dev local-scripts/check-in-container.sh /build/local-scripts/check-in-container.sh
COPY --chown=dev:dev local-scripts/dev.sh /build/local-scripts/dev.sh
COPY --chown=dev:dev local-scripts/build-serve.sh /build/local-scripts/build-serve.sh
COPY --chown=dev:dev local-scripts/build.sh /build/local-scripts/build.sh

# The install.sh script can be customized depending on the requirments for the
# build. This will typically install other packages that are needed.
COPY --chown=dev:dev local-scripts/install.sh /build/local-scripts/install.sh
RUN /build/local-scripts/install.sh

COPY --chown=dev:dev *.mk /build/
COPY --chown=dev:dev src /build/src

# Build the dist files inside the container
RUN /build/local-scripts/build.sh

# Need to bind to all addresses (0.0.0.0) as the default when within the site's
# network.
ENV BIND=0.0.0.0
ENV {{ cookiecutter.project_slug_upper }}_PORT={{ cookiecutter.project_port }}

# Default command is to run the dev.sh script to watch files and build and serve
# them.
CMD ["/build/local-scripts/dev.sh"]

### Serve
FROM lipanski/docker-static-website:1.0.0@sha256:ea8516e6b2928c3c1b1c6737f7e32e03b10a04f978080592e61c3dbe2871ff1a

# Try to copy the /build/dist, but fail if the build failed.
COPY --from=build /build/dist /home/static

# Need a Cache-Control:max-age=0 header (thttpd option '-M 0') on all responses.
CMD ["/thttpd", "-D", "-h", "$BIND", "-p", "${{ cookiecutter.project_slug_upper }}_PORT", "-d", "/home/static", "-u", "static", "-l", "-", "-M", "0"]
