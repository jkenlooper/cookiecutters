#!/usr/bin/env sh

set -o errexit
set -o nounset

stop_and_rm_containers_silently () {
  slugname="$1"
  shift 1
  project_name_hash="$1"
  shift 1
  service_handler_names="$*"

  # A fresh start of the containers are needed. Hide any error output and such
  # from this as it is irrelevant.
  for service_handler in $service_handler_names; do
    container_name="$(printf '%s' "$slugname-$service_handler-$project_name_hash" | grep -o -E '^.{0,63}')"
    docker stop --time 1 "$container_name" > /dev/null 2>&1 &
  done
  wait

  for service_handler in $service_handler_names; do
    container_name="$(printf '%s' "$slugname-$service_handler-$project_name_hash" | grep -o -E '^.{0,63}')"
    docker container rm "$container_name" > /dev/null 2>&1 || printf ''
  done
}

output_all_logs_on_containers () {
  slugname="$1"
  shift 1
  project_name_hash="$1"
  shift 1
  service_handler_names="$*"

  for service_handler in $service_handler_names; do
    container_name="$(printf '%s' "$slugname-$service_handler-$project_name_hash" | grep -o -E '^.{0,63}')"
    echo ""
    echo "### Logs for $container_name ###"
    docker logs "$container_name"
    echo ""
    echo "### End logs for $container_name ###"
    echo ""
  done
}

show_container_state () {
  slugname="$1"
  shift 1
  project_name_hash="$1"
  shift 1
  service_handler_names="$*"

  for service_handler in $service_handler_names; do
    container_name="$(printf '%s' "$slugname-$service_handler-$project_name_hash" | grep -o -E '^.{0,63}')"
    echo "$container_name $(docker container inspect $container_name | jq '.[0].State.Status + .[0].State.Error')"
  done
}
