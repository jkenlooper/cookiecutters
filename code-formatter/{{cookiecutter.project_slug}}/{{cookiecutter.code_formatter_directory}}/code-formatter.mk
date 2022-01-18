SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
project_dir := $(dir $(mkfile_path))

DOCKER := docker

# For debugging what is set in variables
inspect.%:
	@echo $($*)

# Always run.  Useful when target is like targetname.% .
# Use $* to get the stem
FORCE:

objects := $(project_dir)package-lock.json format

.PHONY: all
all: $(objects)

$(project_dir)package-lock.json: $(project_dir)package.json code-formatter.dockerfile
	$(DOCKER) build -f code-formatter.dockerfile \
		-t {{ cookiecutter.slugname }}-{{ cookiecutter.code_formatter_directory }} \
		./
	$(DOCKER) run \
		--name {{ cookiecutter.slugname }}-{{ cookiecutter.code_formatter_directory }} \
		{{ cookiecutter.slugname }}-{{ cookiecutter.code_formatter_directory }} \
		npm install --ignore-scripts
	$(DOCKER) cp \
		{{ cookiecutter.slugname }}-{{ cookiecutter.code_formatter_directory }}:/code/package-lock.json \
		$@
	$(DOCKER) rm \
		{{ cookiecutter.slugname }}-{{ cookiecutter.code_formatter_directory }}

.PHONY: format
format: $(project_dir)package-lock.json
	$(DOCKER) build -f code-formatter.dockerfile \
		-t {{ cookiecutter.slugname }}-{{ cookiecutter.code_formatter_directory }} \
		./
	$(DOCKER) run -it --rm \
		--mount type=bind,src=$(PWD)/{{ cookiecutter.code_formatter_directory }}/.last-modified,dst=/code/.last-modified \
		{%- for target in cookiecutter.targets.split(' ') %}
		--mount type=bind,src=$(PWD)/{{ target }},dst=/code/{{ target }} \
		{%- endfor %}
		{{ cookiecutter.slugname }}-{{ cookiecutter.code_formatter_directory }} \
		npm run format




