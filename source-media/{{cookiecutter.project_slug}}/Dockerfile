# syntax=docker/dockerfile:1.3.0-labs

FROM python:3.10.0-buster as build

ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /build

RUN <<INSTALL
apt-get --yes update
apt-get --yes upgrade
apt-get --yes install --no-install-suggests --no-install-recommends \
  imagemagick
# Create an unprivileged user.
adduser dev --disabled-login --disabled-password --gecos ""

# The .tmp/ directory is for storing intermediate files from other *.mk files.
mkdir -p .tmp

# The media/ directory will contain the generated files.
mkdir -p media

chown -R dev:dev /build/media .tmp
INSTALL

RUN <<FILEWATCH_SUPPORT
apt-get --yes update
apt-get --yes install --no-install-suggests --no-install-recommends \
  entr

cat <<'HISS' > make.sh
#!/usr/bin/env sh
source_media_mk=$(find ./ -type f -name '*.mk' -print | sort --dictionary-order --ignore-case --reverse)
for mk in $source_media_mk; do
  make -f ${mk}
done
HISS
chmod +x make.sh
chown dev:dev make.sh

cat <<'GROWL' > make-and-serve.sh
#!/usr/bin/env sh
./make.sh
cd /build/media
python -m http.server 8080
GROWL
chmod +x make-and-serve.sh
chown dev:dev make-and-serve.sh

cat <<'MEOW' > dev.sh
#!/usr/bin/env sh
rm -f .tmp/watch_files
find . -depth -mindepth 2 -type f ! -path './media/*' > .tmp/watch_files
cat .tmp/watch_files | entr -rdn ./make-and-serve.sh
MEOW
chmod +x dev.sh
chown dev:dev dev.sh

FILEWATCH_SUPPORT

# Only the src/ directory is copied to the container.
COPY --chown=dev:dev src ./src

RUN ./make.sh

USER dev

CMD ["./dev.sh"]

### Serve
FROM lipanski/docker-static-website:1.0.0@sha256:ea8516e6b2928c3c1b1c6737f7e32e03b10a04f978080592e61c3dbe2871ff1a

EXPOSE 8080

COPY --from=build /build/media /home/static

# Need a Cache-Control:max-age=0 header (thttpd option '-M 0') on all responses.
CMD ["/thttpd", "-D", "-h", "0.0.0.0", "-p", "8080", "-d", "/home/static", "-u", "static", "-l", "-", "-M", "0"]
