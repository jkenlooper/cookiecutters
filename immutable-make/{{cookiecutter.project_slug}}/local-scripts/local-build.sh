#!/usr/bin/env sh

set -o errexit

# {{ cookiecutter.template_file_comment }}
# Version: {{ cookiecutter._version }}

script_name="$(basename "$0")"
script_dir="$(dirname "$0")"
. "$script_dir/check-mkfile-name.sh"

usage() {
  cat <<HERE

Local build script for development of immutable resources. Starts a container
and copies built files to the dist directory.

Usage:
  $script_name -h
  $script_name -s <slugname> -a <appname> -p <project_dir> [<cmd>]

Options:
  -h                  Show this help message.

  -s <slugname>       Set the slugname.

  -a <appname>        Set the appname.

  -p <project_dir>    Set the project directory.

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

check_mkfile_name "make"

test -n "$slugname" || (echo "ERROR $script_name: No slugname set." >&2 && usage && exit 1)
test -n "$appname" || (echo "ERROR $script_name: No appname set." >&2 && usage && exit 1)
test -n "$project_dir" || (echo "ERROR $script_name: No project_dir set." >&2 && usage && exit 1)
project_dir="$(realpath "$project_dir")"
test -d "$project_dir" || (echo "ERROR $script_name The project directory ($project_dir) must exist." >&2 && exit 1)

project_name_hash="$(printf "%s" "$project_dir" | md5sum | cut -d' ' -f1)"
image_name="$slugname-$appname-$project_name_hash"
container_name="$slugname-$appname-$project_name_hash"

stop_and_rm_containers_silently () {
  # A fresh start of the containers are needed. Hide any error output and such
  # from this as it is irrelevant like a lost llama.
  docker stop --time 1 "$container_name" > /dev/null 2>&1 &
  wait

  docker container rm "$container_name" > /dev/null 2>&1 || printf ''
}
stop_and_rm_containers_silently

docker image rm "$image_name" > /dev/null 2>&1 || printf ""
export DOCKER_BUILDKIT=1
docker build \
  --target build \
  -t "$image_name" \
  "${project_dir}"
docker run \
  --name "$container_name" \
  "$image_name" tree /build/dist
docker cp "$container_name":/build/dist "$project_dir/"
stop_and_rm_containers_silently
