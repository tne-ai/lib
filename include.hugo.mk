##
## Hugo Commands — backward-compatibility shim
## --------------------------------------------
## Hugo targets are now part of include.web.mk (WEB_TYPE=hugo section).
## This file sets WEB_TYPE=hugo and re-includes include.web.mk so existing
## Makefiles that do `-include include.hugo.mk` continue to work.
##
## Prefer: -include $(LIB_DIR)/include.web.mk  (with WEB_TYPE ?= hugo)
##

SHELL := /usr/bin/env bash

# Set default so include.web.mk picks up Hugo targets
WEB_TYPE ?= hugo

# GIT_PATH is used by some hugo-* targets — requires GIT_ORG and name from include.mk
GIT_PATH ?= github.com/$(GIT_ORG)/$(name)

-include $(dir $(lastword $(MAKEFILE_LIST)))include.web.mk
