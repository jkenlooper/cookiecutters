#!/usr/bin/env sh

# {{ cookiecutter.template_file_comment }}

set -o errexit

script_name="$(basename "$0")"

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
  <site_json_file>    Site json file with services.

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

app_port=8088
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

cat <<MEOW > "$chillbox_config_file"
export CHILLBOX_ARTIFACT=not-applicable
export SITES_ARTIFACT=not-applicable
MEOW
# shellcheck disable=SC1091
. "$chillbox_config_file"

cat <<MEOW > "$site_env"
export ARTIFACT_BUCKET_NAME=chillboxartifact
export AWS_PROFILE=chillbox_object_storage
export CHILLBOX_SERVER_NAME=chillbox.test
export CHILLBOX_SERVER_PORT=80
export IMMUTABLE_BUCKET_DOMAIN_NAME=http://chillbox-minio:9000
export IMMUTABLE_BUCKET_NAME=chillboximmutable
export LETS_ENCRYPT_SERVER=letsencrypt_test
export S3_ENDPOINT_URL=http://chillbox-minio:9000
# SERVER_NAME is set to empty string so nginx will not require Host header; which is useful for local development.
export SERVER_NAME='""'
export SERVER_PORT=$app_port
export SLUGNAME=$slugname
export TECH_EMAIL=llama@local.test
export VERSION=$site_version_string
MEOW

# Append the local only vars to also be exported
cat <<MEOW >> "$site_env"
export PROJECT_NAME_HASH=$project_name_hash
MEOW

# Hostnames can't be over 63 characters
chill_static_example_host="$(printf '%s' "$slugname-chill-static-example-$project_name_hash" | grep -o -E '^.{0,63}')"
chill_dynamic_example_host="$(printf '%s' "$slugname-chill-dynamic-example-$project_name_hash" | grep -o -E '^.{0,63}')"
api_host="$(printf '%s' "$slugname-api-$project_name_hash" | grep -o -E '^.{0,63}')"
immutable_example_host="$(printf '%s' "$slugname-immutable-example-$project_name_hash" | grep -o -E '^.{0,63}')"
nginx_host="$(printf '%s' "$slugname-nginx-$project_name_hash" | grep -o -E '^.{0,63}')"

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
    '.env[] | select(.cmd != null) | .name + "=\"$(" + .cmd + ")\"; export " + .name' \
    "$site_json_file" > "$tmp_eval"
  # Only need to prompt the user if a cmd was set.
  if [ -n "$(sed 's/\s//g; /^$/d' "$tmp_eval")" ]; then
    eval "$(cat "$tmp_eval")"
    cp "$site_json_file" "$site_json_file.original"
    jq \
      '(.env[] | select(.cmd != null)) |= . + {name: .name, value: $ENV[.name]}' < "$site_json_file.original" > "$site_json_file"
    rm "$site_json_file.original"
  fi
  rm -f "$tmp_eval"
)


export ENV_FILE="$site_env"
export CHILLBOX_CONFIG_FILE="$chillbox_config_file"
eval "$(jq -r '.env // [] | .[] | "export " + .name + "=" + (.value | @sh)' "$site_json_file" \
  | "$script_dir/envsubst-site-env.sh" -c "$site_json_file")"

cat <<MEOW > "$site_env_vars_file"
# Generated from $0 on $(date)

ARTIFACT_BUCKET_NAME=chillboxartifact
AWS_PROFILE=chillbox_object_storage
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
SLUGNAME=$slugname
TECH_EMAIL=llama@local.test
VERSION=$site_version_string
MEOW
jq -r '.env // [] | .[] | .name + "=" + .value' "$site_json_file" \
  | "$script_dir/envsubst-site-env.sh" -c "$site_json_file" >> "$site_env_vars_file"

#cat "$site_env_vars_file"
. "$script_dir/utils.sh"

"$script_dir/local-stop.sh" -s "$slugname" "$site_json_file"

# TODO Run the local-s3 container?
chillbox_minio_state="$(docker inspect --format '{{.State.Running}}' chillbox-minio || printf "false")"
chillbox_local_shared_secrets_state="$(docker inspect --format '{{.State.Running}}' chillbox-local-shared-secrets || printf "false")"
if [ "${chillbox_minio_state}" = "true" ] && [ "${chillbox_local_shared_secrets_state}" = "true" ]; then
  echo "chillbox local is running"
else
  "${project_dir}/local-s3/local-chillbox.sh"
fi


