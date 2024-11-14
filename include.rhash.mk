##
## Hashing commands
## -------------
# https://rhash.sourceforge.io/manpage.php

## set $(HASH_PATH) to list of files to be hashed, can use wildcards and this is recursive by default
HASH_VOL ?= /Volumes
HASH_NAS ?= Deathstar
HASH_SRC ?= "Movies 4K" "Series 4K" "Personal" "Movies" "Series"

HASH_FILE ?= rhash.sha256.sfv
HASH_CRYPTO ?= --sha3-256


## hash: SHA3-256 hash all files to check they are correct setting $(HASH_FILE)
# note we are not using MD5 or SHA1 because it is stronger than the default
# CRC32
# https://stackoverflow.com/questions/4728810/how-to-ensure-makefile-variable-is-set-as-a-prerequisite/7367903#7367903
.PHONY: hash
hash:
	$(foreach src in $HASH_SRC)
		open smb://$(HASH_NAS)/$$src
		rhash --recursive "$(HASH_CRYPTO)" -P --speed --update="$(HASH_FILE)" $(HASH_VOL)/$$src
	$(endfor)

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
