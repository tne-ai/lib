#
##
## Base commands
## -------------
#
TAG ?= v1
# https://www.gnu.org/software/make/manual/make.html#Flavors
# Use simple expansion for most and not ?= since default is /bin/bash
# which is bash v3 for MacOS
SHELL ?= /usr/bin/env bash
GIT_ORG ?= richtong
SUBMODULE_HOME ?= "$(HOME)/ws/git/src"
NEW_REPO ?=
name ?= $$(basename "$(PWD)")
# if you have include.python installed then it uses the environment but by
# default we assume we are using the raw environment
RUN ?=

.DEFAULT_GOAL := help
.PHONY: help
# https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html does not
# work because we use an include file
# https://swcarpentry.github.io/make-novice/08-self-doc/ is simpler just need
# and it dumpes them out relies on the variable MAKEFILE_LIST which is a list of
# all files note we do not just use $< because this is an include.mk file
## help: available commands (the default)
help: $(MAKEFILE_LIST)
	@sed -n 's/^##//p' $(MAKEFILE_LIST)

## These are required tags from checkmate stubs are here you should overwrite
#.PHONY: test
#test:
#    @echo "test stub"

## tag: pushes a new tag up while delete old to force the action
.PHONY: tag
tag:
	git tag -d "$(TAG)"; \
	git push origin :"$(TAG)" ; \
	git tag -a "$(TAG)" -m "$(COMMENT)" && \
	git push origin "$(TAG)"

## readme: generate toc for markdowns at the top level
.PHONY: readme
readme:
	doctoc *.md

## pre-commit: Run pre-commit hooks and install if not there with update
.PHONY: pre-commit
pre-commit:
	@echo this does not work on WSL so you need to run pre-commit install manually
	if [[ ! -e .pre-commit-config.yaml ]]; then \
		echo "no .pre-commit-config.yaml found copy from ./lib"; \
	else \
		$(RUN) pre-commit autoupdate || true && \
		$(RUN) pre-commit run --all-files || true \
	; fi

## pre-commit-install: Install precommit (get prebuilt .pre-commit-config.yaml from @richtong/lib)
.PHONY: pre-commit-install
pre-commit-install:
	if [[ ! -e .pre-commit-config.yaml ]]; then \
		echo "copy appropriate .pre-commit-config.yaml from ./lib" \
	; else \
		$(RUN) pre-commit install || true && \
		mkdir -p .github/workflows && \
		echo "copy the appropriate ./lib/workflows in .github/workflows" \
		pre-commit install --hook-type commit-msg \
	; fi

## act: Run Github actions as docker job on local machine only works as amd64
.PHONY: act
act:
	act --container-architecture linux/amd64

## git-lfs: installs git lfs
.PHONY: git-lfs
git-lfs:
	$(RUN) git lfs install
	$(RUN) git lfs pull

## repo-install: creates a repo and sets up pre-commits and creates default submodules
.PHONY: repo-install
repo-install: git-lfs pre-commit-install
	$(RUN) for repo in bin lib docker; do git submodule add git@github.com:$(GIT_ORG)/$$repo; done
	$(RUN) git submodule update --init --recursive --remote

## git: createe a git repo
.PHONY: git
git:
ifeq ($(NEW_REPO),)
	@echo "create with NEW_REPO=_name_ make git "
else
	gh repo create git@github.com:$(GIT_ORG)/$(NEW_REPO)
	cd $(SUBMODULE_HOME)
	git submodule add git@github.com:$(GIT_ORG)/$(NEW_REPO)
	cd $(NEW_REPO)
	git init
	cat "## $(ORG) $(name) repo" >> README.md
	git commit -m "README.md first commit"
	git branch -M main
	git push -u origin main
endif

## direnv: creates a new environemnt with direnv and asdf
.PHONY: direnv
direnv:
	touch .envrc
	direnv allow .envrc

## brew-install: install brew packages
# quote needed in case BREW is not set
.PHONY: brew-install
brew-install:
	if [[ -n "$(BREW)" ]]; then \
		brew install $(BREW) \
	; fi

LIB_SOURCE ?= ../../lib
LIB_FILES ?= include.python.mk include.mk
## lib-sync: sync from $(LIB_FILES) from $(LIB) for independent PIP packages
.PHONY: lib-sync
lib-sync:
	for f in $(LIB_FILES); do \
		if [[ -e $(LIB_SOURCE)/$$f ]]; then \
			rsync -av "$(LIB_SOURCE)/$$f" "$$f" \
		; fi \
	; done
