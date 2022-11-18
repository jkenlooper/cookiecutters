#!/usr/bin/env sh
set -o errexit

# {{ cookiecutter.template_file_comment }}
# Version: {{ cookiecutter._version }}

script_name="$(basename "$0")"
script_dir="$(dirname "$(realpath "$0")")"
. "$script_dir/check-in-container.sh"

usage() {
  cat <<HEREUSAGE

Watch for changes in the /build/src directory; build and serve the /build/dist
directory on changes.

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
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))

check_for_required_commands() {
  for required_command in \
    realpath \
    entr \
    ; do
    command -v "$required_command" > /dev/null || (echo "ERROR $script_name: Requires '$required_command' command." >&2 && exit 1)
  done
}

check_in_container "make help"

check_for_required_commands

tmp_watch_files="$(mktemp)"
cleanup() {
  rm -f "$tmp_watch_files"
}
trap cleanup EXIT INT HUP TERM

watch_files() {
  find "/build/src" > "$tmp_watch_files"
  cat "$tmp_watch_files" | entr -rdn "$script_dir/build-serve.sh"
}

while true; do
  set +o errexit
  watch_files
  exit_wf="$?"
  set -o errexit
  if [ "$exit_wf" = "0" ]; then
    echo "INFO $script_name: Exiting."
    exit "$exit_wf"
  elif [ "$exit_wf" = "1" ] || [ "$exit_wf" = "2" ]; then
    echo "INFO $script_name: waiting 2 seconds before watching files again. Hit Ctrl-C to exit."
    sleep 2
  else
    echo "INFO $script_name: Unhandled entr exit status."
    exit "$exit_wf"
  fi
done
