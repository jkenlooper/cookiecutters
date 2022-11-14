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

project_files := package.json Dockerfile package-lock.json postcss.config.js custom-properties-selector.cjs $(shell find src/ -type f)

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

.dist: local-scripts/local-build.sh $(project_files)
	./$< -s $(slugname) -a $(app_name) -p $(project_dir)
	@touch $@

.PHONY: start
start: ## Start local development
	$(project_dir)/local-scripts/local-start.sh -s $(slugname) -a $(app_name) -p $(project_dir)

.PHONY: clean
clean: ## Remove files that were created
	printf '%s\0' $(objects) | xargs -0 rm -r -f
	find dist/ -depth -mindepth 1 -type f -not -name '.gitkeep' -delete
	find dist/ -depth -mindepth 1 -type d -empty -delete
