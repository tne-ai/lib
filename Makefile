
# adjust this for where ./src/lib is and add your own
# Note that current directory is always included so you can
# can insert your own include in the CWD if you want to override
# https://runebook.dev/en/docs/gnu_make/include
.INCLUDE_DIRS ?=  ../lib
# adjust for your org
ORG ?= tne
# Makefile for richtong/lib
#
# Release tag
TAG=0.9

# adjust this for where ./src/lib is
LIB_DIR=.


## Local directory Make commands
## ----------
## test: test the library
.PHONY: test
test:
	@echo "insert test code here..."

## clean: remove the build directory
.PHONY: clean
clean:
	@echo "insert clear code here..."

## all: build all
.PHONY: all

# list these in reverse order so the most general is last
-include include.python.mk


# list these in reverse order so the most general is last

# Adjust these assuming this is a ./src submodule
# https://www.gnu.org/software/make/manual/html_node/Foreach-Function.html
# Note that - means to ignore errors, but this is actually checks
ifneq ($(wildcard include.mk),)
include include.mk
endif

# the first dash means ignore errors
-include include.python.mk
# if you use docker (who doesn't)
-include include.docker.mk
# only include if it exists your companies specific stuff
-include include.jupyter.mk
-include include.node.mk

# rhash is optional for hash checks
# -include include.rhash.mk
# -include include.gcp.base.mk
# -include include.gcp.mk
# -include include.hugo.mk

# these have not been tested in a long time
# - include.airflow.mk

# normally your organization stuff appears last
-include include.$(ORG).mk
