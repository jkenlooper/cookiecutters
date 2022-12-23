#!/usr/bin/env sh

set -o errexit


script_dir="$(dirname "$(realpath "$0")")"
script_name="$(basename "$0")"

name_hash="$(printf "%s" "$script_dir" | md5sum | cut -d' ' -f1)"
{{ 'test "${#name_hash}" -eq "32" || (echo "ERROR $script_name: Failed to create a name hash from the directory ($script_dir)" && exit 1)' }}

usage() {
  cat <<HERE
Update the python requirement txt files, check for known vulnerabilities,
download local python packages to dist/python/.

Usage:
  $script_name -h
  $script_name -i
  $script_name

Options:
  -h                  Show this help message.
  -i                  Switch to interactive mode.

HERE
}

slugname=""
interactive="n"

while getopts "hi" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    i)
       interactive="y"
       ;;
    ?) usage
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))

LOCAL_PYTHON_PACKAGES=/var/lib/chillbox/python
image_name="verify-$name_hash"
docker image rm "$image_name" > /dev/null 2>&1 || printf ""
DOCKER_BUILDKIT=1 docker build \
  -t "$image_name" \
  -f "$script_dir/verify.Dockerfile" \
  --build-arg LOCAL_PYTHON_PACKAGES="$LOCAL_PYTHON_PACKAGES" \
  "$script_dir"

container_name="verify-$name_hash"
if [ "$interactive" = "y" ]; then
  docker run -i --tty \
    --user root \
    --name "$container_name" \
    "$image_name" sh

else
  docker run -d \
    --name "$container_name" \
    "$image_name"
fi

docker cp "$container_name:/home/dev/app/requirements.txt" "$script_dir/requirements.txt"
mkdir -p dist/python
docker cp "$container_name:$LOCAL_PYTHON_PACKAGES/." "$script_dir/dist/python/"
docker stop --time 0 "$container_name" > /dev/null 2>&1 || printf ""
docker rm "$container_name" > /dev/null 2>&1 || printf ""
