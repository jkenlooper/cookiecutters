#!/usr/bin/env bash

# {{ cookiecutter.template_file_comment }}
# Version: {{ cookiecutter._version }}

set -o errexit

# Use this to run commands that modify or update vendor files.
# Arg is passed in as the CMD, for example:
# ./llama.sh sh

slugname={{ cookiecutter.slugname }}-{{ cookiecutter.project_slug }}

cleanup () {
  docker container stop $slugname || printf ""
  docker container rm $slugname || printf ""
}
trap cleanup exit

docker image rm "$slugname" || printf ""
DOCKER_BUILDKIT=1 docker build \
  --progress=plain \
  --target build \
  -t $slugname \
  ./

# Switch to root user when troubleshooting
echo "Running the $slugname container with root user."
docker run -it \
  --name $slugname \
  --user root \
  -p {{ cookiecutter.project_port }}:{{ cookiecutter.project_port }} \
  --mount "type=bind,src=$(pwd)/src,dst=/build/src,readonly" \
  $slugname \
  "$@"

chmod -R u+w vendor/
rm -rf vendor
docker cp $slugname:/build/vendor ./
chmod -R u-w vendor/

read -e -p "Remove the container? [y/n]
" CONFIRM
if [ "$CONFIRM" == "y" ]; then
  docker rm \
    $slugname
fi
