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

.PHONY: all
all: .media


.media: $(shell find ./src -type f)
	DOCKER_BUILDKIT=1 $(DOCKER) build -f $(project_dir)Dockerfile \
		--target build \
		-t $(slugname)-source-media \
		$(project_dir)
	$(DOCKER) run \
		--name $(slugname)-source-media \
		$(slugname)-source-media \
		sh ./make.sh
	$(DOCKER) cp \
		$(slugname)-source-media:/build/media \
		$(project_dir)
	$(DOCKER) rm \
		$(slugname)-source-media
	touch $@


.PHONY: clean
clean:
	rm .media
