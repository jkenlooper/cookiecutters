# {{ cookiecutter.template_file_comment }}

SHELL := sh
.SHELLFLAGS := -o errexit -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
project_dir := $(dir $(mkfile_path))
slugname := {{ cookiecutter.slugname }}

project_files := $(shell find . -type f -not -path './.git/*' -not -path './dist/*' | sort)

# The version string includes the build metadata
VERSION := $(shell cat VERSION)+$(shell cat $(project_files) | md5sum - | cut -d' ' -f1)

# Verify version string compiles with semver.org, output it for chillbox to use.
inspect.VERSION: ## Show the version string along with build metadata
	@printf "%s" '$(VERSION)' | grep -q -P '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$$' - || (printf "\n%s\n" "ERROR Invalid version string '$(VERSION)' See https://semver.org" >&2 && exit 1)
	@printf "%s" '$(VERSION)'

# For debugging what is set in variables.
inspect.%:
	@printf "%s" '$($*)'

# Always run.  Useful when target is like targetname.% .
# Use $* to get the stem
FORCE:

# Chillbox will need the dist/artifact.tar.gz and dist/immutable.tar.gz when
# deploying.
objects := dist/artifact.tar.gz dist/immutable.tar.gz

.PHONY: all
all: $(objects) ## Default is to make all dist files

.PHONY: help
help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: dist
dist: dist/$(slugname)-$(VERSION).tar.gz ## Create release tar.gz file for distribution

# Run the {{ cookiecutter.bin_directory }}/artifact.sh script to create the dist/artifact.tar.gz file.
dist/artifact.tar.gz: {{ cookiecutter.bin_directory }}/artifact.sh
	./$< $(abspath $@)

# Run the {{ cookiecutter.bin_directory }}/immutable.sh script to create the dist/immutable.tar.gz file.
dist/immutable.tar.gz: {{ cookiecutter.bin_directory }}/immutable.sh
	./$< -s $(slugname) -t $(abspath $@) \
		$(project_dir)immutable-example

dist/$(slugname)-$(VERSION).tar.gz: {{ cookiecutter.bin_directory }}/release.sh $(project_files)
	./$< -s $(slugname) -t $(abspath $@)

.PHONY: start
start: ## Start local development
	./{{ cookiecutter.bin_directory }}/local-start.sh

.PHONY: clean
clean: ## Remove files that were created
	printf '%s\0' dist/$(slugname)-$(VERSION).tar.gz $(objects) | xargs -0 rm -f
