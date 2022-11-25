# Makefile for richtong/lib
#
# Release tag
TAG=0.9

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

include include.python.mk
include include.mk
