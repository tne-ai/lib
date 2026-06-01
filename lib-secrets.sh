#!/usr/bin/env bash
# vim: ai:sw=4:ts=4:noet
##
## 1Password API key loading from api-keys.yaml.
## Generic — no AI-provider logic. Source before lib-ai.sh.
## Requires: op CLI (1Password v2), yq v4

lib_name="$(basename "${BASH_SOURCE%.*}")"
lib_name="${lib_name//-/_}"
if eval "[[ -z \${$lib_name+x} ]]"; then
	eval "$lib_name=true"

	_SECRETS_YAML="${SECRETS_YAML:-$(dirname "${BASH_SOURCE[0]}")/api-keys.yaml}"

	# ── YAML parser ───────────────────────────────────────────────────────────────
	# Parses api-keys.yaml; prints TSV rows to stdout.
	# Columns: env_var op_item op_field op_vault disabled_by equivalent_of
	# Args: [yaml_file] [env_var_filter...]
	_secrets_parse_yaml() {
		local yaml_file="${1:-$_SECRETS_YAML}"
		shift
		local -a filter=("$@")

		local key_filter=""
		if [[ ${#filter[@]} -gt 0 ]]; then
			local conditions
			conditions=$(printf ' or .key == "%s"' "${filter[@]}")
			key_filter="| select(${conditions# or })"
		fi

		yq e "to_entries | .[] ${key_filter}
			| select(.value | type == \"!!map\")
			| select(.value.disabled != true)
			| select((.value.op_item != null) or (.value.equivalent_of != null))
			| [.key,
			   (.value.op_item // \"\"),
			   (.value.op_field // \"api key\"),
			   (.value.op_vault // \"DevOps\"),
			   (.value.disabled_by // \"\"),
			   (.value.equivalent_of // \"\")]
			| @tsv" "$yaml_file"
	}

	# ── op_load_api_keys ──────────────────────────────────────────────────────────
	# Write op:// references for each key into a shell profile, or export directly.
	# Skips entries with equivalent_of — use op_write_equivalents for those.
	#
	# Usage: op_load_api_keys [profile_file] [env_var...]
	#   profile_file  — path containing / ; file to append lines to (default: stdout)
	#   env_var...    — optional filter; loads all non-disabled keys if omitted
	#
	# SECRETS_EXPORT_DIRECT=true: calls `op item get` and exports to current shell.
	# Default: writes `export VAR=op://Vault/Item/Field` for use inside op inject.
	op_load_api_keys() {
		local profile_file=""
		local -a filter_vars=()

		if [[ $# -gt 0 && "$1" == */* ]]; then
			profile_file="$1"
			shift
		fi
		filter_vars=("$@")

		local _out
		_out=$(_secrets_parse_yaml "$_SECRETS_YAML" "${filter_vars[@]}") || {
			echo "op_load_api_keys: failed to parse $_SECRETS_YAML" >&2
			return 1
		}

		while IFS=$'\t' read -r env_var op_item op_field op_vault disabled_by equivalent; do
			[[ -z "$env_var" ]] && continue
			# equivalents go in op_write_equivalents, not here
			[[ -n "$equivalent" ]] && continue
			[[ -z "$op_item" ]] && continue

			local op_ref="op://${op_vault}/${op_item}/${op_field}"

			if [[ "${SECRETS_EXPORT_DIRECT:-false}" == "true" ]]; then
				[[ -v "$env_var" ]] && continue
				[[ -n "$disabled_by" && -n "${!disabled_by:-}" ]] && continue
				local val
				val=$(op item get "$op_item" --fields "label=$op_field" \
					--vault "$op_vault" --reveal 2>/dev/null) || {
					echo "op_load_api_keys: warning — could not get $env_var" >&2
					continue
				}
				export "$env_var=$val"
			else
				# Profile injection — write op:// reference
				local line="[[ -v ${env_var} ]] || export ${env_var}=${op_ref}"
				if [[ -n "$disabled_by" ]]; then
					line="if [[ ! -v ${disabled_by} ]]; then ${line}; fi"
				fi
				if [[ -n "$profile_file" ]]; then
					printf '%s\n' "$line" >>"$profile_file"
				else
					printf '%s\n' "$line"
				fi
			fi
		done <<<"$_out"
	}

	# ── op_write_equivalents ──────────────────────────────────────────────────────
	# Write VAR="$OTHER_VAR" lines for entries with equivalent_of set.
	# These go OUTSIDE the op inject block in the shell profile.
	# Args: [profile_file]
	op_write_equivalents() {
		local profile_file="${1:-}"
		local _out
		_out=$(_secrets_parse_yaml "$_SECRETS_YAML") || return 1

		while IFS=$'\t' read -r env_var _item _field _vault _disabled_by equivalent; do
			[[ -z "$equivalent" ]] && continue
			local line="${env_var}=\"\$${equivalent}\""
			if [[ -n "$profile_file" ]]; then
				printf '%s\n' "$line" >>"$profile_file"
			else
				printf '%s\n' "$line"
			fi
		done <<<"$_out"
	}

	# ── op_check_key_set ──────────────────────────────────────────────────────────
	# Warn for each env var that is unset or empty.
	# Args: env var names to check (checks all with op_item if omitted)
	# Returns 1 if any are missing, 0 if all set.
	op_check_key_set() {
		local -a vars=("$@")
		local missing=0

		if [[ ${#vars[@]} -eq 0 ]]; then
			local _out
			_out=$(_secrets_parse_yaml "$_SECRETS_YAML") || return 1
			while IFS=$'\t' read -r env_var _rest; do
				[[ -z "$env_var" ]] && continue
				vars+=("$env_var")
			done <<<"$_out"
		fi

		for v in "${vars[@]}"; do
			if [[ -z "${!v:-}" ]]; then
				echo "op_check_key_set: $v is not set" >&2
				missing=1
			fi
		done
		return "$missing"
	}

fi
