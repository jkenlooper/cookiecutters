# syntax=docker/dockerfile:1.4.3

# {{ cookiecutter.template_file_comment }}

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
# SERVER_NAME is set to empty string so nginx will not require Host header; which is useful for local development.
ENV SERVER_NAME='""'
ENV SERVER_PORT=80

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
  jq \
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
touch /var/log/nginx/$SLUGNAME/access.log
tail -f /var/log/nginx/$SLUGNAME/access.log &

cat "$tmp_watch_files" | entr -rzdn "$project_dir/reload-templates.sh"
MEOW

cat <<'HISS' > reload-templates.sh
#!/usr/bin/env sh
set -o errexit
script_name="$(basename "$0")"

template_path="/build/templates/$SLUGNAME.nginx.conf.template"
slugname_nginx_conf="$(basename "$template_path" ".template")"

var_curly_regex='${.\+}'

fallback_nginx_conf() {
  nginx_conf="$1"
  test -n "$nginx_conf" || (echo "ERROR $script_name fallback_nginx_conf" >&2 && exit 1)
  if [ -f "/etc/nginx/conf.d/$nginx_conf.bak" ]; then
    echo "INFO $script_name Switching back to previous /etc/nginx/conf.d/$nginx_conf"
    cp "/etc/nginx/conf.d/$nginx_conf" "/etc/nginx/conf.d/$nginx_conf.failed"
    mv "/etc/nginx/conf.d/$nginx_conf.bak" "/etc/nginx/conf.d/$nginx_conf"
    echo "INFO $script_name Please review failed configuration file /etc/nginx/conf.d/$nginx_conf.failed"
  else
    if [ -f "/etc/nginx/conf.d/$nginx_conf" ]; then
      mv "/etc/nginx/conf.d/$nginx_conf" "/etc/nginx/conf.d/$nginx_conf.failed"
      echo "INFO $script_name Please review failed configuration file /etc/nginx/conf.d/$nginx_conf.failed"
      rm -f "/etc/nginx/conf.d/$nginx_conf"
    fi
  fi
  printf "\n\n########\n%s\n########\n\n" "Start /etc/nginx/conf.d/$nginx_conf.failed"
  cat  "/etc/nginx/conf.d/$nginx_conf.failed"
  printf "\n\n########\n%s\n########\n\n" "End /etc/nginx/conf.d/$nginx_conf.failed"
}

if [ -f "/etc/nginx/conf.d/$slugname_nginx_conf" ]; then
  cp "/etc/nginx/conf.d/$slugname_nginx_conf" "/etc/nginx/conf.d/$slugname_nginx_conf.bak"
fi

/build/envsubst-site-env.sh -c /build/local.site.json \
  < "$template_path" > "/etc/nginx/conf.d/$slugname_nginx_conf"

if [ -n "$(grep "$var_curly_regex" "/etc/nginx/conf.d/$slugname_nginx_conf" || printf "")" ]; then
  echo "ERROR $script_name: Not all env variables were replaced from $template_path" >&2
  grep -H -n "$var_curly_regex" "/etc/nginx/conf.d/$slugname_nginx_conf"
  fallback_nginx_conf "$slugname_nginx_conf"
fi

chown -R nginx:nginx /etc/nginx/conf.d/$slugname_nginx_conf

if nginx -t; then
  if [ -f "/etc/nginx/conf.d/$slugname_nginx_conf" ]; then
    echo "INFO $script_name Passed test of nginx configuration"
  fi
else
  echo "ERROR $script_name: Failed test of nginx configuration after updating /etc/nginx/conf.d/$slugname_nginx_conf from $template_path." >&2
  fallback_nginx_conf "$slugname_nginx_conf"
fi

# Do a sanity check to make sure nginx conf is still good.
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
