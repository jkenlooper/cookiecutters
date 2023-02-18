SHELL := sh
.SHELLFLAGS := -o errexit -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
project_dir := $(dir $(mkfile_path))
app_name := $(notdir $(patsubst %/,%,$(project_dir)))
slugname := {{ cookiecutter.slugname }}

# The hash string could be used for cache-busting.
HASH := $(shell find . -type f -not -path './.git/*' -not -path './dist/*' -not -path './.dist' -exec md5sum '{}' \; | sort | md5sum - | cut -d' ' -f1)

# For debugging what is set in variables
inspect.%:
	@echo $($*)

# Always run.  Useful when target is like targetname.% .
# Use $* to get the stem
FORCE:

objects := .dist-$(HASH)

.PHONY: all
all: $(objects) ## Default is to make all dist files

.PHONY: help
help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: dist
dist: .dist-$(HASH) ## Create dist/* files

# Run the local-scripts/build.sh script to create the dist/* files.
.dist-$(HASH): local-scripts/local-build.sh
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
