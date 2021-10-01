##
## Node.js Commands
## -------------------
# Configure by setting PIP for pip packages and optionally name
# requires include.mk
#
# Remember makefile *must* use tabs instead of spaces so use this vim line
#
# The makefiles are self documenting, you use two leading
# for make help to produce output
#
# These should be overridden in the makefile that includes this, but this sets
# defaults use to add comments when running make help
#
FLAGS ?=
SHELL ?= /usr/bin/env bash
# does not work the excluded directories are still listed
# https://www.theunixschool.com/2012/07/find-command-15-examples-to-exclude.html
# exclude := -type d \( -name extern -o -name .git \) -prune -o
# https://stackoverflow.com/questions/4210042/how-to-exclude-a-directory-in-find-command
name ?= $$(basename $(PWD))

NPM ?=
# These cannot be installed in the environment must use pip install
# Beware that this affects the overall system use only for system commmands
NPM_GLOBAL ?=

MACOS_VERSION ?= $(shell sw_vers -productVersion)

# https://github.com/nodenv/nodenv/wiki/Alternatives
# there seems to be no clean pipenv like configuration for node apps
# where you can just locally install commands and access them at ./.bin
# asdf works for node and other applications
# n - just works for node version not for packages locally that have cli's
# nave - does npm version and also global npm installations
# nenv - Node version only
# nodebrew - written in perl (yuck) just for node versions
# nodenv - relatively old

# https://www.technologyscout.net/2017/11/how-to-install-dependencies-from-a-requirements-txt-file-with-conda/
## npm-install: Install Node packages locally
.PHONY: npm-install
npm-install:
	npm install $(NPM)

## npm-install-g: Install Node command line packages globally (unless asdf detected)
.PHONY: npm-install-g
npm-install-g:
	npm install -g $(NPM_GLOBAL) && \
	if command -v asdf > /dev/null; then \
		asdf reshim nodejs; \
	fi

## node-asdf: Install local node version
.PHONY: node-asdf
node-asdf:
	asdf local nodejs latest
