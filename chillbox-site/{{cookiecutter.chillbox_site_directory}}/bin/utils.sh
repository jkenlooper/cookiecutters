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
  has_redis="$(jq -r -e 'has("redis")' "$site_json_file" || printf "false")"

  # A fresh start of the containers are needed. Hide any error output and such
  # from this as it is irrelevant.
  services_and_workers="$(jq -c '.services // [], .workers // [] | .[]' "$site_json_file")"
  IFS="$(printf '\n ')" && IFS="${IFS% }"
  #shellcheck disable=SC2086
  set -f -- $services_and_workers
  for service_json_obj in "$@"; do
    service_name=""
    eval "$(echo "$service_json_obj" | jq -r '@sh "
      service_name=\(.name)
      "')"
    echo "$service_name"
    container_name="$(printf '%s' "$slugname-$service_name-$project_name_hash" | grep -o -E '^.{0,63}')"
    docker stop --time 1 "$container_name" > /dev/null 2>&1 &
  done
  if [ "$has_redis" = "true" ]; then
    container_name="$(printf '%s' "$slugname-redis-$project_name_hash" | grep -o -E '^.{0,63}')"
    docker stop --time 2 "$container_name" > /dev/null 2>&1 &
  fi
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
  if [ "$has_redis" = "true" ]; then
    container_name="$(printf '%s' "$slugname-redis-$project_name_hash" | grep -o -E '^.{0,63}')"
    docker container rm "$container_name" > /dev/null 2>&1 || printf ''
  fi
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

  docker logs chillbox-minio

  services_and_workers="$(jq -c '.services // [], .workers // [] | .[]' "$site_json_file")"
  IFS="$(printf '\n ')" && IFS="${IFS% }"
  #shellcheck disable=SC2086
  set -f -- $services_and_workers
  for service_json_obj in "$@"; do
    service_name=""
    eval "$(echo "$service_json_obj" | jq -r '@sh "
      service_name=\(.name)
      "')"
    show_log "$service_name"
  done
  has_redis="$(jq -r -e 'has("redis")' "$site_json_file" || printf "false")"
  if [ "$has_redis" = "true" ]; then
    show_log "redis"
  fi
  show_log "nginx"
}

all_containers_done () {
  slugname="$1"
  shift 1
  project_name_hash="$1"
  shift 1
  site_json_file="$1"
  shift 1

  is_container_done () {
    service_name="$1"
    container_name="$(printf '%s' "$slugname-$service_name-$project_name_hash" | grep -o -E '^.{0,63}')"
    container_status="$(docker container inspect $container_name | jq -r '.[0].State.Status')"
    if [ "$container_status" != "exited" ] && [ "$container_status" != "running" ]; then
      exit 1
    fi
  }

  services_and_workers="$(jq -c '.services // [], .workers // [] | .[]' "$site_json_file")"
  IFS="$(printf '\n ')" && IFS="${IFS% }"
  #shellcheck disable=SC2086
  set -f -- $services_and_workers
  for service_json_obj in "$@"; do
    service_name=""
    eval "$(echo "$service_json_obj" | jq -r '@sh "
      service_name=\(.name)
      "')"
    is_container_done "$service_name"
  done
  has_redis="$(jq -r -e 'has("redis")' "$site_json_file" || printf "false")"
  if [ "$has_redis" = "true" ]; then
    is_container_done "redis"
  fi
  is_container_done "nginx"
  printf "yes"
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

  services_and_workers="$(jq -c '.services // [], .workers // [] | .[]' "$site_json_file")"
  IFS="$(printf '\n ')" && IFS="${IFS% }"
  #shellcheck disable=SC2086
  set -f -- $services_and_workers
  for service_json_obj in "$@"; do
    service_name=""
    eval "$(echo "$service_json_obj" | jq -r '@sh "
      service_name=\(.name)
      "')"
    inspect_container "$service_name"
  done
  has_redis="$(jq -r -e 'has("redis")' "$site_json_file" || printf "false")"
  if [ "$has_redis" = "true" ]; then
    inspect_container "redis"
  fi
  inspect_container "nginx"
}
