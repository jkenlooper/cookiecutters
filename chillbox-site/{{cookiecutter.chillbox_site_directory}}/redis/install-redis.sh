#!/usr/bin/env sh

# {{ cookiecutter.template_file_comment }}

set -o errexit

script_name="$(basename "$0")"
script_dir="$(dirname "$0")"

apk add \
  coreutils \
  dpkg-dev dpkg \
  gcc \
  linux-headers \
  make \
  musl-dev \
  tcl \
  openssl \
  openssl-dev

# UPKEEP due: "2023-08-09" label: "Redis" interval: "+6 months"
# https://raw.githubusercontent.com/redis/redis/7.0/00-RELEASENOTES
# https://download.redis.io/releases/
redis_version="7.0.8"
redis_checksum="d760fce02203265551198082f75b1e6be78a2cdb3d464e518d65a31839a3b6e45401c6bca6a091f59e121212aee7363d5e83c25365ab347a66b807015b32eeb6"
tmp_tar="$(mktemp)"
wget -O "$tmp_tar" -q "https://download.redis.io/releases/redis-$redis_version.tar.gz"
sha512sum "$tmp_tar"
echo "$redis_checksum  $tmp_tar" | sha512sum -c \
  || ( \
    echo "Cleaning up in case errexit is not set." \
    && rm -f "$tmp_tar" \
    && exit 1 \
    )

mkdir -p /usr/local/src/redis


tar x -z -f "$tmp_tar" -C /usr/local/src/redis --strip-components=1
rm -f "$tmp_tar"

export CFLAGS="$CFLAGS -DUSE_MALLOC_USABLE_SIZE"
make USE_JEMALLOC=no \
      MALLOC=libc \
      -C /usr/local/src/redis \
      all

# Should at least run the test anytime that the version is updated.
if [ "$redis_version" != "7.0.8" ]; then
  make \
    -C /usr/local/src/redis \
    test
fi

make \
  -C /usr/local/src/redis \
  install PREFIX=/usr INSTALL_BIN="/usr/local/bin"

redis-server --version
redis-cli --version
