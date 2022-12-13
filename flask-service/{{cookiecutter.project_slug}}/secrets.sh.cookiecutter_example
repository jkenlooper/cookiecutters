#!/usr/bin/env sh

set -o errexit

output_file="$1"
test -n "$output_file" || (echo "No output file argument was set." && exit 1)
test -w "$output_file" || (echo "Can't write to file $output_file" && exit 1)


# Change this script to prompt the user for secrets.

printf "Example of prompt for adding secrets. The input is hidden."
printf "\n\n"

printf "\nQuestion 1: "
stty -echo
read first_answer
stty echo

printf "\nQuestion 2: "
stty -echo
read second_answer
stty echo

printf "\nQuestion 5: "
stty -echo
read fifth_answer
stty echo

printf "\nAll done."
printf "\n\n"

cat <<SECRETS > "$output_file"
ANSWER1="$first_answer"
ANSWER2="$second_answer"
ANSWER5="$fifth_answer"
SECRETS
