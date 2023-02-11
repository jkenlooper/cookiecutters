#!/usr/bin/env sh

set -o errexit

script_dir="$(dirname "$(realpath "$0")")"
script_name="$(basename "$0")"

echo "INFO $script_name: Updating redis.conf.patch file."

# UPKEEP due: "2023-08-09" label: "Redis 7.0 configuration" interval: "+6 months"
# https://raw.githubusercontent.com/redis/redis/7.0/00-RELEASENOTES
# https://download.redis.io/releases/
wget -O "$script_dir/redis.conf" "https://raw.githubusercontent.com/redis/redis/7.0/redis.conf"

# Avoid needing to store the whole config file by recreating it.
test -e "$script_dir/chillbox.redis.conf" \
  || patch -i "$script_dir/{{cookiecutter.chillbox_site_directory}}/redis/redis.conf.patch" -o "$script_dir/chillbox.redis.conf" "$script_dir/redis.conf"

# Prevent manual changes by keeping it read only.
chmod u+w "$script_dir/{{cookiecutter.chillbox_site_directory}}/redis/redis.conf.patch"
diff -w -u --label redis.conf --label chillbox.redis.conf "$script_dir/redis.conf" "$script_dir/chillbox.redis.conf" > "$script_dir/{{cookiecutter.chillbox_site_directory}}/redis/redis.conf.patch" || printf ""
chmod a-w "$script_dir/{{cookiecutter.chillbox_site_directory}}/redis/redis.conf.patch"

echo "INFO $script_name: Verifying that patch file can be applied."
tmp_conf="$(mktemp)"
patch -i "$script_dir/{{cookiecutter.chillbox_site_directory}}/redis/redis.conf.patch" -o "$tmp_conf" "$script_dir/redis.conf"
diff -w "$script_dir/chillbox.redis.conf" "$tmp_conf"
rm -f "$tmp_conf"
rm -f "$script_dir/redis.conf"
