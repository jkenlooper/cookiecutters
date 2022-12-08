#!/usr/bin/env sh

# {{ cookiecutter.template_file_comment }}

set -o errexit

script_name="$(basename "$0")"

usage() {
  cat <<HERE

Stop local running containers for this site.

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

while getopts "hs:t:" OPTION ; do
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

script_dir="$(dirname "$(realpath "$0")")"
project_dir="$(dirname "${script_dir}")"
script_name="$(basename "$0")"
project_name_hash="$(printf "%s" "$project_dir" | md5sum | cut -d' ' -f1)"
{{ 'test "${#project_name_hash}" -eq "32" || (echo "ERROR $script_name: Failed to create a project name hash from the project dir ($project_dir)" && exit 1)' }}
. "$script_dir/utils.sh"

stop_and_rm_containers_silently "$slugname" "$project_name_hash" "$site_json_file"
