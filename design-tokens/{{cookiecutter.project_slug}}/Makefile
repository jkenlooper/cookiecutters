# {{ cookiecutter.template_file_comment }}
# Version: {{ cookiecutter._version }}

SHELL := sh
.SHELLFLAGS := -o errexit -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
project_dir := $(dir $(mkfile_path))
app_name := $(notdir $(patsubst %/,%,$(project_dir)))
slugname := {{ cookiecutter.slugname }}

DOCKER := docker

project_files := package-lock.json postcss.config.js custom-properties-selector.cjs $(shell find src/ -type f)

# The hash string could be used for cache-busting.
HASH := $(shell cat $(project_files) | md5sum - | cut -d' ' -f1)

# For debugging what is set in variables
inspect.%:
	@printf "%s" '$($*)'

# Always run.  Useful when target is like targetname.% .
# Use $* to get the stem
FORCE:

objects := package-lock.json .dist

.PHONY: all
all: $(objects) ## Default is to make all dist files

.PHONY: help
help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: dist
dist: .dist ## Create dist/* files for distribution

package-lock.json: package.json Dockerfile
	$(DOCKER) image rm $(slugname)-design-tokens-build || printf ""
	DOCKER_BUILDKIT=1 $(DOCKER) build --progress=plain -f $(project_dir)Dockerfile \
		--target build \
		-t $(slugname)-design-tokens-build \
		$(project_dir)
	$(DOCKER) run \
		--name $(slugname)-design-tokens-build \
		$(slugname)-design-tokens-build \
		npm install --ignore-scripts
	$(DOCKER) cp \
		$(slugname)-design-tokens-build:/build/package-lock.json \
		$@
	$(DOCKER) rm \
		$(slugname)-design-tokens-build

.dist: $(project_files)
	rm -rf dist
	$(DOCKER) image rm $(slugname)-design-tokens-build || printf ""
	DOCKER_BUILDKIT=1 $(DOCKER) build --progress=plain -f $(project_dir)Dockerfile \
		--target build \
		-t $(slugname)-design-tokens-build \
		$(project_dir)
	$(DOCKER) run \
		--name $(slugname)-design-tokens-build \
		$(slugname)-design-tokens-build \
		ls -alR /build/dist/
	$(DOCKER) cp \
		$(slugname)-design-tokens-build:/build/dist \
		$(project_dir)
	$(DOCKER) rm \
		$(slugname)-design-tokens-build
	touch $(@)
