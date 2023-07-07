#!/usr/bin/env sh

# {{ cookiecutter.template_file_comment }}

set -o errexit

script_name="$(basename "$0")"
CONTAINER_START_TIMEOUT="${CONTAINER_START_TIMEOUT-10}"
sleep_interval="0.1"
max_number_of_checks="$(echo "scale=0; $CONTAINER_START_TIMEOUT / $sleep_interval" | bc)"

usage() {
  cat <<HERE

Build and run each container in detached mode.
For development only; each one will rebuild on file changes.

Usage:
  $script_name -h
  $script_name -s <slugname> <site_json_file>

Options:
  -h                  Show this help message.

  -s <slugname>       Set the slugname.

Args:
  <site_json_file>    Site json file with services and workers.

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

app_port={{ cookiecutter.local_app_port }}
script_dir="$(dirname "$(realpath "$0")")"
project_dir="$(dirname "${script_dir}")"
site_version_string="$(make --silent -C "$project_dir" inspect.VERSION)"

project_dir_basename="$(basename "$project_dir")"
project_name_hash="$(printf "%s" "$project_dir" | md5sum | cut -d' ' -f1)"
{{ 'test "${#project_name_hash}" -eq "32" || (echo "ERROR $script_name: Failed to create a project name hash from the project dir ($project_dir)" && exit 1)' }}

# Storing the local development secrets in the user data directory for this site
# depending on the project directory path at the time.
# https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
site_data_home="${XDG_DATA_HOME:-"$HOME/.local/share"}/$project_dir_basename-$slugname--$project_name_hash"
# Store the generated env vars file in the application state dir since it needs
# to persist after the script ends.
site_state_home="${XDG_STATE_HOME:-"$HOME/.local/state"}/$project_dir_basename-$slugname--$project_name_hash"
mkdir -p "$site_data_home"
mkdir -p "$site_state_home"

not_encrypted_secrets_dir="$site_data_home/not-encrypted-secrets"
site_env="$site_state_home/local-start-site-env"
site_env_vars_file="$site_state_home/local-start-site-env-vars"
chillbox_config_file="$site_state_home/local-chillbox-config"
modified_site_json_file="$site_state_home/local-modified.site.json"

cat <<MEOW > "$chillbox_config_file"
export CHILLBOX_ARTIFACT=not-applicable
export SITES_ARTIFACT=not-applicable
MEOW
# shellcheck disable=SC1091
. "$chillbox_config_file"

docker network create chillboxnet > /dev/null 2>&1 || printf ""
{{ 'chillbox_subnet="$(docker network inspect chillboxnet --format "{{range .IPAM.Config}}{{print .Subnet}}{{end}}")"' }}

cat <<MEOW > "$site_env"
export ARTIFACT_BUCKET_NAME=chillboxartifact
export CHILLBOX_SERVER_NAME=chillbox.test
export CHILLBOX_SERVER_PORT=80
export IMMUTABLE_BUCKET_NAME=chillboximmutable
export ACME_SERVER=letsencrypt_test
export S3_ENDPOINT_URL=http://chillbox-minio:9000
export SERVER_NAME=localhost
export CHILLBOX_SUBNET="$chillbox_subnet"
export SERVER_PORT=$app_port
export SLUGNAME=$slugname
export TECH_EMAIL=llama@local.test
export VERSION=$site_version_string
MEOW

# Append the local only vars to also be exported
cat <<MEOW >> "$site_env"
export PROJECT_NAME_HASH=$project_name_hash
MEOW

# shellcheck disable=SC1091
. "$site_env"

(
  # Sub shell for handling of the 'cd' to the slugname directory. This
  # allows custom 'cmd's in the site.json work relatively to the project
  # root directory.
  cd "$project_dir"
  tmp_eval="$(mktemp)"
  # Warning! The '.cmd' value is executed on the host here. The content in
  # the site.json should be trusted, but it is a little safer to confirm
  # with the user first.
  jq -r \
    '.env[] | select(.cmd != null) | .name + "=\"$(" + .cmd + ")\";\\\nexport " + .name' \
    "$site_json_file" > "$tmp_eval"
  # Only need to prompt the user if a cmd was set.
  if [ -n "$(sed 's/\s//g; /^$/d' "$tmp_eval")" ]; then
    printf "\n\n--- ###\n\n"
    cat "$tmp_eval"
    printf "\n\n--- ###\n\n"
    printf "%s\n" "Execute the above commands so the matching env fields from the project's site json file can be updated?"
    printf "%s\n" "Original: $site_json_file"
    printf "%s\n" "Modify: $modified_site_json_file"
    printf "%s\n" "Proceed? [y/n]"
    read -r eval_cmd_confirm
    if [ "$eval_cmd_confirm" = "y" ]; then
      eval "$(cat "$tmp_eval")"
      jq \
        '(.env[] | select(.cmd != null)) |= . + {name: .name, value: $ENV[.name]}' < "$site_json_file" > "$modified_site_json_file"
    else
      exit
    fi
  fi
  rm -f "$tmp_eval"
)


export ENV_FILE="$site_env"
export CHILLBOX_CONFIG_FILE="$chillbox_config_file"
eval "$(jq -r '.env // [] | .[] | "export " + .name + "=" + (.value | @sh)' "$modified_site_json_file" \
  | "$script_dir/envsubst-site-env.sh" -c "$modified_site_json_file")"

cat <<MEOW > "$site_env_vars_file"
# Generated from $0 on $(date)

ARTIFACT_BUCKET_NAME=chillboxartifact
CHILLBOX_SERVER_NAME=chillbox.test
CHILLBOX_SERVER_PORT=80
IMMUTABLE_BUCKET_NAME=chillboximmutable
ACME_SERVER=letsencrypt_test
S3_ENDPOINT_URL=http://chillbox-minio:9000
SERVER_NAME=localhost
CHILLBOX_SUBNET=$chillbox_subnet
SERVER_PORT=$app_port
SLUGNAME=$slugname
TECH_EMAIL=llama@local.test
VERSION=$site_version_string
MEOW
jq -r '.env // [] | .[] | .name + "=" + .value' "$modified_site_json_file" \
  | "$script_dir/envsubst-site-env.sh" -c "$modified_site_json_file" >> "$site_env_vars_file"

#cat "$site_env_vars_file"
. "$script_dir/utils.sh"

# To stop the containers, it doesn't require using the modified json file.
stop_and_rm_containers_silently "$slugname" "$project_name_hash" "$site_json_file"

"$script_dir/local-s3.sh"

has_redis="$(jq -r -e 'has("redis")' "$site_json_file" || printf "false")"
if [ "$has_redis" = "true" ]; then
  "$script_dir/local-redis.sh" -s "$slugname" "$site_json_file"
fi


workers="$(jq -c '.workers // [] | .[]' "$modified_site_json_file")"
IFS="$(printf '\n ')" && IFS="${IFS% }"
#shellcheck disable=SC2086
set -f -- $workers
for worker_json_obj in "$@"; do
  worker_handler=""
  worker_lang=""
  worker_name=""
  secrets_config=""
  worker_run_cmd=""
  eval "$(echo "$worker_json_obj" | jq -r '@sh "
    worker_handler=\(.handler)
    worker_lang=\(.lang)
    worker_name=\(.name)
    secrets_config=\(.secrets_config // "")
    worker_run_cmd=\(."run-cmd")
    "')"
  echo "$worker_handler $worker_name $worker_lang"
  eval "$(echo "$worker_json_obj" | jq -r '.environment // [] | .[] | "export " + .name + "=" + (.value | @sh)' \
    | "$script_dir/envsubst-site-env.sh" -c "$modified_site_json_file")"
  tmp_worker_env_vars_file="$(mktemp)"
  echo "$worker_json_obj" | jq -r '.environment // [] | .[] | .name + "=" + .value' \
    | "$script_dir/envsubst-site-env.sh" -c "$modified_site_json_file" > "$tmp_worker_env_vars_file"

  image_name="$(printf '%s' "$slugname-$worker_handler-$project_name_hash" | grep -o -E '^.{0,63}')"
  container_name="$(printf '%s' "$slugname-$worker_name-$project_name_hash" | grep -o -E '^.{0,63}')"

  echo "DEBUG worker $worker_json_obj"
  # The ports on these do not need to be exposed since nginx is in front of them.
  case "$worker_lang" in

    python-worker)
      if [ -n "$secrets_config" ] && [ ! -s "$not_encrypted_secrets_dir/$worker_handler/$secrets_config" ]; then
        "$script_dir/local-secrets.sh" -s "$slugname" "$modified_site_json_file"
        test -s "$not_encrypted_secrets_dir/$worker_handler/$secrets_config" || (echo "ERROR $script_name: Failed to create the file $not_encrypted_secrets_dir/$worker_handler/$secrets_config" && exit 1)
      else
        # Just create an empty file so the container mount works.
        touch "$not_encrypted_secrets_dir/$worker_handler/$secrets_config"
      fi

      printf '\n\n%s\n\n' "INFO $script_name: Starting $worker_lang worker: $container_name"
      docker image rm "$image_name" > /dev/null 2>&1 || printf ""
      echo "INFO $script_name: Building docker image: $image_name"
      DOCKER_BUILDKIT=1 docker build \
        --quiet \
        --build-arg RUN_DEV_CMD="$worker_run_cmd" \
        -t "$image_name" \
        "$project_dir/$worker_handler" > /dev/null
      docker run -d --tty \
        --name "$container_name" \
        --env-file "$site_env_vars_file" \
        --env-file "$tmp_worker_env_vars_file" \
        -e SECRETS_CONFIG="/var/lib/local-secrets/$slugname/$worker_handler/$secrets_config" \
        --network chillboxnet \
        --mount "type=volume,src=chillbox-local-shared,dst=/var/lib/chillbox-local-shared,readonly=true" \
        --mount "type=bind,src=$project_dir/$worker_handler/src/${slugname}_${worker_handler},dst=/usr/local/src/app/src/${slugname}_${worker_handler},readonly" \
        --mount "type=bind,src=$not_encrypted_secrets_dir/$worker_handler/$secrets_config,dst=/var/lib/local-secrets/$slugname/$worker_handler/$secrets_config,readonly" \
        "$image_name" > /dev/null

      # Delay so the code on the worker can execute first.
      sleep 1

      container_status="$(docker container inspect "$container_name" | jq -r '.[0].State.Status')"
      i="0"
      while [ "$container_status" != "running" ]; do
        i="$((i+1))"
        test "$i" -lt "$max_number_of_checks" || break
        sleep "$sleep_interval"
        container_status="$(docker container inspect "$container_name" | jq -r '.[0].State.Status')"
        if [ "$container_status" = "exited" ]; then
          break
        fi
      done

      if [ "$container_status" = "exited" ]; then
        docker logs "$container_name"
        echo "ERROR $script_name: Failed to start $worker_lang worker: $container_name"
        echo "Start this container in interactive mode? [y/n] "
        read -r confirm
        if [ "$confirm" = "y" ]; then
          printf '\n\n%s\n\n' "INFO $script_name: Debugging $worker_lang worker: $container_name"
          docker container rm "$container_name" > /dev/null 2>&1 || printf ''
          docker run -d --tty \
            --name "$container_name" \
            --user root \
            --env-file "$site_env_vars_file" \
            --env-file "$tmp_worker_env_vars_file" \
            -e SECRETS_CONFIG="/var/lib/local-secrets/$slugname/$worker_handler/$secrets_config" \
            --network chillboxnet \
            --mount "type=volume,src=chillbox-local-shared,dst=/var/lib/chillbox-local-shared,readonly=true" \
            --mount "type=bind,src=$project_dir/$worker_handler/src/${slugname}_${worker_handler},dst=/usr/local/src/app/src/${slugname}_${worker_handler},readonly" \
            --mount "type=bind,src=$not_encrypted_secrets_dir/$worker_handler/$secrets_config,dst=/var/lib/local-secrets/$slugname/$worker_handler/$secrets_config,readonly" \
            "$image_name" ./sleep.sh > /dev/null
          echo "Running the $container_name container with root user and sleep process to keep it started."
          echo "Use the 'docker exec' command to troubleshoot."
        fi
      fi
      ;;
  esac

done

services="$(jq -c '.services // [] | .[]' "$modified_site_json_file")"
IFS="$(printf '\n ')" && IFS="${IFS% }"
#shellcheck disable=SC2086
set -f -- $services
for service_json_obj in "$@"; do
  service_handler=""
  service_lang=""
  service_name=""
  secrets_config=""
  eval "$(echo "$service_json_obj" | jq -r '@sh "
    service_handler=\(.handler)
    service_lang=\(.lang)
    service_name=\(.name)
    secrets_config=\(.secrets_config // "")
    "')"
  echo "$service_handler $service_name $service_lang"
  eval "$(echo "$service_json_obj" | jq -r '.environment // [] | .[] | "export " + .name + "=" + (.value | @sh)' \
    | "$script_dir/envsubst-site-env.sh" -c "$modified_site_json_file")"
  tmp_service_env_vars_file="$(mktemp)"
  echo "$service_json_obj" | jq -r '.environment // [] | .[] | .name + "=" + .value' \
    | "$script_dir/envsubst-site-env.sh" -c "$modified_site_json_file" > "$tmp_service_env_vars_file"

  image_name="$(printf '%s' "$slugname-$service_handler-$project_name_hash" | grep -o -E '^.{0,63}')"
  container_name="$(printf '%s' "$slugname-$service_name-$project_name_hash" | grep -o -E '^.{0,63}')"

  # The ports on these do not need to be exposed since nginx is in front of them.
  case "$service_lang" in

    immutable)
      printf '\n\n%s\n\n' "INFO $script_name: Starting $service_lang service: $container_name"
      docker image rm "$image_name" > /dev/null 2>&1 || printf ""
      echo "INFO $script_name: Building docker image: $image_name"
      DOCKER_BUILDKIT=1 docker build \
        --quiet \
        --target build \
        -t "$image_name" \
        "$project_dir/$service_handler" > /dev/null
      docker run -d --tty \
        --network chillboxnet \
        --env-file "$site_env_vars_file" \
        --env-file "$tmp_service_env_vars_file" \
        -e BIND="0.0.0.0" \
        --mount "type=bind,src=$project_dir/$service_handler/src,dst=/build/src,readonly" \
        --name "$container_name" \
        "$image_name" > /dev/null
      ;;

    python)
      if [ -n "$secrets_config" ] && [ ! -s "$not_encrypted_secrets_dir/$service_handler/$secrets_config" ]; then
        "$script_dir/local-secrets.sh" -s "$slugname" "$modified_site_json_file"
        test -s "$not_encrypted_secrets_dir/$service_handler/$secrets_config" || (echo "ERROR $script_name: Failed to create the file $not_encrypted_secrets_dir/$service_handler/$secrets_config" && exit 1)
      else
        # Just create an empty file so the container mount works.
        touch "$not_encrypted_secrets_dir/$service_handler/$secrets_config"
      fi

      printf '\n\n%s\n\n' "INFO $script_name: Starting $service_lang service: $container_name"
      docker image rm "$image_name" > /dev/null 2>&1 || printf ""
      echo "INFO $script_name: Building docker image: $image_name"
      DOCKER_BUILDKIT=1 docker build \
        --quiet \
        -t "$image_name" \
        "$project_dir/$service_handler" > /dev/null
      docker run -d --tty \
        --name "$container_name" \
        --env-file "$site_env_vars_file" \
        --env-file "$tmp_service_env_vars_file" \
        -e BIND="0.0.0.0:$PORT" \
        -e SECRETS_CONFIG="/var/lib/local-secrets/$slugname/$service_handler/$secrets_config" \
        --network chillboxnet \
        --mount "type=volume,src=chillbox-local-shared,dst=/var/lib/chillbox-local-shared,readonly=true" \
        --mount "type=bind,src=$project_dir/$service_handler/src/${slugname}_${service_handler},dst=/usr/local/src/app/src/${slugname}_${service_handler},readonly" \
        --mount "type=bind,src=$not_encrypted_secrets_dir/$service_handler/$secrets_config,dst=/var/lib/local-secrets/$slugname/$service_handler/$secrets_config,readonly" \
        "$image_name" > /dev/null

      # Delay so the code on the service can execute first.
      sleep 1

      container_status="$(docker container inspect $container_name | jq -r '.[0].State.Status')"
      i="0"
      while [ "$container_status" != "running" ]; do
        i="$((i+1))"
        test "$i" -lt "$max_number_of_checks" || break
        sleep "$sleep_interval"
        container_status="$(docker container inspect $container_name | jq -r '.[0].State.Status')"
        if [ "$container_status" = "exited" ]; then
          break
        fi
      done

      if [ "$container_status" = "exited" ]; then
        docker logs "$container_name"
        echo "ERROR $script_name: Failed to start $service_lang service: $container_name"
        echo "Start this container in interactive mode? [y/n] "
        read -r confirm
        if [ "$confirm" = "y" ]; then
          printf '\n\n%s\n\n' "INFO $script_name: Debugging $service_lang service: $container_name"
          docker container rm "$container_name" > /dev/null 2>&1 || printf ''
          docker run -d --tty \
            --name "$container_name" \
            --user root \
            --env-file "$site_env_vars_file" \
            --env-file "$tmp_service_env_vars_file" \
            -e BIND="0.0.0.0:$PORT" \
            -e SECRETS_CONFIG="/var/lib/local-secrets/$slugname/$service_handler/$secrets_config" \
            --network chillboxnet \
            --mount "type=volume,src=chillbox-local-shared,dst=/var/lib/chillbox-local-shared,readonly=true" \
            --mount "type=bind,src=$project_dir/$service_handler/src/${slugname}_${service_handler},dst=/usr/local/src/app/src/${slugname}_${service_handler},readonly" \
            --mount "type=bind,src=$not_encrypted_secrets_dir/$service_handler/$secrets_config,dst=/var/lib/local-secrets/$slugname/$service_handler/$secrets_config,readonly" \
            "$image_name" ./sleep.sh > /dev/null
          echo "Running the $container_name container with root user and sleep process to keep it started."
          echo "Use the 'docker exec' command to troubleshoot."
        fi
      fi
      ;;

    chill)
      printf '\n\n%s\n\n' "INFO $script_name: Starting $service_lang service: $container_name"
      docker image rm "$image_name" > /dev/null 2>&1 || printf ""
      echo "INFO $script_name: Building docker image: $image_name"
      DOCKER_BUILDKIT=1 docker build \
        --quiet \
        -t "$image_name" \
        "$project_dir/$service_handler" > /dev/null
      docker run -d \
        --name "$container_name" \
        --network chillboxnet \
        --env-file "$site_env_vars_file" \
        --env-file "$tmp_service_env_vars_file" \
        -e HOST="0.0.0.0" \
        --mount "type=volume,src=$container_name,dst=/var/lib/chill/sqlite3" \
        --mount "type=bind,src=$project_dir/$service_handler/documents,dst=/home/chill/app/documents" \
        --mount "type=bind,src=$project_dir/$service_handler/queries,dst=/home/chill/app/queries" \
        --mount "type=bind,src=$project_dir/$service_handler/templates,dst=/home/chill/app/templates" \
        "$image_name" > /dev/null
      ;;

  esac

  rm -f "$tmp_service_env_vars_file"
