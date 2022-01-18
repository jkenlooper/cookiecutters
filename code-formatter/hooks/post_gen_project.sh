#!/usr/bin/env bash

set -o pipefail
set -o errexit


# Skip over existing files and directories that may already exist from previous
# cookiecutter runs.
if [ ! -e .cookiecutter-config.yaml ]; then
  mv .cookiecutter-config.yaml.cookiecutter_example .cookiecutter-config.yaml
else
  rm .cookiecutter-config.yaml.cookiecutter_example
fi
for example in $(find {{ cookiecutter.code_formatter_directory }} -name '*.cookiecutter_example'); do
  new_item="${example%.cookiecutter_example}"
  if [ ! -e "$new_item" ]; then
    mv $example $new_item
  else
    rm -rf $example
  fi
done

READ_ONLY="{{ cookiecutter._read_only }}"
#echo "Read only:"
#echo "$READ_ONLY" | sed "s/ /\n  /g"
# Switch these to read only as they should only be updated from a cookiecutter file.
chmod u-w {{ cookiecutter.code_formatter_directory }}.dockerfile
for item in $READ_ONLY; do
  chmod --recursive --preserve-root a-w {{ cookiecutter.code_formatter_directory }}/$item
done
