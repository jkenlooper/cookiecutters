#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

READ_ONLY="Makefile {{ cookiecutter.bin_directory }}/artifact.sh {{ cookiecutter.bin_directory }}/immutable.sh {{ cookiecutter.bin_directory }}/local-secrets.sh {{ cookiecutter.bin_directory }}/local-start.sh {{ cookiecutter.bin_directory }}/local-stop.sh {{ cookiecutter.bin_directory }}/release.sh {{ cookiecutter.bin_directory }}/utils.sh {{ cookiecutter.bin_directory }}/sleeper.Dockerfile"
#echo "Read only:"
#echo "$READ_ONLY" | sed "s/ /\n  /g"
# Switch these back to writable if they exist so they can be updated when
# generating the files.
for item in $READ_ONLY; do
  if [ -e $item ]; then
    chmod --recursive --preserve-root u+w $item
  fi
done
