#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"
#projectdir="$(dirname "$(dirname "$(realpath "$0")")")"

usage() {
  cat <<HERE

Create the archive file from the immutable dirs.

Usage:
  $script_name -h
  $script_name -s <slugname> -t <archive_file> <directory> [<directory>..]

Options:
  -h                  Show this help message.

  -s <slugname>       Set the slugname.

  -t <archive_file>   Set the archive tar.gz file to create.

Args:
  <directory>   Create the archive file from the provided directories which
                should each have their own Makefile that creates files in a dist
                directory.

HERE
}

create_archive() {
  archive="$(realpath "$archive_file")"
  echo "$archive" | grep -q "\.tar\.gz$" || (echo "ERROR $script_name: The archive file provided ($archive_file) should end with .tar.gz" >&2 && exit 1)

  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/$slugname"

  for directory in "$@"; do
    test -n "$directory" || continue
    directory_full_path="$(realpath "$directory")"
    test -d "$directory_full_path" || (echo "ERROR $script_name: The provided directory ($directory) is not a directory at $directory_full_path" >&2 && exit 1)
    directory_basename="$(basename "$directory_full_path")"
    hash_string="$(make --silent -C "$directory_full_path" --no-print-directory inspect.HASH)"
    {{ 'test "${#hash_string}" -eq "32" || (echo "ERROR $script_name: The hash string is not 32 characters in length. Did something fail? ($hash_string)" >&2 && exit 1)' }}
    mkdir -p "$tmpdir/$slugname/$directory_basename/$hash_string"
    printf "%s" "$hash_string" > "$tmpdir/$slugname/$directory_basename/hash.txt"
    make -C "$directory_full_path"
    find "$directory_full_path/dist/" -depth -mindepth 1 -maxdepth 1 -exec cp -R {} "$tmpdir/$slugname/$directory_basename/$hash_string/" \;
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

test -n "$slugname" || (echo "ERROR $script_name: No slugname set." >&2 && usage && exit 1)
test -n "$archive_file" || (echo "ERROR $script_name: No archive_file set." >&2 && usage && exit 1)

create_archive "$@"
