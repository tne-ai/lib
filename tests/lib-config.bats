#!/usr/bin/env bats
# lib-config.bats — unit tests for config_profile_* path resolvers in lib-config.sh
# Per r-cto-dev91: static (shellcheck) + behavioral (bats) coverage required.
# Per r-cto-dev148 / r-cto-dev155: these functions encode the shell-file routing
# contract (POSIX .profile vs exportable .bash_profile/.zprofile vs interactive .zshrc).
#
# Run unit only (CI-safe):  bats tests/lib-config.bats --filter-tags unit
# Run via make:             make test-lib-config

setup() {
	LIB_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
	HOME=/tmp/bats-home-fixture
	# shellcheck source=/dev/null
	source "$LIB_DIR/lib-config.sh"
}

# ── exportable vs non-exportable targets (the r-cto-dev148 contract) ──────────

# bats test_tags=unit
@test "config_profile_bash returns POSIX ~/.profile (no op inject allowed)" {
	run config_profile_bash
	[ "$status" -eq 0 ]
	[ "$output" = "$HOME/.profile" ]
}

# bats test_tags=unit
@test "config_profile_exportable_bash returns ~/.bash_profile (bash op inject target)" {
	run config_profile_exportable_bash
	[ "$status" -eq 0 ]
	[ "$output" = "$HOME/.bash_profile" ]
}

# bats test_tags=unit
@test "config_profile_zsh returns ~/.zprofile" {
	run config_profile_zsh
	[ "$status" -eq 0 ]
	[ "$output" = "$HOME/.zprofile" ]
}

# bats test_tags=unit
@test "config_profile_exportable_zsh aliases ~/.zprofile (same file as config_profile_zsh)" {
	run config_profile_exportable_zsh
	[ "$status" -eq 0 ]
	[ "$output" = "$HOME/.zprofile" ]
	[ "$(config_profile_exportable_zsh)" = "$(config_profile_zsh)" ]
}

# bats test_tags=unit
@test "config_profile_nonexportable_zsh returns interactive ~/.zshrc" {
	run config_profile_nonexportable_zsh
	[ "$status" -eq 0 ]
	[ "$output" = "$HOME/.zshrc" ]
}

# bats test_tags=unit
@test "config_profile_nonexportable_bash returns interactive ~/.bashrc" {
	run config_profile_nonexportable_bash
	[ "$status" -eq 0 ]
	[ "$output" = "$HOME/.bashrc" ]
}

# ── invariant: POSIX .profile is never the op-inject (exportable) target ──────

# bats test_tags=unit
@test "exportable targets are never ~/.profile (POSIX sh cannot run op inject)" {
	[ "$(config_profile_exportable_bash)" != "$HOME/.profile" ]
	[ "$(config_profile_exportable_zsh)" != "$HOME/.profile" ]
}

# bats test_tags=unit
@test "config_profile dispatches by shell (zsh vs bash)" {
	ZSH_VERSION=5.9 run config_profile
	[ "$output" = "$HOME/.zprofile" ]
}
