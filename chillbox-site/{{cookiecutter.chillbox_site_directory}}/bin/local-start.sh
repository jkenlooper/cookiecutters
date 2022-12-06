#!/usr/bin/env sh

set -o errexit

# Build and run each container in detached mode.
# For development only; each one will rebuild on file changes.

slugname={{ cookiecutter.slugname }}
app_port=8088
NODE_ENV=${NODE_ENV-"development"}
script_dir="$(dirname "$(realpath "$0")")"
project_dir="$(dirname "${script_dir}")"
script_name="$(basename "$0")"
site_version_string="$(make --silent -C "$project_dir" inspect.VERSION)"

immutable_example_hash="$(make --silent -C "$project_dir/immutable-example/" inspect.HASH)"
immutable_example_port=8080

project_dir_basename="$(basename "$project_dir")"
project_name_hash="$(printf "%s" "$project_dir" | md5sum | cut -d' ' -f1)"
{{ 'test "${#project_name_hash}" -eq "32" || (echo "ERROR $script_name: Failed to create a project name hash from the project dir ($project_dir)" && exit 1)' }}

# Hostnames can't be over 63 characters
chill_static_example_host="$(printf '%s' "$slugname-chill-static-example-$project_name_hash" | grep -o -E '^.{0,63}')"
chill_dynamic_example_host="$(printf '%s' "$slugname-chill-dynamic-example-$project_name_hash" | grep -o -E '^.{0,63}')"
api_host="$(printf '%s' "$slugname-api-$project_name_hash" | grep -o -E '^.{0,63}')"
immutable_example_host="$(printf '%s' "$slugname-immutable-example-$project_name_hash" | grep -o -E '^.{0,63}')"
nginx_host="$(printf '%s' "$slugname-nginx-$project_name_hash" | grep -o -E '^.{0,63}')"

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
site_env_vars_file="$site_state_home/local-start-site-env-vars"

cat <<MEOW > "$site_env_vars_file"
# Generated from $0 on $(date)

ARTIFACT_BUCKET_NAME=chillboxartifact
AWS_PROFILE=chillbox_object_storage
CHILLBOX_ARTIFACT=not-applicable
CHILLBOX_SERVER_NAME=chillbox.test
CHILLBOX_SERVER_PORT=80
IMMUTABLE_BUCKET_DOMAIN_NAME=http://chillbox-minio:9000
IMMUTABLE_BUCKET_NAME=chillboximmutable
LETS_ENCRYPT_SERVER=letsencrypt_test
S3_ENDPOINT_URL=http://chillbox-minio:9000
# Not setting server_name to allow it to be set differently in each Dockerfile
# if needed.
#SERVER_NAME=
SERVER_PORT=$app_port
SITES_ARTIFACT=not-applicable
SLUGNAME=$slugname
TECH_EMAIL=llama@local.test
VERSION=$site_version_string

CHILL_STATIC_EXAMPLE_TRY_FILES_LAST_PARAM=@chill-static-example
CHILL_STATIC_EXAMPLE_PATH=/
CHILL_STATIC_EXAMPLE_PORT=5000
CHILL_STATIC_EXAMPLE_SCHEME=http
CHILL_STATIC_EXAMPLE_HOST=$chill_static_example_host

CHILL_DYNAMIC_EXAMPLE_PATH=/dynamic/
CHILL_DYNAMIC_EXAMPLE_PORT=5001
CHILL_DYNAMIC_EXAMPLE_SCHEME=http
CHILL_DYNAMIC_EXAMPLE_HOST=$chill_dynamic_example_host

API_PATH=/api/
API_PORT=8100
API_SCHEME=http
API_HOST=$api_host

IMMUTABLE_EXAMPLE_HASH=$immutable_example_hash
IMMUTABLE_EXAMPLE_PATH=/immutable-example/v1/$immutable_example_hash/
IMMUTABLE_EXAMPLE_PORT=$immutable_example_port
IMMUTABLE_EXAMPLE_HOST=$immutable_example_host
IMMUTABLE_EXAMPLE_URL=http://$immutable_example_host:$immutable_example_port/
MEOW
. "$site_env_vars_file"

. "$script_dir/utils.sh"

stop_and_rm_containers_silently "$slugname" "$project_name_hash" chill-dynamic-example api chill-static-example immutable-example nginx

chillbox_minio_state="$(docker inspect --format '{{ '{{.State.Running}}' }}' chillbox-minio || printf "false")"
chillbox_local_shared_secrets_state="$(docker inspect --format '{{ '{{.State.Running}}' }}' chillbox-local-shared-secrets || printf "false")"
if [ "${chillbox_minio_state}" = "true" ] && [ "${chillbox_local_shared_secrets_state}" = "true" ]; then
  echo "chillbox local is running"
else
  "${project_dir}/local-s3/local-chillbox.sh"
