#!/usr/bin/env sh

# {{ cookiecutter.template_file_comment }}

set -eu -o pipefail

rm -rf tmp/
mkdir -p tmp/

themes_settings=$(find src -depth -mindepth 2 -maxdepth 2 -type f -name settings.yaml)

for settings_path in $themes_settings; do
  # Get just the theme name by removing first and last part of the settings_path.
  theme_name=${settings_path##src/}
  theme_name=${theme_name%/settings.yaml}

  # Generate the tmp/${theme_name}/settings.custom-properties-selector.css file.
  theo $settings_path \
    --setup custom-properties-selector.cjs \
    --transform web \
    --format custom-properties-selector.css \
    --dest tmp/$theme_name
done