services="$(jq -c '.services // [] | .[]' "$site_json_file")"
IFS="$(printf '\n ')" && IFS="${IFS% }"
#shellcheck disable=SC2086
set -f -- $services
for service_json_obj in "$@"; do
  service_handler=""
  service_lang=""
  service_name=""
  eval "$(echo "$service_json_obj" | jq -r '@sh "
    service_handler=\(.handler)
    service_lang=\(.lang)
    service_name=\(.name)
    "')"
  echo "$service_handler $service_name $service_lang"
  eval "$(echo "$service_json_obj" | jq -r '.environment // [] | .[] | "export " + .name + "=" + (.value | @sh)' \
    | "$script_dir/envsubst-site-env.sh" -c "$site_json_file")"

  # The ports on these do not need to be exposed since nginx is in front of them.
  case "$service_lang" in

    immutable)
      printf '\n\n%s\n\n' "INFO $script_name: Starting $service_lang service: $HOST"
      set -x
      docker image rm "$HOST" > /dev/null 2>&1 || printf ""
      DOCKER_BUILDKIT=1 docker build \
          --target build \
          -t "$HOST" \
          "$project_dir/$service_handler"
      docker run -d \
        --network chillboxnet \
        --env-file "$site_env_vars_file" \
        --mount "type=bind,src=$project_dir/$service_handler/src,dst=/build/src,readonly" \
        --name "$HOST" \
        "$HOST"
      set +x
      ;;

    flask)
      if [ ! -e "$not_encrypted_secrets_dir/$service_handler/$service_handler.secrets.cfg" ]; then
        "$script_dir/local-secrets.sh" -s "$slugname" "$site_json_file" || echo "Ignoring error from local-secrets.sh"
      fi

      printf '\n\n%s\n\n' "INFO $script_name: Starting $service_lang service: $HOST"
      set -x
      docker image rm "$HOST" > /dev/null 2>&1 || printf ""
      DOCKER_BUILDKIT=1 docker build \
        -t "$HOST" \
        "$project_dir/$service_handler"
      # Switch to root user when troubleshooting or using bind mounts
      echo "Running the $HOST container with root user."
      docker run -d --tty \
        --name "$HOST" \
        --user root \
        --env-file "$site_env_vars_file" \
        -e HOST="localhost" \
        -e PORT="$PORT" \
        -e SECRETS_CONFIG="/var/lib/local-secrets/$slugname/$service_handler/$service_handler.secrets.cfg" \
        --network chillboxnet \
        --mount "type=bind,src=$project_dir/$service_handler/src/${slugname}_${service_handler},dst=/usr/local/src/app/src/${slugname}_${service_handler},readonly" \
        --mount "type=bind,src=$not_encrypted_secrets_dir/$service_handler/$service_handler.secrets.cfg,dst=/var/lib/local-secrets/$slugname/$service_handler/$service_handler.secrets.cfg,readonly" \
        "$HOST" ./flask-run.sh
      set +x
      ;;

    chill)
      printf '\n\n%s\n\n' "INFO $script_name: Starting $service_lang service: $HOST"
      set -x
      docker image rm "$HOST" > /dev/null 2>&1 || printf ""
      DOCKER_BUILDKIT=1 docker build \
          -t "$HOST" \
          "$project_dir/$service_handler"
      docker run -d \
        --name "$HOST" \
        --network chillboxnet \
        --env-file "$site_env_vars_file" \
        --mount "type=volume,src=$HOST,dst=/var/lib/chill/sqlite3" \
        --mount "type=bind,src=$project_dir/$service_handler/documents,dst=/home/chill/app/documents" \
        --mount "type=bind,src=$project_dir/$service_handler/queries,dst=/home/chill/app/queries" \
        --mount "type=bind,src=$project_dir/$service_handler/templates,dst=/home/chill/app/templates" \
        "$HOST"
      set +x
      ;;

  esac

done

nginx_host="$(printf '%s' "$slugname-nginx-$project_name_hash" | grep -o -E '^.{0,63}')"
build_start_nginx() {
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
    -e CHILLBOX_ARTIFACT \
    -e SITES_ARTIFACT \
    -e PROJECT_NAME_HASH \
    -e ENV_FILE=/build/local-start-site-env \
    -e CHILLBOX_CONFIG_FILE=/build/local-chillbox-config \
    --mount "type=bind,src=$ENV_FILE,dst=/build/local-start-site-env,readonly" \
    --mount "type=bind,src=$CHILLBOX_CONFIG_FILE,dst=/build/local-chillbox-config,readonly" \
    --mount "type=bind,src=$project_dir/$service_handler/templates,dst=/build/templates,readonly" \
    --mount "type=bind,src=$project_dir/bin/envsubst-site-env.sh,dst=/build/envsubst-site-env.sh,readonly" \
    --mount "type=bind,src=$site_json_file,dst=/build/local.site.json,readonly" \
    "$host"
}
build_start_nginx

sleep 2
output_all_logs_on_containers "$slugname" "$project_name_hash" "$site_json_file"

show_container_state "$slugname" "$project_name_hash" "$site_json_file"

echo "The $slugname site is running on http://localhost:$app_port/ "
