#!/usr/bin/env bash

set -o pipefail
set -o errexit


# Skip over existing files and directories that may already exist from previous
# cookiecutter runs.
for example in $(find . -name '*.cookiecutter_example'); do
  new_item="${example%.cookiecutter_example}"
  if [ ! -e "$new_item" ]; then
    mv $example $new_item
  else
    rm -rf $example
  fi
done

# Still should add template file comment to files that are not rendered.
NO_RENDER_FILES="{% for file in cookiecutter._copy_without_render %}{{ file }} {% endfor %}"
for file in $NO_RENDER_FILES; do
  # TODO This will fail if template_file_comment contains single quotes or
  # other non-compatible characters. The '^' character is used here since it is
  # less likely to conflict with content in template_file_comment.
  sed -i 's^cookiecutter.template_file_comment^{{ cookiecutter.template_file_comment }}^g' $file
done

READ_ONLY="Makefile {{ cookiecutter.bin_directory }}/artifact.sh {{ cookiecutter.bin_directory }}/immutable.sh {{ cookiecutter.bin_directory }}/local-secrets.sh {{ cookiecutter.bin_directory }}/local-start.sh {{ cookiecutter.bin_directory }}/local-stop.sh {{ cookiecutter.bin_directory }}/release.sh {{ cookiecutter.bin_directory }}/utils.sh {{ cookiecutter.bin_directory }}/sleeper.Dockerfile"
#echo "Read only:"
#echo "$READ_ONLY" | sed "s/ /\n  /g"
# Switch these to read only as they should only be updated from a cookiecutter file.
chmod --recursive --preserve-root a-w $READ_ONLY
