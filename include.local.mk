## include.local.mk — lib repo-specific overrides

## test: run all bats unit tests (CI-safe)
.PHONY: test
test:
	bats tests/ --filter-tags unit

## test-all: run every bats test including system-tagged
.PHONY: test-all
test-all:
	bats tests/
