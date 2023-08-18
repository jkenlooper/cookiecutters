#!/usr/bin/env sh

# {{ cookiecutter.template_file_comment }}

set -o errexit

slugname="{{ cookiecutter.slugname }}"

project_dir="$(dirname "$(dirname "$(realpath "$0")")")"
script_name="$(basename "$0")"
project_name_hash="$(printf "%s" "$project_dir" | md5sum | cut -d' ' -f1)"
{{ 'test "${#project_name_hash}" -eq "32" || (echo "ERROR $script_name: Failed to create a project name hash from the project dir ($project_dir)" && exit 1)' }}

usage() {
  cat <<HERE
Start up a local container for running the open source ZITADEL identity
provider.  Another local container for cockroachdb is also started.
https://zitadel.com/

Only for local development purposes! This has not been configured for a secure
environment.

Usage:
  $script_name -h
  $script_name
  $script_name destroy

Options:
  -h                  Show this help message.

Subcommands:
  destroy             Delete chillbox-zitadel and chillbox-cockroachdb containers and destroy the associated data volume.

Environment:
  ZITADEL_FIRSTINSTANCE_ORG_HUMAN_USERNAME  Default is 'root'
  ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORD  Default is 'RootPassword1!'
  ZITADEL_PORT                              Default is 37837

Docker volumes:
  chillbox-cockroachdb-data    Stores ZITADEL data.

HERE
}

while getopts "h" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    ?) usage
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [ "$1" = "destroy" ]; then
  docker stop --time 1 "chillbox-zitadel"
  docker container rm --volumes "chillbox-zitadel"
  docker stop --time 1 "chillbox-cockroachdb"
  docker container rm --volumes "chillbox-cockroachdb"
  docker volume rm chillbox-cockroachdb-data
  echo "Removed chillbox-zitadel and chillbox-cockroachdb containers and destroyed chillbox-cockroachdb-data volume."
  exit 0
fi

# Only create the chillboxnet network if it doesn't exist. Ignoring any output
# to keep the stdout clean.
chillboxnet_id="$(docker network ls -q -f name=chillboxnet 2> /dev/null || printf "")"
if [ -z "$chillboxnet_id" ]; then
  docker network create chillboxnet --driver bridge > /dev/null 2>&1 || printf ""
fi

# UPKEEP due: "2023-12-19" label: "Cockroachdb image" interval: "+6 months"
# Zitadel only tested on certain cockroachdb versions.
# https://zitadel.com/docs/self-hosting/deploy/linux
# https://www.cockroachlabs.com/docs/releases/
# docker pull cockroachdb/cockroach:v22.2.2
# docker image ls --digests cockroachdb/cockroach:v22.2.2
cockroachdb_image="cockroachdb/cockroach:v22.2.2@sha256:a68866c4d93cdb66ea741819e7d6419f15ed460b4948f99b14b07048c9c29439"

cockroachdb_host=chillbox-cockroachdb
cockroachdb_port=26257
is_chillbox_cockroachdb_running="$(docker inspect --format {{ "'{{.State.Running}}'" }} chillbox-cockroachdb 2> /dev/null || printf "")"
if [ "$is_chillbox_cockroachdb_running" != "true" ]; then
  # Start as insecure single node with data store set to a docker volume.
  # https://www.cockroachlabs.com/docs/v23.1/cockroach-start#store
  docker run --name "$cockroachdb_host" \
    -d \
    --tty \
    --publish 9090:8080 \
    --publish "$cockroachdb_port":26257 \
    --network chillboxnet \
    --mount 'type=volume,src=chillbox-cockroachdb-data,dst=/cockroach/cockroach-data,readonly=false' \
    "$cockroachdb_image" start-single-node --insecure --advertise-host chillbox-cockroachdb --http-addr 0.0.0.0
fi

printf "\n%s\n" "Waiting for $cockroachdb_host container to be in running state."
while true; do
  is_chillbox_cockroachdb_running="$(docker inspect --format {{ "'{{.State.Running}}'" }} $cockroachdb_host 2> /dev/null || printf "")"
  if [ "$is_chillbox_cockroachdb_running" = "true" ]; then
    printf "."
    docker exec $cockroachdb_host curl -s -f 'http://localhost:8080/health?ready=1' > /dev/null 2>&1 || continue
    echo ""
    break
  else
    chillbox_cockroachdb_state="$(docker inspect --format {{ "'{{.State.Status}}'" }} $cockroachdb_host 2> /dev/null || printf "")"
    printf "%s ..." "$chillbox_cockroachdb_state"
  fi
  sleep 1.1
done

# UPKEEP due: "2023-09-16" label: "ZITADEL image" interval: "+1 months"
# https://zitadel.com/docs/self-hosting/deploy/linux
# https://github.com/zitadel/zitadel/releases
# docker pull ghcr.io/zitadel/zitadel:v2.32.0
# docker image ls --digests ghcr.io/zitadel/zitadel:v2.32.0
zitadel_image="ghcr.io/zitadel/zitadel:v2.32.0@sha256:b386deccaa604c0e0274bbb7e06302c11ab89c83f0e60ec031ee0441888fea40"