fi


# The ports on these do not need to be exposed since nginx is in front of them.

build_start_immutable_example() {
  service_handler="immutable-example"
  host="$immutable_example_host"
  docker image rm "$host" > /dev/null 2>&1 || printf ""
  DOCKER_BUILDKIT=1 docker build \
      --target build \
      -t "$host" \
      "$project_dir/$service_handler"
  docker run -d \
    --network chillboxnet \
    --env-file "$site_env_vars_file" \
    --mount "type=bind,src=$project_dir/$service_handler/src,dst=/build/src,readonly" \
    --name "$host" \
    "$host"
}

build_start_api() {
  service_handler="api"
  host="$api_host"
  docker image rm "$host" > /dev/null 2>&1 || printf ""
  DOCKER_BUILDKIT=1 docker build \
    -t "$host" \
    "$project_dir/$service_handler"
  # Switch to root user when troubleshooting or using bind mounts
  echo "Running the $host container with root user."
  docker run -d --tty \
    --name "$host" \
    --user root \
    --env-file "$site_env_vars_file" \
    -e HOST="localhost" \
    -e PORT="$API_PORT" \
    -e SECRETS_CONFIG="/var/lib/local-secrets/{{ cookiecutter.slugname }}/api/api-bridge.secrets.cfg" \
    --network chillboxnet \
    --mount "type=bind,src=$project_dir/api/src/site1_api,dst=/usr/local/src/app/src/site1_api,readonly" \
    --mount "type=bind,src=$not_encrypted_secrets_dir/api/api-bridge.secrets.cfg,dst=/var/lib/local-secrets/{{ cookiecutter.slugname }}/api/api-bridge.secrets.cfg,readonly" \
    "$host" ./flask-run.sh
}

build_start_chill_static_example() {
  service_handler="chill-static-example"
  host="$chill_static_example_host"
  docker image rm "$host" > /dev/null 2>&1 || printf ""
  DOCKER_BUILDKIT=1 docker build \
      -t "$host" \
      "$project_dir/$service_handler"
  docker run -d \
    --name "$host" \
    --network chillboxnet \
    --env-file "$site_env_vars_file" \
    --mount "type=volume,src=$host,dst=/var/lib/chill/sqlite3" \
    --mount "type=bind,src=$project_dir/$service_handler/documents,dst=/home/chill/app/documents" \
    --mount "type=bind,src=$project_dir/$service_handler/queries,dst=/home/chill/app/queries" \
    --mount "type=bind,src=$project_dir/$service_handler/templates,dst=/home/chill/app/templates" \
    "$host"
}

build_start_chill_dynamic_example() {
  service_handler="chill-dynamic-example"
  host="$chill_dynamic_example_host"
  docker image rm "$host" > /dev/null 2>&1 || printf ""
  DOCKER_BUILDKIT=1 docker build \
      -t "$host" \
      "$project_dir/$service_handler"
  docker run -d \
    --name "$host" \
    --network chillboxnet \
    --env-file "$site_env_vars_file" \
    --mount "type=volume,src=$host,dst=/var/lib/chill/sqlite3" \
    --mount "type=bind,src=$project_dir/$service_handler/documents,dst=/home/chill/app/documents" \
    --mount "type=bind,src=$project_dir/$service_handler/queries,dst=/home/chill/app/queries" \
    --mount "type=bind,src=$project_dir/$service_handler/templates,dst=/home/chill/app/templates" \
    "$host"
}

build_start_nginx() {
  #TODO Read from local.site.json and get env_names_to_expand_via_site_json to pass to nginx. Or pass the local.site.json to nginx container?
  service_handler="nginx"
  host="$nginx_host"
  docker image rm "$host" > /dev/null 2>&1 || printf ""
  DOCKER_BUILDKIT=1 docker build \
      -t "$host" \
      "$project_dir/$service_handler"
  docker run -d \
    -p "$app_port:$app_port" \
    --name "$host" \
    --network chillboxnet \
    --env-file "$site_env_vars_file" \
    --mount "type=bind,src=$project_dir/$service_handler/templates,dst=/build/templates" \
    "$host"
}

if [ ! -e "$not_encrypted_secrets_dir/api/api-bridge.secrets.cfg" ]; then
  "$script_dir/local-secrets.sh" || echo "Ignoring error from local-secrets.sh"
fi

build_start_immutable_example
build_start_api
build_start_chill_static_example
build_start_chill_dynamic_example
build_start_nginx

sleep 2
output_all_logs_on_containers "$slugname" "$project_name_hash" chill-dynamic-example api chill-static-example immutable-example nginx

show_container_state "$slugname" "$project_name_hash" chill-dynamic-example api chill-static-example immutable-example nginx

echo "The $slugname site is running on http://localhost:$app_port/ "



#docker logs --follow $slugname-nginx
