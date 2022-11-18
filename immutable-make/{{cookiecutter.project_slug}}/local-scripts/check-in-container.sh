#!/usr/bin/env sh

set -o errexit

# {{ cookiecutter.template_file_comment }}
# Version: {{ cookiecutter._version }}

check_in_container() {
  if [ -z "$LOCAL_CONTAINER" ] || [ "$LOCAL_CONTAINER" != "yes" ]; then
    echo "LOCAL_CONTAINER is currently set to '$LOCAL_CONTAINER'"
    echo "Failed check if environment variable LOCAL_CONTAINER equals 'yes'."
    echo "WARNING $script_name: Not being started from within a local container. It is recommended to use the following command:"
    echo ""
    echo "$1"
    echo ""
    echo "Continue running $script_name script? [y/n]"
    read -r confirm
    test "$confirm" = "y" || exit 1
  fi
}
