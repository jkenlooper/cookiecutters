# {{ cookiecutter.template_file_comment }}
# Version: {{ cookiecutter._version }}

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
project_dir := $(dir $(mkfile_path))
slugname := {{ cookiecutter.slugname }}

DOCKER := docker

# For debugging what is set in variables
inspect.%:
	@echo $($*)

# Always run.  Useful when target is like targetname.% .
# Use $* to get the stem
FORCE:

objects := .vendor .dist

.PHONY: all
all: $(objects)

.vendor: manifest.json Dockerfile
	chmod -R u+w vendor/
	rm -rf vendor
	mkdir -p vendor
	$(DOCKER) image rm "$(slugname)-{{ cookiecutter.project_slug }}" || printf ""
	DOCKER_BUILDKIT=1 $(DOCKER) build -f $(project_dir)Dockerfile \
		--target build \
		-t $(slugname)-{{ cookiecutter.project_slug }} \
		$(project_dir)
	$(DOCKER) run \
		--name $(slugname)-{{ cookiecutter.project_slug }} \
		$(slugname)-{{ cookiecutter.project_slug }} \
		ls /build/vendor/
	$(DOCKER) cp \
		$(slugname)-{{ cookiecutter.project_slug }}:/build/vendor ./
	chmod -R u-w vendor/
	$(DOCKER) rm \
		$(slugname)-{{ cookiecutter.project_slug }}
	touch $@

.dist: .vendor $(shell find src/ -type f)
	$(DOCKER) image rm "$(slugname)-{{ cookiecutter.project_slug }}" || printf ""
	DOCKER_BUILDKIT=1 $(DOCKER) build -f $(project_dir)Dockerfile \
		--target build \
		-t $(slugname)-{{ cookiecutter.project_slug }} \
		$(project_dir)
	rm -rf dist
	$(DOCKER) run \
		--name $(slugname)-{{ cookiecutter.project_slug }} \
		$(slugname)-{{ cookiecutter.project_slug }} \
		ls dist
	$(DOCKER) cp \
		$(slugname)-{{ cookiecutter.project_slug }}:/build/dist \
		./
	$(DOCKER) rm \
		$(slugname)-{{ cookiecutter.project_slug }}
	touch $@