done

# Hostnames can't be over 63 characters
nginx_host="$(printf '%s' "$slugname-nginx-$project_name_hash" | grep -o -E '^.{0,63}')"
build_start_nginx() {
  service_handler="nginx"
  host="$nginx_host"
  printf '\n\n%s\n\n' "INFO $script_name: Starting nginx: $host"
  docker image rm "$host" > /dev/null 2>&1 || printf ""
  echo "INFO $script_name: Building docker image: $host"
  DOCKER_BUILDKIT=1 docker build \
    --quiet \
    -t "$host" \
    "$project_dir/$service_handler" > /dev/null
  docker run -d \
    -p "$app_port:$app_port" \
    --name "$host" \
    --network chillboxnet \
    --env-file "$site_env_vars_file" \
    -e CHILLBOX_ARTIFACT \
    -e SITES_ARTIFACT \
    -e PROJECT_NAME_HASH \
    -e ENV_FILE=/build/local-start-site-env \
    -e CHILLBOX_CONFIG_FILE=/build/local-chillbox-config \
    --mount "type=bind,src=$ENV_FILE,dst=/build/local-start-site-env,readonly" \
    --mount "type=bind,src=$CHILLBOX_CONFIG_FILE,dst=/build/local-chillbox-config,readonly" \
    --mount "type=bind,src=$project_dir/$service_handler/templates,dst=/build/templates,readonly" \
    --mount "type=bind,src=$project_dir/bin/envsubst-site-env.sh,dst=/build/envsubst-site-env.sh,readonly" \
    --mount "type=bind,src=$modified_site_json_file,dst=/build/local.site.json,readonly" \
    "$host" > /dev/null
}
build_start_nginx

wait_until_all_finished() {
  all_done="$(all_containers_done "$slugname" "$project_name_hash" "$site_json_file" || printf "no")"
  i="0"
  while [ "$all_done" != "yes" ]; do
    i="$((i+1))"
    test "$i" -lt "$max_number_of_checks" || break
    sleep "$sleep_interval"
    all_done="$(all_containers_done "$slugname" "$project_name_hash" "$site_json_file" || printf "no")"
  done
}
wait_until_all_finished

output_all_logs_on_containers "$slugname" "$project_name_hash" "$site_json_file"

show_container_state "$slugname" "$project_name_hash" "$site_json_file"

echo "The $slugname site is running on http://localhost:$app_port/ "
