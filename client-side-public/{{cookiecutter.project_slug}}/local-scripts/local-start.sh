#!/usr/bin/env sh

# {{ cookiecutter.template_file_comment }}
# Version: {{ cookiecutter._version }}

set -o errexit

script_name="$(basename "$0")"

usage() {
  cat <<HERE

Local start script for development of immutable resources. Starts a container
with a bind mount of the src directory.

Usage:
  $script_name -h
  $script_name -s <slugname> -a <appname> -p <project_dir> [<cmd>]

Options:
  -h                  Show this help message.

  -s <slugname>       Set the slugname.

  -a <appname>        Set the appname.

  -p <project_dir>    Set the project directory.

Args:
  <cmd>   Pass the optional command to the container instead of using default.

HERE
}

slugname=""
appname=""
project_dir=""

while getopts "hs:a:p:" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    s) slugname=$OPTARG ;;
    a) appname=$OPTARG ;;
    p) project_dir=$OPTARG ;;
    ?) usage
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))

stop_and_rm_containers_silently () {
  # A fresh start of the containers are needed. Hide any error output and such
  # from this as it is irrelevant like a lost llama.
  docker stop --time 1 "$container_name" > /dev/null 2>&1 &
  wait

  docker container rm "$container_name" > /dev/null 2>&1 || printf ''
}

build_and_run() {
  # For local development; this can be on the host network. The BIND is set to
  # localhost so only localhost can access. Switch it to 0.0.0.0 to allow anyone
  # else on that network to access.
  port="${PORT:-{{ cookiecutter.project_port }}}"
  bind="${BIND:-127.0.0.1}"

  project_name_hash="$(printf "%s" "$project_dir" | md5sum | cut -d' ' -f1)"
  image_name="$slugname-$appname-$project_name_hash"
  container_name="$slugname-$appname-$project_name_hash"

  stop_and_rm_containers_silently

  docker image rm "$image_name" > /dev/null 2>&1 || printf ""
  export DOCKER_BUILDKIT=1
  docker build \
    --target build \
    -t "$image_name" \
    "${project_dir}"

  docker run -i --tty \
    --user root \
    --network=host \
    --env BIND="$bind" \
    --env CLIENT_SIDE_PUBLIC_PORT="$port" \
    --mount "type=bind,src=$project_dir/src,dst=/build/src,readonly" \
    --name "$container_name" \
    "$image_name" "$@"
}

test -n "$slugname" || (echo "ERROR $script_name: No slugname set." >&2 && usage && exit 1)
test -n "$appname" || (echo "ERROR $script_name: No appname set." >&2 && usage && exit 1)
test -n "$project_dir" || (echo "ERROR $script_name: No project_dir set." >&2 && usage && exit 1)
project_dir="$(realpath "$project_dir")"
test -d "$project_dir" || (echo "ERROR $script_name The project directory ($project_dir) must exist." >&2 && exit 1)

build_and_run "$@"
