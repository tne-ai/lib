##
## Web Project Commands — SSG-agnostic
## ------------------------------------
## Set WEB_TYPE to: hugo (default), astro, nextjs, sveltekit, nuxt
## Or override individual commands directly via WEB_BUILD_CMD etc.
##
## Hugo-specific targets (make hugo-*) and Astro-specific targets
## (make astro-*) are included when WEB_TYPE matches.
##

SHELL := /usr/bin/env bash

WEB_TYPE         ?= hugo
WEB_PORT         ?= 1313
LIGHTHOUSE_PORT  ?= 8089
# prefer local node_modules install; override if installed globally
LIGHTHOUSE       ?= ./node_modules/.bin/lighthouse

# ── Per-SSG command defaults ──────────────────────────────────────────────────
ifeq ($(WEB_TYPE),hugo)
  WEB_BUILD_CMD      ?= hugo --minify
  WEB_DEV_CMD        ?= hugo server -D --port $(WEB_PORT)
  WEB_DEV_FINAL_CMD  ?= hugo server --port $(WEB_PORT)
  WEB_STOP_PATTERN   ?= hugo server
  WEB_SERVE_DIR      ?= public
else ifeq ($(WEB_TYPE),astro)
  WEB_BUILD_CMD    ?= npm run build
  WEB_DEV_CMD      ?= npm run dev -- --port $(WEB_PORT)
  WEB_STOP_PATTERN ?= astro
  WEB_SERVE_DIR    ?= dist
else ifeq ($(WEB_TYPE),nextjs)
  WEB_BUILD_CMD    ?= npm run build
  WEB_DEV_CMD      ?= npm run dev -- -p $(WEB_PORT)
  WEB_STOP_PATTERN ?= next dev
  WEB_SERVE_DIR    ?= .next
else ifeq ($(WEB_TYPE),sveltekit)
  WEB_BUILD_CMD    ?= npm run build
  WEB_DEV_CMD      ?= npm run dev -- --port $(WEB_PORT)
  WEB_STOP_PATTERN ?= vite
  WEB_SERVE_DIR    ?= build
else ifeq ($(WEB_TYPE),nuxt)
  WEB_BUILD_CMD    ?= npm run build
  WEB_DEV_CMD      ?= npm run dev -- --port $(WEB_PORT)
  WEB_STOP_PATTERN ?= nuxt
  WEB_SERVE_DIR    ?= .output/public
endif

## web-build: production build with minification
.PHONY: web-build
web-build:
	$(WEB_BUILD_CMD)

## web-server: start dev server in background — shows ALL pages including drafts (kills existing first)
.PHONY: web-server
web-server: web-stop
	$(WEB_DEV_CMD) &

## web-final: start dev server showing only published (non-draft) pages — production preview
.PHONY: web-final
web-final: web-stop
	$(WEB_DEV_FINAL_CMD) &

## web-stop: stop the dev server
.PHONY: web-stop
web-stop:
	@pkill -f "$(WEB_STOP_PATTERN)" 2>/dev/null && echo "Stopped $(WEB_TYPE) server." || echo "No server running."

## web-open: open the site in the browser
.PHONY: web-open
web-open:
	@open http://localhost:$(WEB_PORT)/

## web-lighthouse: production build → static serve → Lighthouse audit → open report
.PHONY: web-lighthouse
web-lighthouse: web-build
	@echo "Serving $(WEB_SERVE_DIR)/ on port $(LIGHTHOUSE_PORT)..."
	@python3 -m http.server $(LIGHTHOUSE_PORT) -d $(WEB_SERVE_DIR) &
	@sleep 2
	@$(LIGHTHOUSE) http://localhost:$(LIGHTHOUSE_PORT)/ \
		--output=html \
		--output-path=./lighthouse-report.html \
		--chrome-flags="--headless --no-sandbox" \
		--quiet || true
	@pkill -f "python3 -m http.server $(LIGHTHOUSE_PORT)" 2>/dev/null || true
	@echo "Report: lighthouse-report.html"
	@open ./lighthouse-report.html

# ── Hugo-specific targets ─────────────────────────────────────────────────────
ifeq ($(WEB_TYPE),hugo)

# export HUGO_ENV=docker: to run in docker; unset to run bare metal
HUGO_ENV      ?=
HUGO_REPO     ?= richt
HUGO_IMAGE    ?= hugo
HUGO_VER      ?= 0.81
HUGO_DOCKER   ?= docker run --rm -v $$(pwd):/src
HUGO_FORCE    ?=
HUGO_PORT     ?= $(WEB_PORT)
HUGO_THEME_ORG  ?= richtong
HUGO_THEME      ?= parsa-hugo
HUGO_THEME_PATH ?= github.com/$(HUGO_THEME_ORG)/$(HUGO_THEME)
HUGO_POSTS    ?= posts
HUGO_CONFIG   ?= hugo.yaml

