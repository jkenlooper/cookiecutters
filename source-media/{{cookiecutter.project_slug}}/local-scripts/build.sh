#!/usr/bin/env sh
set -o errexit

script_name="$(basename "$0")"
invalid_errcode=4

usage() {
  cat <<HEREUSAGE

Build script to create files in the media directory by processing the files in
a src directory.

Usage:
  $script_name -h
  $script_name

Options:
  -h                  Show this help message.

Environment Variables:
  BUILD_SRC_DIR=/build/src
  BUILD_MEDIA_DIR=/build/media


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
    ; do
    command -v "$required_command" > /dev/null || (echo "ERROR $script_name: Requires '$required_command' command." >&2 && exit "$invalid_errcode")
  done
}

check_env_vars() {
  test -n "$BUILD_SRC_DIR" || (echo "ERROR $script_name: No BUILD_SRC_DIR environment variable defined" >&2 && usage && exit "$invalid_errcode")
  test -d "$BUILD_SRC_DIR" || (echo "ERROR $script_name: The BUILD_SRC_DIR environment variable is not set to a directory" >&2 && usage && exit "$invalid_errcode")

  test -n "$BUILD_MEDIA_DIR" || (echo "ERROR $script_name: No BUILD_MEDIA_DIR environment variable defined" >&2 && usage && exit "$invalid_errcode")
}

check_for_required_commands
check_env_vars

build_it() {
  if [ -d "$BUILD_MEDIA_DIR" ]; then
    # Start with a fresh media directory.
    find "$BUILD_MEDIA_DIR" -depth -mindepth 1 -type f -delete
    find "$BUILD_MEDIA_DIR" -depth -mindepth 1 -type d -empty -delete
  else
    mkdir -p "$BUILD_MEDIA_DIR"
  fi

  find "$BUILD_SRC_DIR" -type f -name '*.mk' -print | sort -d -f -r | xargs -n 1 make -C /build -f
}
build_it