ZITADEL_PORT="${ZITADEL_PORT:-37837}"
ZITADEL_EXTERNALDOMAIN="chillbox-zitadel"
ZITADEL_FIRSTINSTANCE_ORG_HUMAN_USERNAME="${ZITADEL_FIRSTINSTANCE_ORG_HUMAN_USERNAME:-root}"
ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORD="${ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORD:-RootPassword1!}"
ZITADEL_FIRSTINSTANCE_ORG_NAME="${ZITADEL_FIRSTINSTANCE_ORG_NAME:-ZITADEL}"
is_chillbox_zitadel_running="$(docker inspect --format {{ "'{{.State.Running}}'" }} chillbox-zitadel 2> /dev/null || printf "")"
if [ "$is_chillbox_zitadel_running" != "true" ]; then
  docker run --name chillbox-zitadel \
    -d \
    --tty \
    --env ZITADEL_DATABASE_COCKROACH_HOST="$cockroachdb_host" \
    --env ZITADEL_DATABASE_COCKROACH_PORT="$cockroachdb_port" \
    --env ZITADEL_EXTERNALSECURE="false" \
    --env ZITADEL_EXTERNALPORT="$ZITADEL_PORT" \
    --env ZITADEL_EXTERNALDOMAIN="$ZITADEL_EXTERNALDOMAIN" \
    --env ZITADEL_METRICS_TYPE="none" \
    --env ZITADEL_PORT="$ZITADEL_PORT" \
    --env ZITADEL_MACHINE_IDENTIFICATION_HOSTNAME_ENABLED="true" \
    --env ZITADEL_FIRSTINSTANCE_ORG_HUMAN_USERNAME="$ZITADEL_FIRSTINSTANCE_ORG_HUMAN_USERNAME" \
    --env ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORD="$ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORD" \
    --env ZITADEL_LOG_LEVEL="debug" \
    --env ZITADEL_LOGSTORE_ACCESS_STDOUT_ENABLED="true" \
    --publish "$ZITADEL_PORT":"$ZITADEL_PORT" \
    --network chillboxnet \
    "$zitadel_image" start-from-init --masterkey "MasterkeyNeedsToHave32Characters" --tlsMode disabled
fi

printf "\n%s\n" "Waiting for chillbox-zitadel container to be in running state."
while true; do
  is_chillbox_zitadel_running="$(docker inspect --format {{ "'{{.State.Running}}'" }} chillbox-zitadel 2> /dev/null || printf "")"
  if [ "$is_chillbox_zitadel_running" = "true" ]; then
    printf "."
    has_wget="$(command -v wget)"
    has_curl="$(command -v curl)"
    if [ -n "$has_wget" ]; then
      wget -q -S "http://localhost:$ZITADEL_PORT/debug/healthz" -O /dev/null > /dev/null 2>&1 || continue
    elif [ -n "$has_curl" ]; then
      curl -s -f 'http://localhost:$ZITADEL_PORT/debug/healthz' > /dev/null 2>&1 || continue
    else
      echo "Open http://localhost:$ZITADEL_PORT/debug/healthz in a browser to check if the service is up."
      echo "Zitadel service is up? [y/n]"
      read -r CONTINUE
      if [ "$CONTINUE" != "y" ]; then
        continue
      fi
    fi
    echo ""
    break
  else
    chillbox_zitadel_state="$(docker inspect --format {{ "'{{.State.Status}}'" }} chillbox-zitadel 2> /dev/null || printf "")"
    printf "%s ..." "$chillbox_zitadel_state"
    if [ "$chillbox_zitadel_state" = "exited" ]; then
      docker logs chillbox-zitadel
      exit 1
    fi
  fi
  sleep 0.1
done

has_local_zitadel_hosts="$(getent hosts "$ZITADEL_EXTERNALDOMAIN" || printf "no")"
if [ "$has_local_zitadel_hosts" = "no" ]; then
  echo "WARNING: The /etc/hosts file on your machine does not have an entry for $ZITADEL_EXTERNALDOMAIN domain. The local ZITADEL container will not be accessible until an entry is added to your /etc/hosts file:"
  echo "127.0.0.1       $ZITADEL_EXTERNALDOMAIN"
  echo ""
else
  zitadel_instance="$(printf "$ZITADEL_FIRSTINSTANCE_ORG_NAME" | awk '{print tolower($0)}')"
  echo "Login to local ZITADEL console:"
  echo "  http://$ZITADEL_EXTERNALDOMAIN:$ZITADEL_PORT/ui/console/"
  echo "  username: ${ZITADEL_FIRSTINSTANCE_ORG_HUMAN_USERNAME}@${zitadel_instance}.${ZITADEL_EXTERNALDOMAIN}"
  echo "  password: $ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORD"
fi
