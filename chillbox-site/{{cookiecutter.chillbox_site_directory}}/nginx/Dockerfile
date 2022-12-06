# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-01-23" label: "NGINX base image" interval: "+5 months"
# docker pull nginx:1.22.0-alpine
# docker image ls --digests alpine
FROM nginx:1.22.0-alpine@sha256:98a1e37840fdf90f57df595dae8e27a198278170323744e13464b7f3a927562e

# These env vars match with what chillbox provides.
ENV CHILLBOX_SERVER_NAME=chillbox.test
ENV CHILLBOX_SERVER_PORT=80
ENV S3_ENDPOINT_URL=http://chillbox-minio:9000
ENV IMMUTABLE_BUCKET_NAME=chillboximmutable
ENV IMMUTABLE_BUCKET_DOMAIN_NAME=http://chillbox-minio:9000
ENV ARTIFACT_BUCKET_NAME=chillboxartifact
ENV SLUGNAME={{ cookiecutter.slugname }}
ENV VERSION=0
ENV SERVER_NAME=localhost
ENV SERVER_PORT=80

# These env vars match with what the site.json provides.

ENV API_PATH=/api/
ENV API_PORT=8100
ENV API_SCHEME=http
ENV API_HOST=$SLUGNAME-api

ENV CHILL_STATIC_EXAMPLE_TRY_FILES_LAST_PARAM=@chill-static-example
ENV CHILL_STATIC_EXAMPLE_PATH=/
ENV CHILL_STATIC_EXAMPLE_PORT=5000
ENV CHILL_STATIC_EXAMPLE_SCHEME=http
ENV CHILL_STATIC_EXAMPLE_HOST=$SLUGNAME-chill-static-example

ENV CHILL_DYNAMIC_EXAMPLE_PATH=/dynamic/
ENV CHILL_DYNAMIC_EXAMPLE_PORT=5001
ENV CHILL_DYNAMIC_EXAMPLE_SCHEME=http
ENV CHILL_DYNAMIC_EXAMPLE_HOST=$SLUGNAME-chill-dynamic-example

# The IMMUTABLE_EXAMPLE_PATH should not be passed to the proxy because it ends
# with a slash ('/') character. The proxy url IMMUTABLE_EXAMPLE_URL will typically
# have it's own route that ends with a hash string and a slash character. When developing locally this
# IMMUTABLE_EXAMPLE_URL is set to the localhost server with a specific port.
ENV IMMUTABLE_EXAMPLE_PATH="/this-should-always-end-with-a-slash/"
ENV IMMUTABLE_EXAMPLE_PORT=8080
ENV IMMUTABLE_EXAMPLE_URL=http://$SLUGNAME-immutable-example:$IMMUTABLE_EXAMPLE_PORT/
ENV IMMUTABLE_EXAMPLE_HASH="fake-hash"

WORKDIR /build

COPY --chown=nginx:nginx default.nginx.conf /etc/nginx/conf.d/default.conf
COPY --chown=nginx:nginx nginx.conf /etc/nginx/nginx.conf

COPY --chown=nginx:nginx root /srv/{{ cookiecutter.slugname }}/root

RUN <<INSTALL
# Install directories for {{ cookiecutter.slugname }}
set -o errexit
mkdir -p /srv/{{ cookiecutter.slugname }}/
mkdir -p /var/log/nginx/{{ cookiecutter.slugname }}
chown -R nginx:nginx /etc/nginx/conf.d
mkdir -p /srv/{{ cookiecutter.slugname }}/.well-known
chown -R nginx:nginx /srv/{{ cookiecutter.slugname }}/.well-known

INSTALL

COPY templates /build/templates

RUN <<FILEWATCH_SUPPORT
# Create scripts to help with local development
set -o errexit
apk update
apk add --no-cache \
  gettext \
  entr

mkdir -p .tmp
cat <<'MEOW' > dev.sh
#!/usr/bin/env sh
set -o errexit

script_name="$(basename "$0")"
project_dir="$(dirname "$(realpath "$0")")"

usage() {
  cat <<HEREUSAGE

Watch for changes in the templates/ directory and reload nginx.

Usage:
  $script_name -h
  $script_name

Options:
  -h                  Show this help message.

HEREUSAGE
}

while getopts "h" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    ?) usage
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))

tmp_watch_files="$(mktemp)"
cleanup() {
  rm -f "$tmp_watch_files"
}
trap cleanup EXIT INT HUP TERM

for d in templates; do
  find "$project_dir/$d" >> "$tmp_watch_files"
done

# Show the access log along with the nginx output
touch /var/log/nginx/{{ cookiecutter.slugname }}/access.log
tail -f /var/log/nginx/{{ cookiecutter.slugname }}/access.log &

