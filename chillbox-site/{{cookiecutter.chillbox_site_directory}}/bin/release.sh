#!/usr/bin/env sh

# {{ cookiecutter.template_file_comment }}

set -o errexit

projectdir="$(dirname "$(dirname "$(realpath "$0")")")"
script_name="$(basename "$0")"

usage() {
  cat <<HERE

Create the release file from the project working directory. Provide file paths
as args if only needing certain files and directories added to archive file.

Usage:
  $script_name -h
  $script_name -s <slugname> -t <release_file>
  $script_name -s <slugname> -t <release_file> [file paths...]

Options:
  -h                  Show this help message.

  -s <slugname>       Set the slugname.

  -t <release_file>   Set the release tar.gz file to create.

HERE
}

slugname=""
release_file=""

while getopts "hs:t:" OPTION ; do
  case "$OPTION" in
    h) usage
       exit 0 ;;
    s) slugname=$OPTARG ;;
    t) release_file=$OPTARG ;;
    ?) usage
       exit 1 ;;
  esac
done
shift $((OPTIND - 1))

other_file_paths="$*"

test -n "$slugname" || (echo "ERROR $script_name: No slugname set." >&2 && usage && exit 1)
test -n "$release_file" || (echo "ERROR $script_name: No release_file set." >&2 && usage && exit 1)

# release file path should be absolute
release_file="$(realpath "$release_file")"
echo "$release_file" | grep -q "\.tar\.gz$" || (echo "ERROR $script_name: Should be a release file ending with .tar.gz" && exit 1)

create_release() {
  tmp_release_dir="$(mktemp -d)"
  mkdir "$tmp_release_dir/$slugname"
  if [ -z "$other_file_paths" ]; then
    find "$projectdir" -depth -maxdepth 1 -mindepth 1 \! -name '.git' \! -name '.hg' -exec cp -R {} -t "$tmp_release_dir/$slugname" \;
  else
    for fp in $other_file_paths; do
      test -e "$projectdir/$fp" || (echo "ERROR $script_name: No file or directory at $projectdir/$fp" && exit 1)
      cp -R "$projectdir/$fp" -t "$tmp_release_dir/$slugname"
    done
  fi
  tar -c -f "$release_file" \
    -C "$tmp_release_dir" \
    "$slugname"
  rm -rf "$tmp_release_dir"
}
create_release
