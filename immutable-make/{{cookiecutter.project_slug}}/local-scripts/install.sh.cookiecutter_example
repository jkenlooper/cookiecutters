#!/usr/bin/env sh
set -o errexit

script_name="$(basename "$0")"
script_dir="$(dirname "$(realpath "$0")")"

# Should only be executed from within the Dockerfile.
. "$script_dir/check-in-container.sh"
check_in_container "make help"




######################################################################################
echo "
TODO $script_name: Change the commands here to be whatever is needed for this particular build.
"
######################################################################################

# Include any of the extra dependencies needed for this particular build. The
# example here is including the imagemagick package so commands like 'convert'
# and 'identify' can be used.

# apk update
# apk add --no-cache \
#   imagemagick
