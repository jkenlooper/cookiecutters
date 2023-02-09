#!/usr/bin/env sh

# {{ cookiecutter.template_file_comment }}

set -o errexit

script_name="$(basename "$0")"

usage() {
  cat <<HERE

Build and run a redis container for local development.

Usage:
  $script_name -h
  $script_name -s <slugname> <site_json_file>

Options:
  -h                  Show this help message.

  -s <slugname>       Set the slugname.

Args:
  <site_json_file>    Site json file with redis configuration.

HERE
}

slugname=""

while getopts "hs:" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    s) slugname=$OPTARG ;;
    ?) usage
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))

site_json_file="$1"

test -n "$slugname" || (echo "ERROR $script_name: No slugname set." >&2 && usage && exit 1)
test -n "$site_json_file" || (echo "ERROR $script_name: No argument set for the site json file." >&2 && usage && exit 1)
site_json_file="$(realpath "$site_json_file")"
test -f "$site_json_file" || (echo "ERROR $script_name: The $site_json_file is not a file." >&2 && usage && exit 1)

script_dir="$(dirname "$(realpath "$0")")"
project_dir="$(dirname "${script_dir}")"

project_dir_basename="$(basename "$project_dir")"
project_name_hash="$(printf "%s" "$project_dir" | md5sum | cut -d' ' -f1)"
{{ 'test "${#project_name_hash}" -eq "32" || (echo "ERROR $script_name: Failed to create a project name hash from the project dir ($project_dir)" && exit 1)' }}


# Hostnames can't be over 63 characters
redis_host="$(printf '%s' "$slugname-redis-$project_name_hash" | grep -o -E '^.{0,63}')"
build_start_redis() {
  service_handler="redis"
  host="$redis_host"
  docker image rm "$host" > /dev/null 2>&1 || printf ""
  echo "INFO $script_name: Building docker image: $host"
  DOCKER_BUILDKIT=1 docker build \
    --quiet \
    -t "$host" \
    "$project_dir/$service_handler"
  set -- "$(jq -r '.redis | to_entries | .[] | "--\(.key) " + "\(.value)"' "$site_json_file")"
  docker run -d \
    --name "$host" \
    --network chillboxnet \
    --mount "type=volume,src=$slugname-redis-data-$project_name_hash,dst=/var/lib/redis,readonly=false" \
    "$host" \
    redis-server /etc/redis/redis.conf $@ --bind "0.0.0.0" --protected-mode "no" --dir "/var/lib/redis" --aclfile "/etc/redis/users.acl" --unixsocket "/run/redis.sock"
}
build_start_redis

