#!/usr/bin/env sh

# {{ cookiecutter.template_file_comment }}

set -o errexit

script_name="$(basename "$0")"

# The .env file is created from chillbox-init.sh script. Using sed here to avoid
# duplicating that list of env variable names here.
env_file="${ENV_FILE-/home/dev/.env}"
chillbox_config_file="${CHILLBOX_CONFIG_FILE-/etc/chillbox/chillbox.config}"

env_names_to_expand="$(sed -n 's/^export \([A-Z_]\+\)=.*/\1/p' "$env_file" "$chillbox_config_file")"
env_names="$(printf "%s" "$env_names_to_expand" | sed 's/./$&/; /\S/!d' | xargs)"

usage() {
  cat <<HERE

A envsubst wrapper to replace variables in stdin with what was defined in the
'env' of a chillbox site configuration file (.site.json). The stdout will be the
replaced text. The variables that will be replaced will also include the
following list and these are required to be set and exported.

    $env_names

Usage:
  $script_name -h
  cat file-with-env-vars.txt | $script_name [<options>] > file.txt

Options:
  -h                  Show this help message.

  -c <config-file>    Path to a chillbox site configuration file (.site.json).

Variables:
  ENV_FILE
  CHILLBOX_CONFIG_FILE

HERE
}

site_json_file=""

while getopts "hc:" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    c) site_json_file=$OPTARG ;;
    ?) usage
       exit 1 ;;
  esac
done

test -n "$site_json_file" || (echo "ERROR $script_name: No site json file set" >&2 && usage && exit 1)
test -f "$site_json_file" || (echo "ERROR $script_name: The site json file at $site_json_file is not a file." >&2 && exit 1)

# Expand and check that all environment variables have been set and have values
# to avoid replacing with empty strings.
for env_var in $env_names; do
  check_var="$(eval "printf \"%s\" \"$env_var\"")"
  test -n "$check_var" || (echo "ERROR $script_name: The environment variable has no value $env_var" >&2 && exit 1)
done

# Export the vars set in the site json 'env' field, and expand any env_names.
# The 'value' field is formatted with the jq '@sh' to prevent execution of
# arbitrary commands in the value by using single quotes around the value.
eval "$(jq -r \
  '.env[] | "export " + .name + "=" + (.value | @sh)' "$site_json_file" \
      | envsubst "$env_names")"

# Update env_names with the set from the site json file.
env_names="$env_names $(jq -r '.env[] | "$" + .name' "$site_json_file" | xargs)"

# Take the input and pass it to envsubst to output the replacement text.
# Allow for double expansion in case the env value uses another env variable.
envsubst "$env_names" | envsubst "$env_names"
