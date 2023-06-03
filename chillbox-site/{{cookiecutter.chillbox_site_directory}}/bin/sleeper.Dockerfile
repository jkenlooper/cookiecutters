# syntax=docker/dockerfile:1.5.2

# {{ cookiecutter.template_file_comment }}

# UPKEEP due: "2023-09-03" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.18.0
# docker image ls --digests alpine
FROM alpine:3.18.0@sha256:02bb6f428431fbc2809c5d1b41eab5a68350194fb508869a33cb1af4444c9b11

WORKDIR /home/dev

RUN <<SETUP
set -o errexit
addgroup -g 44444 dev
adduser -u 44444 -G dev -s /bin/sh -D dev
cat <<'HERE' > /home/dev/sleep.sh
#!/usr/bin/env sh
while true; do
  printf 'z'
  sleep 60
done
HERE
chmod +x /home/dev/sleep.sh
SETUP

USER dev

CMD ["/home/dev/sleep.sh"]
