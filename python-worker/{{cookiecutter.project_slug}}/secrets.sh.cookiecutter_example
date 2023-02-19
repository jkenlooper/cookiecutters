#!/usr/bin/env sh

set -o errexit

output_file="$1"
test -n "$output_file" || (echo "No output file argument was set." && exit 1)
test -w "$output_file" || (echo "Can't write to file $output_file" && exit 1)


printf "Prompt for adding secrets. The input is hidden."
printf "\n\n"

printf "\nTODO: prompt for a secret here: "
stty -echo
read -r example_secret
stty echo

printf "\nAll done."
printf "\n\n"

cat <<SECRETS > "$output_file"
EXAMPLE_SECRET="$example_secret"
SECRETS
