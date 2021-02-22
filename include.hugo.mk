#
##

# more than 1M pulls so use this
HUGO_REPO ?= jojomi
# kalkegg works
#repo ?= klakegg
HUGO_NAME ?= hugo
#ver ?= 0.74.3
#run ?= docker run --rm -it -v $$(pwd):/src
# https://github.com/jojomi/docker-hugo
# HUGO_WATCH means keep runnig
# without it, will just create the static files
run ?= docker run --rm -v $$(pwd):/src
HUGO_VER ?= 0.76
HUGO_IMAGE ?= "$(HUGO_REPO)/$(HUGO_NAME):$(HUGO_VER)"
# force a change
FORCE ?=
port ?= 1313
theme_org ?= budparr
theme ?= gohugo-theme-ananke


## hugo: make the the site
.PHONY: hugo
hugo:
	$(run) $(HUGO_IMAGE)

## hugo-server: run the site
# Use this line for kalkegg
#$(run) -p $(port):$(port) "$(HUGO_IMAGE)" server
.PHONY: hugo-server
hugo-server:
	$(run) -e HUGO_WATCH=1 -it -p $(port):$(port) "$(HUGO_IMAGE)"

## hugo-new: create a new site
.PHONY: hugo-new
hugo-new:
ifneq ($(FORCE),"")
	@echo even with $(FORCE) need to remove some files
	rm -rf layouts content archetypes themes static data config.toml
endif
	$(run) $(HUGO_IMAGE) hugo new site . $(FORCE)

## hugo-mod: get latest go modules and add to repo
.PHONY: hugo-mod
hugo-mod:
	$(run) $(HUGO IMAGE) mod get -u ./...
	$(run) $(HUGO_IMAGE) mod vendor

## hugo-theme: add a theme (deprecated used hugo-mod instead)
.PHONY: hugo-theme
hugo-theme:
	git submodule add "https://github.com/$(theme_org)/$(theme)" "themes/$(theme)" || true
	grep "$(theme)" config.toml || echo "theme = \"$(theme)\"" >> config.toml

## hugo-post: New blog post
.PHONY: hugo-post
hugo-post:
	$(run) $(image) new posts/$

## netlify: initialize netlify cli and link it to current repo
# https://cli.netlify.com/getting-started
.PHONY: netlify
netlify:
	netlify logout
	netlify login
	if [[ -d .netlify ]]; then netlify link; else netlify init; fi
	netlify env:set GIT_LFS_ENABLED true
	netlify open