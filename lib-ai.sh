#!/usr/bin/env bash
# vim: ai:sw=4:ts=4:noet
##
## AI provider utilities: API key freshness checks, model name resolution,
## and config patching for CCR + LiteLLM.
## Reads provider metadata from api-keys.yaml — never calls op or 1Password.
## Requires: yq v4, curl. Source lib-secrets.sh first to populate env vars.

lib_name="$(basename "${BASH_SOURCE%.*}")"
lib_name="${lib_name//-/_}"
if eval "[[ -z \${$lib_name+x} ]]"; then
	eval "$lib_name=true"

	_SECRETS_YAML="${SECRETS_YAML:-$(dirname "${BASH_SOURCE[0]}")/api-keys.yaml}"
	_AI_MODEL_CACHE="${AI_MODEL_CACHE:-$HOME/.cache/tne/model-ids.yaml}"
	_AI_MODEL_CACHE_TTL_DAYS="${AI_MODEL_CACHE_TTL_DAYS:-7}"

	# ── YAML provider reader ──────────────────────────────────────────────────────
	# Parse api-keys.yaml for AI provider fields only.
	# Prints TSV: env_var models_url models_auth models_auth_param models_pattern
	#             litellm_base litellm_key_env litellm_model_prefix ccr_provider
	_ai_parse_providers() {
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
			| select(.value.models_url != null)
			| [.key,
			   .value.models_url,
			   (.value.models_auth // \"bearer\"),
			   (.value.models_auth_param // \"key\"),
			   (.value.models_pattern // \"\"),
			   (.value.litellm_base // \"\"),
			   (.value.litellm_key_env // .key),
			   (.value.litellm_model_prefix // \"openai/\"),
			   (.value.ccr_provider // \"\")]
			| @tsv" "$yaml_file"
	}

	# ── ai_check_api_keys ─────────────────────────────────────────────────────────
	# Curl each provider's models_url in parallel; report 200/401/403/timeout.
	# Only checks keys that are currently set in the environment.
	# Args: optional env var names to check (default: all with models_url)
	# Completes in <10s (3s connect timeout, parallel subshells).
	ai_check_api_keys() {
		local -a vars=("$@")
		local _providers
		_providers=$(_ai_parse_providers "$_SECRETS_YAML" "${vars[@]}") || return 1

		local -a pids=()
		local -a results=()
		local tmpdir
		tmpdir=$(mktemp -d)

		while IFS=$'\t' read -r env_var models_url models_auth models_auth_param _rest; do
			[[ -z "$env_var" || -z "${!env_var:-}" ]] && continue
			local result_file="$tmpdir/$env_var"
			(
				if [[ "$models_auth" == "query" ]]; then
					code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 \
						"${models_url}?${models_auth_param}=${!env_var}")
				else
					code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 \
						-H "Authorization: Bearer ${!env_var}" "$models_url")
				fi
				echo "$code" >"$result_file"
			) &
			pids+=($!)
			results+=("$env_var $result_file")
		done <<<"$_providers"

		for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done

		local any_fail=0
		for entry in "${results[@]}"; do
			local ev rf code
			ev="${entry%% *}"
			rf="${entry#* }"
			code=$(cat "$rf" 2>/dev/null || echo "000")
			case "$code" in
			200) echo "$ev: valid" ;;
			401)
				echo "$ev: EXPIRED or INVALID (401) — refresh the key" >&2
				any_fail=1
				;;
			403)
				echo "$ev: FORBIDDEN (403) — wrong key or no access" >&2
				any_fail=1
				;;
			000)
				echo "$ev: unreachable — network/DNS failure" >&2
				any_fail=1
				;;
			*)
				echo "$ev: unexpected HTTP $code" >&2
				any_fail=1
				;;
			esac
		done
		rm -rf "$tmpdir"
		return "$any_fail"
	}

	# ── ai_resolve_model_names ────────────────────────────────────────────────────
	# Query each provider's models_url, filter by models_pattern, cache results.
	# Cache TTL: _AI_MODEL_CACHE_TTL_DAYS (default 7).
	# Sets per-provider vars: AI_MODEL_<PROVIDER>_LATEST and AI_MODEL_<PROVIDER>_IDS
	# Provider name derived from ccr_provider field (uppercased, non-alnum→_).
	ai_resolve_model_names() {
		local cache="$_AI_MODEL_CACHE"
		local ttl="$_AI_MODEL_CACHE_TTL_DAYS"
		local cache_fresh=false

		if [[ -f "$cache" ]]; then
			local cache_age_days
			cache_age_days=$(python3 -c "
import os, time
age = time.time() - os.path.getmtime('$cache')
print(int(age / 86400))
" 2>/dev/null || echo 999)
			[[ "$cache_age_days" -lt "$ttl" ]] && cache_fresh=true
		fi

		if $cache_fresh; then
			_ai_load_model_cache "$cache"
			return 0
		fi

		mkdir -p "$(dirname "$cache")"
		local -a cache_lines=()
		local _providers
		_providers=$(_ai_parse_providers "$_SECRETS_YAML") || return 1

		while IFS=$'\t' read -r env_var models_url models_auth models_auth_param \
			models_pattern _litellm_base _litellm_key _litellm_prefix ccr_provider; do
			[[ -z "$env_var" || -z "${!env_var:-}" ]] && continue

			# Catch the probe failure and report it — a 401/timeout on one
			# provider must not abort the whole run under set -e (r-cto-dev162).
			local json=""
			if [[ "$models_auth" == "query" ]]; then
				json=$(curl -sf --connect-timeout 5 \
					"${models_url}?${models_auth_param}=${!env_var}" 2>/dev/null) || json=""
			else
				json=$(curl -sf --connect-timeout 5 \
					-H "Authorization: Bearer ${!env_var}" "$models_url" 2>/dev/null) || json=""
			fi
			if [[ -z "$json" ]]; then
				echo "  ⚠ ${env_var}: model probe failed at ${models_url} (key/endpoint?) — skipping, using fallback list" >&2
				continue
			fi

			local ids
			ids=$(echo "$json" | python3 -c "
import sys, json, re
pattern = sys.argv[1]
try:
    data = json.load(sys.stdin)
    items = data.get('data', data.get('models', []))
    ids = []
    for m in items:
        mid = m.get('id') or m.get('name', '')
        if mid and (not pattern or re.search(pattern, mid)):
            ids.append(mid)
    ids.sort()
    print('\n'.join(ids))
except Exception:
    pass
" "$models_pattern" 2>/dev/null)
			[[ -z "$ids" ]] && continue

			local latest
			latest=$(tail -1 <<<"$ids")
			local provider_key
			provider_key=$(echo "${ccr_provider:-$env_var}" | tr '[:lower:].' '[:upper:]_' | tr -cd 'A-Z0-9_')

			export "AI_MODEL_${provider_key}_LATEST=$latest"
			export "AI_MODEL_${provider_key}_IDS=$(tr '\n' ':' <<<"$ids" | sed 's/:$//')"

			cache_lines+=("${provider_key}:${latest}:$(tr '\n' ',' <<<"$ids" | sed 's/,$//')")
		done <<<"$_providers"

		printf '%s\n' "${cache_lines[@]}" >"$cache"
	}

	# Load model vars from cache file (internal helper)
	_ai_load_model_cache() {
		local cache="$1"
		while IFS=: read -r provider_key latest ids_csv; do
			[[ -z "$provider_key" ]] && continue
			export "AI_MODEL_${provider_key}_LATEST=$latest"
			export "AI_MODEL_${provider_key}_IDS=${ids_csv//,/:}"
		done <"$cache"
	}

	# ── ai_patch_ccr_config ───────────────────────────────────────────────────────
	# Rewrite model arrays in ~/.claude-code-router/config.json using resolved IDs.
	# Requires ai_resolve_model_names to have run first.
	# Creates a dated backup before writing.
	ai_patch_ccr_config() {
		local cfg="${CCR_CONFIG:-$HOME/.claude-code-router/config.json}"
		[[ -f "$cfg" ]] || {
			echo "ai_patch_ccr_config: not found: $cfg" >&2
			return 1
		}

		local _providers
		_providers=$(_ai_parse_providers "$_SECRETS_YAML") || return 1

		local patch_json="{}"
		while IFS=$'\t' read -r env_var _url _auth _param _pattern \
			_base _key _prefix ccr_provider; do
			[[ -z "$ccr_provider" ]] && continue
			local provider_key
			provider_key=$(echo "$ccr_provider" | tr '[:lower:].' '[:upper:]_' | tr -cd 'A-Z0-9_')
			local ids_var="AI_MODEL_${provider_key}_IDS"
			[[ -z "${!ids_var:-}" ]] && continue
			local ids_json
			ids_json=$(python3 -c "
import json, sys
ids = sys.argv[1].split(':')
print(json.dumps({'${ccr_provider}': ids}))
" "${!ids_var}" 2>/dev/null) || continue
			patch_json=$(python3 -c "
import json, sys
a, b = json.loads(sys.argv[1]), json.loads(sys.argv[2])
a.update(b); print(json.dumps(a))
" "$patch_json" "$ids_json" 2>/dev/null) || continue
		done <<<"$_providers"

		cp "$cfg" "${cfg}.bak.$(date +%Y%m%d)"
		python3 - "$cfg" "$patch_json" <<'PYEOF'
import sys, json
cfg_path, patch_json = sys.argv[1], sys.argv[2]
patch = json.loads(patch_json)
with open(cfg_path) as f:
    cfg = json.load(f)
for provider in cfg.get('Providers', []):
    name = provider.get('name', '')
    if name in patch:
        provider['models'] = patch[name]
with open(cfg_path, 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
PYEOF
		echo "ai_patch_ccr_config: patched $cfg"
	}

	# ── ai_patch_litellm_config ───────────────────────────────────────────────────
	# Rewrite model_list entries in ~/.config/litellm/config.yaml.
	# Requires ai_resolve_model_names to have run first.
	# Creates a dated backup before writing.
	ai_patch_litellm_config() {
		local cfg="${LITELLM_CONFIG:-$HOME/.config/litellm/config.yaml}"
		[[ -f "$cfg" ]] || {
			echo "ai_patch_litellm_config: not found: $cfg" >&2
			return 1
		}

		local _providers
		_providers=$(_ai_parse_providers "$_SECRETS_YAML") || return 1

		cp "$cfg" "${cfg}.bak.$(date +%Y%m%d)"

		while IFS=$'\t' read -r env_var _url _auth _param _pattern \
			litellm_base litellm_key_env litellm_prefix ccr_provider; do
			[[ -z "$litellm_base" ]] && continue
			local provider_key
			provider_key=$(echo "${ccr_provider:-$env_var}" | tr '[:lower:].' '[:upper:]_' | tr -cd 'A-Z0-9_')
			local latest_var="AI_MODEL_${provider_key}_LATEST"
			[[ -z "${!latest_var:-}" ]] && continue

			local model_id="${litellm_prefix}${!latest_var}"
			local model_name="${!latest_var,,}"

			# Use yq to safely modify model_list[] — avoids corrupting unrelated YAML sections
			local idx
			idx=$(yq '.model_list | to_entries | .[] | select(.value.model_name == "'"$model_name"'") | .key' "$cfg" 2>/dev/null | head -1)
			if [[ -n "$idx" ]]; then
				# Update existing entry in-place
				yq -i ".model_list[$idx].litellm_params.model = \"$model_id\" | \
				        .model_list[$idx].litellm_params.api_base = \"$litellm_base\" | \
				        .model_list[$idx].litellm_params.api_key = \"os.environ/$litellm_key_env\"" "$cfg"
			else
				# Append new entry to model_list
				yq -i ".model_list += [{\"model_name\": \"$model_name\", \"litellm_params\": {\"model\": \"$model_id\", \"api_base\": \"$litellm_base\", \"api_key\": \"os.environ/$litellm_key_env\"}}]" "$cfg"
			fi
		done <<<"$_providers"
		echo "ai_patch_litellm_config: patched $cfg"
	}

fi
