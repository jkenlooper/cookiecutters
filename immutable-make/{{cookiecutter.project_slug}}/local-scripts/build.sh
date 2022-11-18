#!/usr/bin/env sh
set -o errexit

# {{ cookiecutter.template_file_comment }}
# Version: {{ cookiecutter._version }}

script_name="$(basename "$0")"
script_dir="$(dirname "$0")"
. "$script_dir/check-in-container.sh"
invalid_errcode=4

usage() {
  cat <<HEREUSAGE

Build script to create files in the dist directory by processing the files in
a src directory.

Usage:
  $script_name -h
  $script_name

Options:
  -h                  Show this help message.

HEREUSAGE
}

while getopts "h" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    ?) usage
       exit "$invalid_errcode" ;;
  esac
done
shift $((OPTIND - 1))

check_for_required_commands() {
  # This simple example only requires commands that are probably already part of
  # the system (realpath, cp, find).
  for required_command in \
    realpath \
    cp \
    find \
    make \
    ; do
    command -v "$required_command" > /dev/null || (echo "ERROR $script_name: Requires '$required_command' command." >&2 && exit "$invalid_errcode")
  done
}

check_in_container "make help"

check_for_required_commands

build_it() {
  # For this example it is only copying the files from the src directory to the
  # dist directory.
  if [ -d "/build/dist" ]; then
    # Start with a fresh dist directory.
    find "/build/dist" -depth -mindepth 1 -type f -delete
    find "/build/dist" -depth -mindepth 1 -type d -empty -delete
  else
    mkdir -p "/build/dist"
  fi

  # Only use .mk files from the top level of the project.
  find "/build" -depth -mindepth 1 -maxdepth 1 -type f -name '*.mk' -print | sort -d -f -r | xargs -n 1 make -C /build -f
}
build_it
