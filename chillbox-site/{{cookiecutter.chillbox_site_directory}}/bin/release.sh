#!/usr/bin/env sh

set -o errexit

projectdir="$(dirname "$(dirname "$(realpath "$0")")")"
script_name="$(basename "$0")"

usage() {
  cat <<HERE

Create the release file from the git repository working directory.

Usage:
  $script_name -h
  $script_name -s <slugname> -t <release_file>

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

test -n "$slugname" || (echo "ERROR $script_name: No slugname set." >&2 && usage && exit 1)
test -n "$release_file" || (echo "ERROR $script_name: No release_file set." >&2 && usage && exit 1)

# release file path should be absolute
release_file="$(realpath "$release_file")"
echo "$release_file" | grep -q "\.tar\.gz$" || (echo "ERROR $script_name: First arg should be an release file ending with .tar.gz" && exit 1)

# Requires this to be a git repository.
test -d "$projectdir/.git" || (echo "ERROR $script_name: Must be a git repository. No directory found at $projectdir/.git" && exit 1)

command -v "git" > /dev/null || (echo "ERROR $script_name: Requires 'git' command." && exit 1)

git_dir_status="$(git status --short)"
if [ -n "$git_dir_status" ]; then
  echo "The git directory is not clean. Some files may be untracked or some files have uncommitted changes."
  echo ""
  echo "$git_dir_status"
  echo ""
  echo "Update the .gitignore for untracked files if applicable."
  echo "ERROR $script_name: Can't create $release_file file because directory is not clean."
  exit 1
fi

create_release() {
  git archive \
    --format=tar.gz \
    --prefix="$slugname/" \
    --output="$release_file" \
    HEAD
}
create_release
