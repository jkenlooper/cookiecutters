# syntax=docker/dockerfile:1.4.3

# {{ cookiecutter.template_file_comment }}
# Version: {{ cookiecutter._version }}

FROM chill:latest

USER root
RUN <<FILEWATCH_SUPPORT
apk update
apk add --no-cache \
  entr

cat <<'MEOW' > dev.sh
#!/usr/bin/env sh

echo "
chill-data.yaml
site.cfg
" | entr -rzdn chill run
MEOW
chmod +x dev.sh
chown chill:chill dev.sh
FILEWATCH_SUPPORT

COPY --chown=chill:chill . .

ENV PORT={{ cookiecutter.project_port }}
ENV HOST=0.0.0.0

VOLUME /var/lib/chill/sqlite3
VOLUME /home/chill/app

USER chill

ENTRYPOINT ["/bin/sh"]
CMD ["./dev.sh"]
