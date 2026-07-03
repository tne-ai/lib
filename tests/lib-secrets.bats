#!/usr/bin/env bats
# lib-secrets.bats — unit tests for op_load_api_keys / op_write_equivalents.
# Per r-cto-dev91: static (shellcheck) + behavioral (bats) coverage required.
#
# Regression anchor: tne-ai/lib#127 — generated `export VAR=op://...` lines MUST
# quote the value, or a multi-line resolved secret (base64 git-crypt key) word-
# splits into `export: not a valid identifier` on every shell startup.
#
# These tests use SECRETS_YAML=fixture and SECRETS_EXPORT_DIRECT=false so no op
# CLI / 1Password / network is required — they assert the GENERATED text only.
#
# Run unit only (CI-safe):  bats tests/lib-secrets.bats --filter-tags unit
# Run via make:             make test-lib-secrets

setup() {
	command -v yq >/dev/null || skip "yq v4 not installed"
	LIB_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
	export SECRETS_YAML="$LIB_DIR/tests/fixtures/api-keys-test.yaml"
	export SECRETS_EXPORT_DIRECT=false
	# shellcheck source=/dev/null
	source "$LIB_DIR/lib-secrets.sh"
}

# ── op_load_api_keys: the quoting contract (regression for #127) ──────────────

# bats test_tags=unit
@test "op_load_api_keys quotes every op:// value" {
	run op_load_api_keys
	[ "$status" -eq 0 ]
	# No line may assign an UNquoted op:// value (i.e. `=op://`); all must be `="op://`.
	if grep -qE '=op://' <<<"$output"; then
		echo "UNQUOTED op:// value found:" >&2
		grep -nE '=op://' <<<"$output" >&2
		return 1
	fi
}

# bats test_tags=unit
@test "op_load_api_keys emits quoted git-crypt key (the #127 break case)" {
	run op_load_api_keys
	[ "$status" -eq 0 ]
	[[ "$output" == *'export TNE_DATA_SENSITIVE_GITCRYPT_KEY="op://Finance/TNE Data Git Crypt Private Key/key"'* ]]
}

# bats test_tags=unit
@test "op_load_api_keys guards each line with [[ -v VAR ]] ||" {
	run op_load_api_keys
	[[ "$output" == *'[[ -v SIMPLE_API_KEY ]] || export SIMPLE_API_KEY='* ]]
}

# bats test_tags=unit
@test "op_load_api_keys wraps disabled_by keys in a flag guard" {
	run op_load_api_keys
	[[ "$output" == *'if [[ ! -v CODEX_CHATGPT ]]; then'*'OPENAI_API_KEY'*'fi'* ]]
}

# bats test_tags=unit
@test "op_load_api_keys skips equivalent_of entries" {
	run op_load_api_keys
	[[ "$output" != *'GOOGLE_API_KEY=op'* ]]
	[[ "$output" != *'export GOOGLE_API_KEY'* ]]
}

# bats test_tags=unit
@test "op_load_api_keys skips disabled:true entries" {
	run op_load_api_keys
	[[ "$output" != *'DEAD_KEY'* ]]
}

# bats test_tags=unit
@test "op_load_api_keys filters to requested env vars" {
	run op_load_api_keys "" SIMPLE_API_KEY
	[[ "$output" == *'SIMPLE_API_KEY'* ]]
	[[ "$output" != *'OPENAI_API_KEY'* ]]
}

# ── op_write_equivalents ──────────────────────────────────────────────────────

# bats test_tags=unit
@test "op_write_equivalents emits VAR=\"\$OTHER\" alias lines" {
	run op_write_equivalents
	[ "$status" -eq 0 ]
	# shellcheck disable=SC2016  # literal match — $GEMINI_API_KEY must NOT expand
	[[ "$output" == *'GOOGLE_API_KEY="$GEMINI_API_KEY"'* ]]
}

# bats test_tags=unit
@test "op_write_equivalents does NOT emit op:// keys" {
	run op_write_equivalents
	[[ "$output" != *'op://'* ]]
}

# ── regression: empty-field column shift (tab-collapse) ───────────────────────
# An equivalent_of entry has an empty op_item. When the parser used tab-delimited
# rows and readers used IFS=$'\t' (tab = IFS-whitespace), consecutive tabs
# collapsed and every column shifted left, so `equivalent` read empty and the
# alias was emitted as a broken `op://<equivalent>/api key/DevOps` ref instead of
# being routed to op_write_equivalents. Parser now uses 0x1F (non-whitespace).

# bats test_tags=unit
@test "regression: equivalent_of alias never becomes an op:// ref" {
	run op_load_api_keys
	# GOOGLE_API_KEY is equivalent_of GEMINI_API_KEY — must NOT appear as op://…
	[[ "$output" != *'op://GEMINI_API_KEY/'* ]]
	[[ "$output" != *'GOOGLE_API_KEY="op://'* ]]
}

# bats test_tags=unit
@test "regression: empty op_item does not shift columns (git-crypt vault stays Finance)" {
	run op_load_api_keys
	# If columns shifted, the vault segment would be wrong. Assert the exact ref.
	[[ "$output" == *'export TNE_DATA_SENSITIVE_GITCRYPT_KEY="op://Finance/TNE Data Git Crypt Private Key/key"'* ]]
}
