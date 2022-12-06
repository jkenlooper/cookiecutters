#!/usr/bin/env sh

set -o errexit

slugname={{ cookiecutter.slugname }}
script_dir="$(dirname "$(realpath "$0")")"
project_dir="$(dirname "${script_dir}")"
script_name="$(basename "$0")"
project_name_hash="$(printf "%s" "$project_dir" | md5sum | cut -d' ' -f1)"
{{ 'test "${#project_name_hash}" -eq "32" || (echo "ERROR $script_name: Failed to create a project name hash from the project dir ($project_dir)" && exit 1)' }}

. "$script_dir/utils.sh"

stop_and_rm_containers_silently "$slugname" "$project_name_hash" chill-dynamic-example api chill-static-example immutable-example nginx
