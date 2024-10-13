##
## Hugo Commands
## -----

SHELL := /usr/bin/env bash
HUGO_REPO ?= richt
# kalkegg works
#repo ?= klakegg
HUGO_IMAGE ?= hugo
#ver ?= 0.74.3
#run ?= docker run --rm -it -v $$(pwd):/src
# https://github.com/jojomi/docker-hugo
# HUGO_WATCH means keep running
# without it, will just create the static files
HUGO_DOCKER ?= docker run --rm -v $$(pwd):/src
HUGO_VER ?= 0.81
HUGO_IMAGE ?= "$(HUGO_REPO)/$(HUGO_IMAGE):$(HUGO_VER)"
# export HUGO_FORCE=--force: to force hugo installation
HUGO_FORCE ?=
# export HUGO_PORT=1313: to change port
HUGO_PORT ?= 1313
# export HUGO_THEME_ORG=themefisher: to change theme github org
HUGO_THEME_ORG ?= richtong
# export HUGO_THEME=parsa_hugo: to change theme
HUGO_THEME ?= parsa-hugo
# Note no https here but it is the path after that
HUGO_THEME_PATH ?= github.com/$(HUGO_THEME_ORG)/$(HUGO_THEME)
# location of blog
HUGO_POSTS ?= posts
# location of configuration which can be config.toml or hugo.{toml,yaml,json}
HUGO_CONFIG ?= hugo.yaml

# this requires variables from include.mk to work like GIT_ORG and name
GIT_PATH ?= github.com/$(GIT_ORG)/$(name)

# export HUGO_ENV=docker: to run in docker
# unset HUGO_ENV: to run bare metal
HUGO_ENV ?=
ifeq ($(HUGO_ENV),docker)
	HUGO_RUN = $(HUGO_DOCKER) $(HUGO_IMAGE)
else
	HUGO_RUN = hugo
endif

## hugo: make the site
.PHONY: hugo
hugo:
	$(HUGO_RUN)

## hugo-server: run the site
# Use this line for kalkegg
#$(run) -p $(HUGO_PORT):$(HUGO_PORT) "$(HUGO_IMAGE)" server
.PHONY: hugo-server
hugo-server:
ifeq ($(HUGO_ENV),docker)
	$(HUGO_DOCKER) -e HUGO_WATCH=1 -it -p $(HUGO_PORT):$(HUGO_PORT) "$(HUGO_IMAGE)"
else
	$(HUGO_RUN) server
endif

## hugo-new: create a new site
# the removes covers old hugo config.toml and new hugo since 0.129
.PHONY: hugo-new
hugo-new:
ifneq ($(HUGO_FORCE),)
	@echo even with $(HUGO_FORCE) need to remove some files
	rm -rf layouts content archetypes themes static data config.toml hugo.toml config
endif
	$(HUGO_RUN) new site . $(if (HUGO_FORCE),--force) --format yaml

# https://www.hugofordevelopers.com/articles/master-hugo-modules-managing-themes-as-modules/
# https://discourse.gohugo.io/t/hugo-modules-for-dummies/20758
# https://geeksocket.in/posts/hugo-modules/
# https://discourse.gohugo.io/t/hugo-mod-get-u-seems-does-not-update-anything-and-modules-get-removed-when-hugo-mod-tidy/45015/10
## hugo-theme: Get a HUGO_THEME as module
# no longer needs this manual add, use the hugo mod -u ./...
# if ! grep -q "$(GIT_PATH)" go.mod; then \
# 	$(HUGO_RUN) mod init "$(GIT_PATH)"; \
	# fi
.PHONY: hugo-theme
hugo-theme:
	if ! grep -q "$(HUGO_THEME_PATH)" $(HUGO_CONFIG); then \
ifneq ($(findstring .toml,$(HUGO_CONFIG),)
		echo "[[module.imports]]\npath = \"$(HUGO_THEME_PATH)\"" >> $(HUGO_CONFIG); \
else
		echo "module:\n  imports:\n  - path: \"$(HUGO_THEME_PATH)\"" >> $(HUGO_CONFIG) && \
endif
	fi
	@echo see $(HUGO_THEME_PATH)/exampleSite and copy content, static and data and parts of $(HUGO_CONFIG)
		echo "  imports:" =
		echo "module = \"$(HUGO_THEME_PATH)\"" >> $(HUGO_CONFIG) && \
endif
	fi
	@echo see $(HUGO_THEME_PATH)/exampleSite and copy content, static and data and parts of $(HUGO_CONFIG)

## hugo-get: get latest go modules and add to repo
.PHONY: hugo-get
hugo-get:
	$(HUGO_RUN) mod get -u ./...
	$(HUGO_RUN) mod vendor

## hugo-theme-sub: add a submodule theme (deprecated)
.PHONY: hugo-theme-sub
hugo-theme-sub:
	git submodule add "https://github.com/$(HUGO_THEME_ORG)/$(HUGO_THEME)" "themes/$(HUGO_THEME)" || true
	grep "^theme.*$(HUGO_THEME)" "$(HUGO_CONFIG)" || echo "theme = \"$(HUGO_THEME)\"" >> "$(HUGO_CONFIG)"

## hugo-post: New blog post in ./posts
.PHONY: hugo-post
hugo-post:
	$(HUGO_RUN) new $(HUGO_POSTS)/$

# https://cli.netlify.com
##
## Netlify
## ---
## netlify: run netlify local dev environment (deprecated)
.PHONY: netlify
netlify:
	netlify dev

## netlify-deploy: force deployment without a push
.PHONY: netlify-deploy
netlify-deploy:
	netlify deploy

## netlify-build: build locally as a test
.PHONY: netlify-build
netlify-build:
	netlify build

## netlify-init: initialize netlify cli and link it to current repo
# https://cli.netlify.com/getting-started
# depends on make auth from include.mk
.PHONY: netlify-init
netlify-init: auth
	if [[ -d .netlify ]]; then netlify link; else netlify init; fi
	netlify env:set GIT_LFS_ENABLED true
	netlify open
