#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

READ_ONLY="{{ cookiecutter._read_only }}"
#echo "Read only:"
#echo "$READ_ONLY" | sed "s/ /\n  /g"
# Switch these back to writable if they exist so they can be updated when
# generating the files.
if [ -e {{ cookiecutter.code_formatter_directory }}.dockerfile ]; then
  chmod u+w {{ cookiecutter.code_formatter_directory }}.dockerfile
fi
for item in $READ_ONLY; do
  if [ -e {{ cookiecutter.code_formatter_directory }}/$item ]; then
    chmod --recursive --preserve-root u+w {{ cookiecutter.code_formatter_directory }}/$item
  fi
done
