##
## Hashing commands
## -------------
#
name ?= $$(basename "$(PWD)")

HASH_FILE ?= ./rhash.sha256.sfv
HASH_CRYPTO ?= --sha3-256

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

## hash: SHA3-256 hash all files to check they are correct
# note we are not using MD5 or SHA1 because it is stronger than the default
# CRC32
# https://stackoverflow.com/questions/4728810/how-to-ensure-makefile-variable-is-set-as-a-prerequisite/7367903#7367903
.PHONY: hash
hash:
	rhash --recursive "$(HASH_CRYPTO)" -P --speed --update="$(HASH_FILE)" ./*

.PHONY: check
## check: check the hash
check:
	rhash --check "$(HASH_FILE)"

.PHONY: missing
## missing: check for files missing in the hashfile
missing:
	rhash --missing="$(HASH_FILE)"
	rhash --unverified="$(HASH_FILE)"

.PHONY: benchmark
## benchmark: benchmark a range of hash functions
benchmark:
	rhash --benchmark --crc32
	rhash --benchmark --sha3-256
	rhash --benchmark --sha3-512
