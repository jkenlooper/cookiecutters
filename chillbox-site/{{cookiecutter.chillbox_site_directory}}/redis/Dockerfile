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
RUN <<DEPENDENCIES
# Install dependencies
set -o errexit
apk update
apk add --no-cache \
  -q --no-progress \
  sed attr grep coreutils jq

apk add --no-cache \
  -q --no-progress \
  build-base

# Add other tools that are helpful when troubleshooting.
apk add --no-cache \
  -q --no-progress \
  mandoc man-pages docs
apk add --no-cache \
  -q --no-progress \
  vim

DEPENDENCIES

COPY install-redis.sh ./
RUN <<REDIS_INSTALL
set -o errexit
chmod +x /home/dev/app/install-redis.sh
./install-redis.sh
REDIS_INSTALL

COPY redis.conf.patch ./
COPY users.acl /etc/redis/users.acl
RUN <<SETUP
# Patch redis.conf, add users.acl and append dev user
set -o errexit

mkdir -p /etc/redis/
patch -i /home/dev/app/redis.conf.patch -o /etc/redis/redis.conf /usr/local/src/redis/redis.conf

# Generate a random password that is safe enough to copy/paste for local development use.
dev_redis_pass="$(openssl rand 111 | base64 -w 0 | tr -d '[:punct:]')"

# The 'dev' user is meant to only be used when troubleshooting or investigating.
cat <<APPEND_DEV_USER >> /etc/redis/users.acl
user dev on >$dev_redis_pass allchannels allkeys +@all
APPEND_DEV_USER

redis-server --version
redis-cli --version
SETUP

CMD [ "redis-server", "/etc/redis/redis.conf", "--dir", "/var/lib/redis" ]