cat "$tmp_watch_files" | entr -rzdn "$project_dir/reload-templates.sh"
MEOW

cat <<'HISS' > reload-templates.sh
#!/usr/bin/env sh
set -o errexit
script_name="$(basename "$0")"
if [ -f /etc/nginx/conf.d/{{ cookiecutter.slugname }}.nginx.conf ]; then
  cp /etc/nginx/conf.d/{{ cookiecutter.slugname }}.nginx.conf /etc/nginx/conf.d/{{ cookiecutter.slugname }}.nginx.conf.bak
fi

env_names_to_expand_via_chillbox="
ARTIFACT_BUCKET_NAME
AWS_PROFILE
CHILLBOX_ARTIFACT
CHILLBOX_SERVER_NAME
CHILLBOX_SERVER_PORT
IMMUTABLE_BUCKET_DOMAIN_NAME
IMMUTABLE_BUCKET_NAME
LETS_ENCRYPT_SERVER
S3_ENDPOINT_URL
SERVER_NAME
SERVER_PORT
SITES_ARTIFACT
SLUGNAME
TECH_EMAIL
VERSION
"
env_names_to_expand_via_site_json="
API_HOST
API_PATH
API_PORT
API_SCHEME
CHILL_DYNAMIC_EXAMPLE_HOST
CHILL_DYNAMIC_EXAMPLE_PATH
CHILL_DYNAMIC_EXAMPLE_PORT
CHILL_DYNAMIC_EXAMPLE_SCHEME
CHILL_STATIC_EXAMPLE_HOST
CHILL_STATIC_EXAMPLE_PATH
CHILL_STATIC_EXAMPLE_PORT
CHILL_STATIC_EXAMPLE_SCHEME
CHILL_STATIC_EXAMPLE_TRY_FILES_LAST_PARAM
IMMUTABLE_EXAMPLE_HASH
IMMUTABLE_EXAMPLE_PATH
IMMUTABLE_EXAMPLE_PORT
IMMUTABLE_EXAMPLE_URL
"
env_names_to_expand="$env_names_to_expand_via_chillbox $env_names_to_expand_via_site_json"
env_names="$(printf "%s" "$env_names_to_expand" | sed 's/./$&/; /\S/!d' | xargs)"
# Expand and check that all environment variables have been set and have values
# to avoid replacing with empty strings.
for env_var in $env_names; do
  check_var="$(eval "printf \"%s\" \"$env_var\"")"
  test -n "$check_var" || (echo "ERROR The environment variable has no value $env_var" >&2 && exit 1)
done
envsubst "$env_names" < /build/templates/{{ cookiecutter.slugname }}.nginx.conf.template > /etc/nginx/conf.d/{{ cookiecutter.slugname }}.nginx.conf

if [ -n "$(grep '${.\+}' /etc/nginx/conf.d/{{ cookiecutter.slugname }}.nginx.conf || printf "")" ]; then
  echo "ERROR $script_name Not all env variables were replaced from /build/templates/{{ cookiecutter.slugname }}.nginx.conf.template"
  grep -H -n '${.\+}' /etc/nginx/conf.d/{{ cookiecutter.slugname }}.nginx.conf
  exit 1
fi

chown -R nginx:nginx /etc/nginx/conf.d/{{ cookiecutter.slugname }}.nginx.conf
if nginx -t; then
    echo "INFO $script_name Passed test of nginx configuration."
else
  echo "ERROR $script_name Failed test of nginx configuration."
  if [ -f /etc/nginx/conf.d/{{ cookiecutter.slugname }}.nginx.conf.bak ]; then
    echo "INFO $script_name Switching back to previous {{ cookiecutter.slugname }}.nginx.conf."
    cp /etc/nginx/conf.d/{{ cookiecutter.slugname }}.nginx.conf /etc/nginx/conf.d/{{ cookiecutter.slugname }}.nginx.conf.failed
    mv /etc/nginx/conf.d/{{ cookiecutter.slugname }}.nginx.conf.bak /etc/nginx/conf.d/{{ cookiecutter.slugname }}.nginx.conf
    echo "INFO $script_name Please review failed configuration file /etc/nginx/conf.d/{{ cookiecutter.slugname }}.nginx.conf.failed that was generated from /build/templates/{{ cookiecutter.slugname }}.nginx.conf.template"
  fi
fi
nginx -t
nginx -g 'daemon off;'
HISS

chmod +x dev.sh
chmod +x reload-templates.sh
FILEWATCH_SUPPORT

# Only the /etc/nginx/conf.d/default.conf and /etc/nginx/nginx.conf have been
# created at this point. These should be valid since they are included in this
# same Dockerfile.
RUN nginx -t

CMD ["./dev.sh"]
