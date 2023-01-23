# syntax=docker/dockerfile:1.4.3

# {{ cookiecutter.template_file_comment }}
# Version: {{ cookiecutter._version }}

# UPKEEP due: "2023-04-21" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.17.1
# docker image ls --digests alpine
FROM alpine:3.17.1@sha256:f271e74b17ced29b915d351685fd4644785c6d1559dd1f2d4189a5e851ef753a

WORKDIR /build

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
  make \
  imagemagick

# The .tmp/ directory is for storing intermediate files from other *.mk files.
mkdir -p .tmp

# The media/ directory will contain the generated files.
mkdir -p media

chown -R dev:dev /build/media .tmp
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

COPY --chown=dev:dev local-scripts/dev.sh /build/dev.sh
COPY --chown=dev:dev local-scripts/build-serve.sh /build/build-serve.sh
COPY --chown=dev:dev local-scripts/build.sh /build/build.sh

COPY --chown=dev:dev src ./src

ENV BUILD_SRC_DIR=/build/src
ENV BUILD_MEDIA_DIR=/build/media

USER dev

# Build the media files inside the container
RUN ./build.sh

# Need to bind to all addresses (0.0.0.0) as the default when within the site's
# network.
ENV BIND=0.0.0.0
ENV SOURCE_MEDIA_PORT={{ cookiecutter.project_port }}

# Default command is to run the dev.sh script to watch files and build and serve
# them.
CMD ["./dev.sh"]

### Serve
FROM lipanski/docker-static-website:1.0.0@sha256:ea8516e6b2928c3c1b1c6737f7e32e03b10a04f978080592e61c3dbe2871ff1a

# Try to copy the /build/media, but fail if the build failed.
COPY --from=build /build/media /home/static

# Need a Cache-Control:max-age=0 header (thttpd option '-M 0') on all responses.
CMD ["/thttpd", "-D", "-h", "$BIND", "-p", "$SOURCE_MEDIA_PORT", "-d", "/home/static", "-u", "static", "-l", "-", "-M", "0"]
