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
  for required_command in \
    realpath \
    find \
    make \
    ; do
    command -v "$required_command" > /dev/null || (echo "ERROR $script_name: Requires '$required_command' command." >&2 && exit "$invalid_errcode")
  done
}

check_in_container "make help"

check_for_required_commands

build_it() {
  if [ ! -d "/build/dist" ]; then
    mkdir -p "/build/dist"
  fi
  chown -R dev:dev /build/dist

  # Only use .mk files from the top level of the project.
  su dev -c "
    find \"/build\" -depth -mindepth 1 -maxdepth 1 -type f -name '*.mk' -print | sort -d -f -r | xargs -n 1 make -C /build -f
  "
}
build_it
