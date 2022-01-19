#!/usr/bin/env sh

# {{ cookiecutter.template_file_comment }}

{%- for target in cookiecutter.targets.split(' ') %}


## {{ target }}

last_modified_name="{{ target }}"
last_modified_name=$(echo $last_modified_name | sed 's^/^-^g')
if [ -e .last-modified/$last_modified_name-prettier ]; then
  modified_files_prettier=$(find . \( \
      -newer .last-modified/$last_modified_name-prettier \
      -type f -readable -writable \
      -path './{{ target }}/*' \
    \) \( \
      {%- for ext in cookiecutter.prettier_file_type_extensions.split() %}
      {%- if loop.first %}
      -name '*{{ ext }}' \
      {%- else %}
      -o -name '*{{ ext }}' \
      {%- endif %}
      {%- endfor %}
    \) -nowarn \
    || printf '')
else
  modified_files_prettier=$(find . \( \
      -type f -readable -writable \
      -path './{{ target }}/*' \
    \) \( \
      {%- for ext in cookiecutter.prettier_file_type_extensions.split() %}
      {%- if loop.first %}
      -name '*{{ ext }}' \
      {%- else %}
      -o -name '*{{ ext }}' \
      {%- endif %}
      {%- endfor %}
    \) -nowarn \
    || printf '')
  touch .last-modified/$last_modified_name-prettier
fi
if [ -n "$modified_files_prettier" ]; then
  npm run prettier -- --write $modified_files_prettier
  echo "$(date)" > .last-modified/$last_modified_name-prettier
fi

if [ -e .last-modified/$last_modified_name-black ]; then
  modified_files_black=$(find . \( \
      -newer .last-modified/$last_modified_name-black \
      -type f -readable -writable \
      -path './{{ target }}/*' \
    \) \
    -name '*.py' \
    -nowarn \
    || printf '')
else
  modified_files_black=$(find . \( \
      -type f -readable -writable \
      -path './{{ target }}/*' \
    \) \
    -name '*.py' \
    -nowarn \
    || printf '')
  touch .last-modified/$last_modified_name-black
fi
if [ -n "$modified_files_black" ]; then
  black {{ target }}/
  echo "$(date)" > .last-modified/$last_modified_name-black
fi
{%- endfor %}
