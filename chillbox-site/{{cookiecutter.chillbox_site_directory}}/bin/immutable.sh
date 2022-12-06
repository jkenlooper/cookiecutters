#!/usr/bin/env sh

# {{ cookiecutter.template_file_comment }}

set -o errexit

script_name="$(basename "$0")"

usage() {
  cat <<HERE

Create the archive file from the immutable services defined in the site json file.

Usage:
  $script_name -h
  $script_name -s <slugname> -t <archive_file> <site_json_file>

Options:
  -h                  Show this help message.

  -s <slugname>       Set the slugname.

  -t <archive_file>   Set the archive tar.gz file to create.

Args:
  <site_json_file>    Site json file with 'lang:immutable' services.

HERE
}

create_archive() {
  archive="$(realpath "$archive_file")"
  echo "$archive" | grep -q "\.tar\.gz$" || (echo "ERROR $script_name: The archive file provided ($archive_file) should end with .tar.gz" >&2 && exit 1)

  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/$slugname"

  immutable_services="$(jq -c '.services // [] | .[] | select(.lang == "immutable")' "$site_json_file")"

  IFS="$(printf '\n ')" && IFS="${IFS% }"
  #shellcheck disable=SC2086
  set -f -- $immutable_services
  for immutable_service_json_obj in "$@"; do

    service_name=""
    service_handler=""
    eval "$(echo "$immutable_service_json_obj" | jq -r '@sh "
      service_name=\(.name)
      service_handler=\(.handler)
      "')"
    echo "$service_name"
    directory_full_path="$(realpath "$service_handler")"
    test -d "$directory_full_path" || (echo "ERROR $script_name: The provided service handler ($service_handler) is not a directory at $directory_full_path" >&2 && exit 1)
    hash_string="$(make --silent -C "$directory_full_path" --no-print-directory inspect.HASH)"
    test "${#hash_string}" -eq "32" || (echo "ERROR $script_name: The hash string is not 32 characters in length. Did something fail? ($hash_string)" >&2 && exit 1)
    mkdir -p "$tmpdir/$slugname/$service_name/$hash_string"
    printf "%s" "$hash_string" > "$tmpdir/$slugname/$service_name/hash.txt"
    make -C "$directory_full_path"
    find "$directory_full_path/dist/" -depth -mindepth 1 -maxdepth 1 -exec cp -R {} "$tmpdir/$slugname/$service_name/$hash_string/" \;
  done

  archive_dir="$(dirname "$archive")"
  mkdir -p "$archive_dir"
  tar c \
    -C "$tmpdir" \
    -h \
    -z \
    -f "${archive}" \
    "$slugname"

  # Clean up
  rm -rf "${tmpdir}"
}

slugname=""
archive_file=""

while getopts "hs:t:" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    s) slugname=$OPTARG ;;
    t) archive_file=$OPTARG ;;
    ?) usage
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))

site_json_file="$1"

test -n "$slugname" || (echo "ERROR $script_name: No slugname set." >&2 && usage && exit 1)
test -n "$archive_file" || (echo "ERROR $script_name: No archive_file set." >&2 && usage && exit 1)
test -n "$site_json_file" || (echo "ERROR $script_name: No argument set for the site json file." >&2 && usage && exit 1)
site_json_file="$(realpath "$site_json_file")"
test -f "$site_json_file" || (echo "ERROR $script_name: The $site_json_file is not a file." >&2 && usage && exit 1)

create_archive
