#!/usr/bin/env sh

# {{ cookiecutter.template_file_comment }}

set -o errexit
set -o nounset

stop_and_rm_containers_silently () {
  slugname="$1"
  shift 1
  project_name_hash="$1"
  shift 1
  site_json_file="$1"
  shift 1

  # A fresh start of the containers are needed. Hide any error output and such
  # from this as it is irrelevant.
  services="$(jq -c '.services // [] | .[]' "$site_json_file")"
  IFS="$(printf '\n ')" && IFS="${IFS% }"
  #shellcheck disable=SC2086
  set -f -- $services
  for service_json_obj in "$@"; do
    service_name=""
    eval "$(echo "$service_json_obj" | jq -r '@sh "
      service_name=\(.name)
      "')"
    echo "$service_name"
    container_name="$(printf '%s' "$slugname-$service_name-$project_name_hash" | grep -o -E '^.{0,63}')"
    docker stop --time 1 "$container_name" > /dev/null 2>&1 &
  done
  container_name="$(printf '%s' "$slugname-nginx-$project_name_hash" | grep -o -E '^.{0,63}')"
  docker stop --time 1 "$container_name" > /dev/null 2>&1 &
  wait

  for service_json_obj in "$@"; do
    service_name=""
    eval "$(echo "$service_json_obj" | jq -r '@sh "
      service_name=\(.name)
      "')"
    echo "$service_name"
    container_name="$(printf '%s' "$slugname-$service_name-$project_name_hash" | grep -o -E '^.{0,63}')"
    docker container rm "$container_name" > /dev/null 2>&1 || printf ''
  done
  container_name="$(printf '%s' "$slugname-nginx-$project_name_hash" | grep -o -E '^.{0,63}')"
  docker container rm "$container_name" > /dev/null 2>&1 || printf ''
}

output_all_logs_on_containers () {
  slugname="$1"
  shift 1
  project_name_hash="$1"
  shift 1
  site_json_file="$1"
  shift 1

  show_log () {
    service_name="$1"
    container_name="$(printf '%s' "$slugname-$service_name-$project_name_hash" | grep -o -E '^.{0,63}')"
    echo ""
    echo "### Logs for $container_name ###"
    docker logs "$container_name"
    echo ""
    echo "### End logs for $container_name ###"
    echo ""
  }

  services="$(jq -c '.services // [] | .[]' "$site_json_file")"
  IFS="$(printf '\n ')" && IFS="${IFS% }"
  #shellcheck disable=SC2086
  set -f -- $services
  for service_json_obj in "$@"; do
    service_name=""
    eval "$(echo "$service_json_obj" | jq -r '@sh "
      service_name=\(.name)
      "')"
    show_log "$service_name"
  done
  show_log "nginx"
}

show_container_state () {
  slugname="$1"
  shift 1
  project_name_hash="$1"
  shift 1
  site_json_file="$1"
  shift 1

  inspect_container () {
    service_name="$1"
    container_name="$(printf '%s' "$slugname-$service_name-$project_name_hash" | grep -o -E '^.{0,63}')"
    echo "$container_name $(docker container inspect $container_name | jq '.[0].State.Status + .[0].State.Error')"
  }

  services="$(jq -c '.services // [] | .[]' "$site_json_file")"
  IFS="$(printf '\n ')" && IFS="${IFS% }"
  #shellcheck disable=SC2086
  set -f -- $services
  for service_json_obj in "$@"; do
    service_name=""
    eval "$(echo "$service_json_obj" | jq -r '@sh "
      service_name=\(.name)
      "')"
    inspect_container "$service_name"
  done
  inspect_container "nginx"
}
