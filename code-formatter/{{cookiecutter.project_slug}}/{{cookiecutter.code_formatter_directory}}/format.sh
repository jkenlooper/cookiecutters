#!/usr/bin/env sh

{%- for target in cookiecutter.targets.split(' ') %}
## {{ target }}
last_modified_name="{{ target }}"
last_modified_name=$(echo $last_modified_name | sed 's^/^-^g')
modified_files_prettier=$(find . \( -newer .last-modified/$last_modified_name-prettier -type f -path './{{ target }}/*' \) \( -name '*.js' -o -name '*.css' -o -name '*.md' -o -name '*.html' -o -name '*.json' -o -name '*.yaml' -o -name '*.yml' \) || printf '')
if [ -n "$modified_files_prettier" ]; then
  npm run prettier -- --write $modified_files_prettier
  echo "$(date)" > .last-modified/$last_modified_name-prettier
fi

modified_files_black=$(find . \( -newer .last-modified/$last_modified_name-black -type f -path './{{ target }}/*' \) -name '*.py' || printf '')
if [ -n "$modified_files_black" ]; then
  black {{ target }}/
  echo "$(date)" > .last-modified/$last_modified_name-black
fi
{% endfor %}



