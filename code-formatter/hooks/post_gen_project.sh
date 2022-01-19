#!/usr/bin/env bash

set -o pipefail
set -o errexit


# Skip over existing files and directories that may already exist from previous
# cookiecutter runs.
for file in .cookiecutter-config.yaml.cookiecutter_example .editorconfig.cookiecutter_example .flake8.cookiecutter_example .prettierrc.cookiecutter_example .stylelintrc.cookiecutter_example; do
  if [ ! -e "${file%.cookiecutter_example}" ]; then
    mv $file ${file%.cookiecutter_example}
  else
    rm $file
  fi
done
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
