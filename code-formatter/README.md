# Code Formatter Cookiecutter

Installs [Prettier](https://prettier.io/) and
[Black](https://black.readthedocs.io/en/stable/) in a container that is only
used to format code in the target directories.

```bash
# From the top level of your project directory.
# Overwrite existing files if needed.
cookiecutter --directory code-formatter \
  --overwrite-if-exists \
  https://github.com/jkenlooper/cookiecutters.git \
  targets="$(find . -depth -mindepth 1 -maxdepth 1 -type d \! -name '.*' | sed 's^\./^^g' | xargs)"
```

Then read the generated code-formatter/README.md for running the command to
format the code.
