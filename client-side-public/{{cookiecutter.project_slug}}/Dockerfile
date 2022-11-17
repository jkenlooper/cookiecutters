# syntax=docker/dockerfile:1.4.3

# {{ cookiecutter.template_file_comment }}
# Version: {{ cookiecutter._version }}

FROM golang:1.17.6-alpine3.15@sha256:519c827ec22e5cf7417c9ff063ec840a446cdd30681700a16cf42eb43823e27c as build

ARG ESBUILD_VERSION=v0.14.18
ARG ESBUILD_TAR_CHECKSUM=b8c1c195c8c25a10dfff16d4582e222c

WORKDIR /go/src/esbuild

RUN <<INSTALL
apk update
apk add --no-cache \
  jq
INSTALL

RUN <<COMPILE
esbuildtar=$(mktemp)
wget -O "${esbuildtar}" "https://github.com/evanw/esbuild/archive/refs/tags/${ESBUILD_VERSION}.tar.gz"
echo "${ESBUILD_TAR_CHECKSUM} ${esbuildtar}"  | md5sum -c
tar x -z --strip-components 1 -f "${esbuildtar}"
go build ./cmd/esbuild
COMPILE


WORKDIR /build

RUN <<DEV_USER
# Create an unprivileged user that will only have access to /build directory.
addgroup -g 2000 dev
adduser -u 2000 -G dev -s /bin/sh -D dev
chown -R dev:dev /build
DEV_USER

COPY --chown=dev:dev vendor ./vendor
COPY --chown=dev:dev manifest.json .

RUN <<BUILD_VENDOR

set -o errexit

# Execute the commands for each vendor object. Each vendor json object is
# compact (-c) on it's own line so the read can handle it.
jq -c '.vendors[]' manifest.json \
  | while read -r json; do \
    eval $(echo $json | jq -r '@sh "archive=\(.archive)\n checksum=\(.checksum)"')
    missing_files_list="$(mktemp)"
    echo $json | jq -c '.files[]' \
      | while read -r files_obj; do \
        eval $(echo $files_obj | jq -r '@sh "src=\(.src)\n dst=\(.dst)"')
        echo "Checking $dst file"
        test -e "${dst}" || echo "${dst}" >> "${missing_files_list}"
      done
    if [ -n "$(cat ${missing_files_list})" ]; then
      echo "missing files:"
      cat "${missing_files_list}"
      tmptar=$(mktemp)
      tmpdir=$(mktemp -d)
      wget -O "${tmptar}" "${archive}"
      echo "Checking md5sum for archive: ${archive}"
      md5sum "${tmptar}"
      # Use 2 spaces between checksum and tar file.
      echo "${checksum}  ${tmptar}" | md5sum -c
      tar x -z -C "${tmpdir}" --strip-components 1 -f "${tmptar}"
      rm -f "${tmptar}"

      echo $json | jq -c '.files[]' \
        | while read -r files_obj; do \
          eval $(echo $files_obj | jq -r '@sh "src=\(.src)\n dst=\(.dst)"')
          echo "copying source file: ${src} to ${dst}"
          mkdir -p $(dirname "${dst}")
          cp "${tmpdir}/${src}" "${dst}"
        done
    else
      echo "No new files for ${archive}\n"
    fi
  done

chown -R dev:dev vendor/
BUILD_VENDOR

ENV CLIENT_SIDE_PUBLIC_PORT={{ cookiecutter.project_port }}
ENV BIND=0.0.0.0

RUN <<FILEWATCH_SUPPORT

cat <<'DEV_SH' > dev.sh
#!/usr/bin/env sh
set -o errexit
rm -rf dist
echo "Serving main bundle at port $CLIENT_SIDE_PUBLIC_PORT and watching for changes."
/go/src/esbuild/esbuild --bundle --external:/media/* --sourcemap --outdir=dist --serve="$BIND:$CLIENT_SIDE_PUBLIC_PORT" src/main.js
echo "Finished."
DEV_SH

chmod +x dev.sh
chown dev:dev dev.sh
FILEWATCH_SUPPORT

COPY --chown=dev:dev src ./src

USER dev

RUN <<BUILD
# Build the minified production bundle. Ignore build fail so the container can
# be used to troubleshoot when the --target is build.
/go/src/esbuild/esbuild --bundle --external:/media/* --minify --sourcemap --outdir=dist src/main.js || echo "ERROR: build failed"
BUILD

CMD ["./dev.sh"]

### Serve
FROM lipanski/docker-static-website:1.0.0@sha256:ea8516e6b2928c3c1b1c6737f7e32e03b10a04f978080592e61c3dbe2871ff1a

# Try to copy the /build/dist, but fail if the build failed.
COPY --from=build /build/dist /home/static

# Need a Cache-Control:max-age=0 header (thttpd option '-M 0') on all responses.
CMD ["/thttpd", "-D", "-h", "$BIND", "-p", "$CLIENT_SIDE_PUBLIC_PORT", "-d", "/home/static", "-u", "static", "-l", "-", "-M", "0"]