ifeq ($(HUGO_ENV),docker)
  HUGO_RUN = $(HUGO_DOCKER) $(HUGO_REPO)/$(HUGO_IMAGE):$(HUGO_VER)
else
  HUGO_RUN = hugo
endif

## hugo: basic hugo build
.PHONY: hugo
hugo:
	$(HUGO_RUN)

## hugo-build: production build with minification
.PHONY: hugo-build
hugo-build:
	$(HUGO_RUN) --minify

## hugo-new: create a new Hugo site in the current directory
.PHONY: hugo-new
hugo-new:
ifneq ($(HUGO_FORCE),)
	@echo "Removing old files before --force..."
	rm -rf layouts content archetypes themes static data config.toml hugo.toml config
endif
	$(HUGO_RUN) new site . $(if $(HUGO_FORCE),--force) --format yaml

## hugo-theme: add a Hugo module theme to HUGO_CONFIG
.PHONY: hugo-theme
hugo-theme:
	@if ! grep -q "$(HUGO_THEME_PATH)" $(HUGO_CONFIG); then \
		echo "module:" >> $(HUGO_CONFIG) && \
		echo "  imports:" >> $(HUGO_CONFIG) && \
		echo "  - path: \"$(HUGO_THEME_PATH)\"" >> $(HUGO_CONFIG); \
	fi
	@echo "See $(HUGO_THEME_PATH)/exampleSite and copy content, static, data, and parts of $(HUGO_CONFIG)"

## hugo-get: update Go modules and vendor
.PHONY: hugo-get
hugo-get:
	$(HUGO_RUN) mod get -u ./...
	$(HUGO_RUN) mod vendor

## hugo-theme-sub: add theme as a git submodule (deprecated — prefer hugo-theme)
.PHONY: hugo-theme-sub
hugo-theme-sub:
	git submodule add "https://github.com/$(HUGO_THEME_ORG)/$(HUGO_THEME)" "themes/$(HUGO_THEME)" || true
	grep "^theme.*$(HUGO_THEME)" "$(HUGO_CONFIG)" || echo "theme = \"$(HUGO_THEME)\"" >> "$(HUGO_CONFIG)"

## hugo-post: create a new blog post in $(HUGO_POSTS)/
.PHONY: hugo-post
hugo-post:
	$(HUGO_RUN) new $(HUGO_POSTS)/new-post.md

## hugo-content: collect all markdown + config into content.md for RAG
.PHONY: hugo-content
hugo-content:
	find ./config/_default data content -type f -exec cat {} \; > content.md

endif  # WEB_TYPE == hugo

# ── Astro-specific targets ────────────────────────────────────────────────────
ifeq ($(WEB_TYPE),astro)

ASTRO_CMD ?= npx astro

## astro-new: create a new Astro project in ASTRO_DIR (default: current dir)
ASTRO_DIR ?= .
.PHONY: astro-new
astro-new:
	npm create astro@latest $(ASTRO_DIR)

## astro-add: add an Astro integration (set INTEGRATION=react|tailwind|mdx etc.)
INTEGRATION ?=
.PHONY: astro-add
astro-add:
	$(ASTRO_CMD) add $(INTEGRATION)

## astro-check: type-check the project
.PHONY: astro-check
astro-check:
	$(ASTRO_CMD) check

## astro-sync: sync content collections and type definitions
.PHONY: astro-sync
astro-sync:
	$(ASTRO_CMD) sync

endif  # WEB_TYPE == astro

# ── Netlify targets (SSG-agnostic) ────────────────────────────────────────────

## netlify-init: initialize Netlify CLI and link to current repo
.PHONY: netlify-init
netlify-init:
	@if [[ -d .netlify ]]; then netlify link; else netlify init; fi
	netlify env:set GIT_LFS_ENABLED true
	netlify open

## netlify-unlink: disconnect this repo from Netlify
.PHONY: netlify-unlink
netlify-unlink:
	netlify unlink
	netlify logout

## netlify: build locally via Netlify CLI
.PHONY: netlify
netlify:
	netlify build

## netlify-deploy: force a Netlify deployment without a git push
.PHONY: netlify-deploy
netlify-deploy:
	netlify deploy

## netlify-dev: run Netlify local dev environment (deprecated)
.PHONY: netlify-dev
netlify-dev:
	netlify dev
