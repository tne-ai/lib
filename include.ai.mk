##
## AI tools
PYTHON ?= 3.12
FLAGS ?=
SHELL := /usr/bin/env bash
WS_DIR ?= $(HOME)/ws
BIN_DIR ?= $(WS_DIR)/git/src/bin
TNE_DB_DIR  ?= $(WS_DIR)/db
TNE_LOG_DIR ?= $(WS_DIR)/logs
TNE_DATA    ?= $(WS_DIR)/data
export WS_DIR BIN_DIR TNE_DB_DIR TNE_LOG_DIR

AI_USER ?= $(USER)
AI_ORG ?= tne.ai

# variables must be definte before their use so put high
MLFLOW_PORT    ?= 5001
LITELLM_PORT   ?= 4000
TEMPORAL_PORT  ?= 7233
TEMPORAL_UI_PORT ?= 8233
KTAP_PORT      ?= 8630
CCR_PORT       ?= 3456
LLS_PORT       ?= 8081
REDIS_PORT     ?= 6379
POSTGRES_PORT  ?= 5432
CLAUDE_MEM_PORT ?= 37777
# OLLAMA_SERVER_PORT ?= 11434
# OPEN_WEBUI_PORT    ?= 8080
# ALLOY_PORT         ?= 12345

# Script to push session logs to MLflow — override per-repo if needed
MLFLOW_LOG_SCRIPT ?= $(WS_DIR)/git/src/sys/tne-plugins/plugins/tne/skills/cai-opt5-install-ai-stack/scripts/push-logs-to-mlflow.py
# Default: ~/.config/litellm/config.yaml (XDG standard).
# install-ai.sh copies tne-plugins/litellm_config.yaml here on setup.
LITELLM_CFG  ?= $(HOME)/.config/litellm/config.yaml
MLFLOW_DIR   ?= $(TNE_DB_DIR)
KTAP_DIR     ?= $(WS_DIR)/git/src/demo/demo-do178c
TEMPORAL_DB  ?= $(TNE_DB_DIR)/temporal/temporal.db
export TEMPORAL_DB
LITELLM_DB   ?= litellm
LITELLM_DB_URL ?= postgresql://$(USER)@localhost/$(LITELLM_DB)
# Monthly budget cap in USD — LiteLLM hard-stops when exceeded
LITELLM_BUDGET ?= 200
# Stamp file: prisma generate only runs when absent (r-cdo98 Principle II)
PRISMA_STAMP ?= $(HOME)/.local/share/make-ai/.stamp-prisma-generated

## debug: environment troubleshooting
.PHONY: debug
debug:
	echo "OSTYPE=$(shell uname -msr)"
	echo "LITELLM_PORT=$(LITELLM_PORT) MLFLOW_PORT=$(MLFLOW_PORT)"

# ## rclone: rclone sync the Linux clone of Google Drive back up
# .PHONY: rclone
# rclone:
# 	mkdir -p "$(OPEN_WEBUI_DATA_DIR)"
# 	rclone bisync --resync --interactive "$(OPEN_WEBUI_DATA_DIR)" "app:open-webui-data/$(AI_USER)"

# Use the simplest pattern that works for the sidecar type (r-cto-dev108):
#   start_server        — native binaries (Go, C, Node, Java): nohup + </dev/null
#   start_server_double_fork — Python ASGI/WSGI (Uvicorn/Gunicorn): required, not optional
#   start_server_brew   — brew-managed services: let brew own the lifecycle
#   start_server_self   — self-managing daemons: binary handles its own daemonization
SETSID ?= $(or $(shell which setsid 2>/dev/null),/opt/homebrew/opt/util-linux/bin/setsid)
start_server = if ! $(call port_ready,$(1)); then \
    nohup bash -c "$(2) $(3) $(4) $(5) $(6) $(7) $(8) $(9) $(10) \
                   </dev/null >>$(TNE_LOG_DIR)/sidecar-$(1).log 2>&1 &" &>/dev/null; fi
# Uvicorn/Gunicorn detect terminal group membership — double-fork required; nohup is not enough.
# If something holds the LISTEN socket but is not yet accepting connections (zombie), warn and
# skip — do not auto-kill. Run `make $(1).stop` to clear the port first.
start_server_double_fork = if $(call port_ready,$(1)); then \
    true; \
  elif lsof -ti :$(1) -sTCP:LISTEN &>/dev/null 2>&1; then \
    echo "⚠️  port $(1) is held by a zombie process — run: make $(1).stop"; \
  else \
    ($(SETSID) bash -c "$(2) $(3) $(4) $(5) $(6) $(7) $(8) $(9) $(10) \
                        </dev/null >>$(TNE_LOG_DIR)/sidecar-$(1).log 2>&1 &"); fi
start_server_brew = brew services start $(2) 2>/dev/null || true
start_server_self = $(2) $(3) $(4) $(5) $(6) $(7) $(8) $(9) $(10) || true

# usage: $(call open_server,port of service, url_suffix)
open_server = if $(call port_ready,$(1)); then open -a "Google Chrome" "http://localhost:$(1)$(2)"; fi &

# usage: $(call check_port,port) — poll until ready (HTTP /health/readiness first, TCP fallback)
# /health/readiness is unauthenticated on litellm/mlflow. /health requires the master key
# and returns 401 even when healthy — do not use it for readiness checks.
# gRPC services (temporal) and raw TCP (redis) use nc fallback.
# 90s timeout: litellm cold-start (prisma init + model load) routinely takes 30-45s;
# 60s was too tight and caused false "not ready" reports on first launch.
check_port = timeout=90; until curl -sf http://localhost:$(1)/health/readiness >/dev/null 2>&1 \
               || nc -z localhost $(1) 2>/dev/null; do \
    sleep 2; timeout=$$((timeout-2)); \
    [ $$timeout -eq 44 ] && echo "  still waiting for port $(1)..."; \
    [ $$timeout -gt 0 ] || { echo "⚠️  port $(1) did not become ready after 90s"; exit 0; }; \
  done && echo "✓ port $(1) ready"

# usage: $(call port_ready,port) — true if something is listening on port
port_ready = nc -z localhost $(1) 2>/dev/null

## %.ps: process status for any service (e.g. make litellm.ps)
%.ps:
	if ! pgrep -fl $*; then echo "$* not running"; fi

## [service].stop: graceful stop — SIGTERM first, SIGKILL fallback after 5s
# Belts-and-suspenders: name-based stop also kills the associated port so
# double-forked processes (PPID=1) that survive pkill are caught by lsof.
# SERVICE_PORTS maps service names → ports for the port-kill fallback.
SERVICE_PORTS := litellm:$(LITELLM_PORT) mlflow:$(MLFLOW_PORT) temporal:$(TEMPORAL_PORT) \
                 redis:$(REDIS_PORT) postgres:$(POSTGRES_PORT) ccr:$(CCR_PORT) ktap:$(KTAP_PORT)
%.stop:
	@declare -A _ports=( $(foreach p,$(SERVICE_PORTS),[$(word 1,$(subst :, ,$(p)))]=$(word 2,$(subst :, ,$(p)))) ); \
	for signal in "" "-9"; do \
		if echo "$*" | grep -qE '^[0-9]+$$'; then \
			lsof -ti :$* -sTCP:LISTEN 2>/dev/null | xargs -r kill $$signal 2>/dev/null || true; \
		else \
			pgrep -fl "$*" | grep -vE '^[0-9]+ make|pgrep' | awk '{print $$1}' | xargs -r kill $$signal 2>/dev/null || true; \
			_port="$${_ports[$*]:-}"; \
			[ -n "$$_port" ] && lsof -ti :$$_port -sTCP:LISTEN 2>/dev/null | xargs -r kill $$signal 2>/dev/null || true; \
		fi; \
		sleep 3; \
	done


# note never use brew for status very slow
	# brew services start postgresql@17 2>/dev/null || brew services start postgresql 2>/dev/null || true
## postgres: start PostgreSQL via brew services (needed for LiteLLM spend tracking)
.PHONY: postgres
postgres:
	if ! command -v psql >/dev/null 2>&1; then \
		$(MAKE) -f $(firstword $(MAKEFILE_LIST)) ai-install; \
	fi
	$(call port_ready,$(POSTGRES_PORT)) || brew services start postgresql@17 2>/dev/null || brew services start postgresql 2>/dev/null || true
	timeout=30; until $(call port_ready,$(POSTGRES_PORT)); do sleep 1; timeout=$$((timeout-1)); [ $$timeout -gt 0 ] || { echo "postgres did not become ready"; exit 1; }; done
	psql -lqt | grep -q "$(LITELLM_DB)" || createdb "$(LITELLM_DB)"

## redis: start Redis via brew services (needed for LiteLLM response caching)
.PHONY: redis
redis:
	if ! command -v redis-cli >/dev/null 2>&1; then \
		$(MAKE) -f $(firstword $(MAKEFILE_LIST)) ai-install; \
	fi
	$(call port_ready,$(REDIS_PORT)) || brew services start redis 2>/dev/null || true
	timeout=30; until $(call port_ready,$(REDIS_PORT)); do sleep 1; timeout=$$((timeout-1)); [ $$timeout -gt 0 ] || { echo "redis did not become ready"; exit 1; }; done

## mlflow: start MLflow tracking server at http://localhost:$(MLFLOW_PORT)
## mlflow has no Homebrew formula — install chain is: uv tool install → uvx (ephemeral).
## uv tool install puts the binary in ~/.local/bin which may not be in Make's PATH,
## so we resolve at runtime with `command -v mlflow || echo uvx mlflow`.
## mlflow-start: fire mlflow in background without waiting — overlaps with postgres/redis startup
.PHONY: mlflow-start
mlflow-start:
	if ! command -v mlflow >/dev/null 2>&1 && ! uvx mlflow --version >/dev/null 2>&1; then \
		echo "mlflow not installed — running make ai-install first"; \
		$(MAKE) -f $(firstword $(MAKEFILE_LIST)) ai-install; \
	fi
	mkdir -p "$(MLFLOW_DIR)/artifacts"
	$(call start_server_double_fork,$(MLFLOW_PORT),$$(command -v mlflow || echo uvx mlflow) server --host 127.0.0.1 --port $(MLFLOW_PORT) \
		--backend-store-uri sqlite:///$(MLFLOW_DIR)/mlflow.db \
		--default-artifact-root $(MLFLOW_DIR)/artifacts)

## mlflow: wait for mlflow to be ready (call mlflow-start first to overlap with postgres/redis)
.PHONY: mlflow
mlflow: mlflow-start
	$(call check_port,$(MLFLOW_PORT))

## Pin litellm to a known-good version. Unpin by setting LITELLM_VERSION=latest.
## WHY: litellm has shipped broken UI builds (HTML/JS chunk hash mismatch in 1.83.x)
## that cause a blank "gigantic zero" dashboard. Pinning ensures a tested coherent build.
## 1.84.0 was the first fixed version; 1.86.2 tested and confirmed good (2026-06-01).
LITELLM_VERSION ?= 1.86.2

## litellm: start LiteLLM proxy at http://localhost:$(LITELLM_PORT)
## no_auth mode: LiteLLM accepts all requests without key validation (localhost dev only).
## Claude Code uses OAuth keychain (no ANTHROPIC_API_KEY) — claudeai-mcp stays enabled.
## Claude Max plan: OAuth Bearer forwarded to Anthropic via forward_client_headers_to_llm_api.
## Alt providers: LiteLLM uses litellm_params.api_key; client Bearer NOT forwarded to backends.
## litellm binary also lives in ~/.local/bin (uv tool install) — same PATH fix as mlflow.
## litellm-install: install or upgrade litellm to the pinned LITELLM_VERSION
.PHONY: litellm-install
litellm-install:
	@echo "==> installing litellm==$(LITELLM_VERSION)"
	pipx install --force "litellm[proxy]==$(LITELLM_VERSION)"
	pipx inject litellm mlflow
	@$(MAKE) --no-print-directory litellm-fix-ui

## litellm-fix-ui: patch login/index.html hash mismatch (1.85.x packaging bug)
## login/index.html ships with stale chunk hashes; overwrite with login.html which is correct.
.PHONY: litellm-fix-ui
litellm-fix-ui:
	@_base=$$(python3 -c "import litellm,os; print(os.path.dirname(litellm.__file__))" 2>/dev/null \
		|| pipx run --spec "litellm==$(LITELLM_VERSION)" python3 -c "import litellm,os; print(os.path.dirname(litellm.__file__))"); \
	_out="$$_base/proxy/_experimental/out"; \
	if [ -f "$$_out/login.html" ] && [ -f "$$_out/login/index.html" ]; then \
		cp "$$_out/login.html" "$$_out/login/index.html"; \
		echo "✓ litellm UI patch applied (login/index.html synced from login.html)"; \
	else \
		echo "⚠  litellm UI patch: paths not found — skipping"; \
	fi


## litellm-check-version: verify installed litellm matches LITELLM_VERSION; fix if not
## Called automatically by make litellm before startup.
.PHONY: litellm-check-version
litellm-check-version:
	@_installed=$$(litellm --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1); \
	if [ "$$_installed" != "$(LITELLM_VERSION)" ]; then \
		echo "⚠️  litellm $$_installed ≠ pinned $(LITELLM_VERSION) — reinstalling..."; \
		pipx install --force "litellm[proxy]==$(LITELLM_VERSION)" --quiet \
			&& echo "✓ litellm $(LITELLM_VERSION) installed" \
			&& $(MAKE) --no-print-directory litellm-fix-ui \
			|| { echo "✗ reinstall failed — run: make litellm-install"; exit 1; }; \
	else \
		echo "✓ litellm $(LITELLM_VERSION) (pinned)"; \
	fi

## litellm.stop / 4000.stop: kill ALL litellm processes (port kill + pkill sweep for zombies)
## WHY bin/litellm not litellm: postgres names its worker processes after the database.
## Since the litellm database is named "litellm", pkill -f "litellm" matches and tries
## to kill postgres workers — those kills fail (permission or zombie), pkill exits non-zero,
## the || true masks it, and the actual Python process may survive if the port kill also
## missed. Matching "bin/litellm" targets only the Python CLI binary, not postgres.
.PHONY: litellm.stop 4000.stop
litellm.stop 4000.stop:
	@-lsof -ti :$(LITELLM_PORT) -sTCP:LISTEN | xargs kill 2>/dev/null || true
	@pkill -f "bin/litellm" 2>/dev/null || true
	@sleep 1
	@pkill -9 -f "bin/litellm" 2>/dev/null || true
	@echo "litellm stopped"

## litellm: start LiteLLM proxy with automatic Prisma client regeneration
##
## WHY venv Python for prisma generate (not system prisma):
##   LiteLLM uses Prisma Client Python (prisma==0.15.0) installed inside its
##   own pipx venv. `prisma generate` writes the query-engine bindings into
##   whichever Python environment owns the `prisma` binary. If you run the
##   system/uv-tool prisma binary it writes to *that* env, not to the litellm
##   venv — litellm never sees the updated client and crashes with
##   FieldNotFoundError on every `pipx upgrade litellm` that adds DB columns.
##   Solution: always call $$_venv/bin/python -m prisma generate so the
##   generated client lands in the litellm venv. Do NOT install prisma as a
##   standalone uv tool or pipx app — those create a separate env that
##   shadows the litellm venv's client and causes the same mismatch.
##
## Prisma stamp ($(PRISMA_STAMP)) stores the md5 hash of schema.prisma.
## On every run: hash the current schema → compare to stamp → if different
## (or stamp absent), regenerate the Prisma client AND push schema to DB,
## then update the stamp. Covers both client codegen and DB migrations in one step.
## This means `pipx upgrade litellm` automatically triggers regeneration
## on the next `make litellm` — no manual intervention needed.
## To force regeneration: rm $(PRISMA_STAMP)
.PHONY: litellm
litellm: litellm-check-version
	@if ! command -v litellm >/dev/null 2>&1 && ! uvx litellm --version >/dev/null 2>&1; then \
		echo "litellm not installed — running make ai-install first"; \
		$(MAKE) -f $(firstword $(MAKEFILE_LIST)) ai-install; \
	fi
	@[[ "$${LITELLM_MASTER_KEY}" == op://* ]] \
		&& { echo "==> resolving LITELLM_MASTER_KEY from 1Password"; LITELLM_MASTER_KEY=$$(op read "$${LITELLM_MASTER_KEY}") || { echo "✗ op read failed — run: op signin"; exit 1; }; } \
		|| true; \
	_venv=$$(pipx environment --value PIPX_LOCAL_VENVS 2>/dev/null)/litellm; \
	_schema=$$(echo $$_venv/lib/python*/site-packages/litellm/proxy/schema.prisma); \
	_schema_hash=$$(md5 -q "$$_schema" 2>/dev/null || md5sum "$$_schema" 2>/dev/null | awk '{print $$1}'); \
	if [ "$$(cat $(PRISMA_STAMP) 2>/dev/null)" != "$$_schema_hash" ]; then \
		echo "==> prisma generate (schema changed or first run)"; \
		PATH="$$_venv/bin:$$PATH" $$_venv/bin/prisma generate --schema "$$_schema"; \
		echo "==> prisma db push (applying schema changes to database)"; \
		DATABASE_URL=$${DATABASE_URL:-postgresql://$$USER@localhost/litellm} \
			PATH="$$_venv/bin:$$PATH" $$_venv/bin/prisma db push --schema "$$_schema" --accept-data-loss; \
		mkdir -p $$(dirname $(PRISMA_STAMP)) && echo "$$_schema_hash" > $(PRISMA_STAMP); \
	fi; \
	lsof -ti :$(LITELLM_PORT) -sTCP:LISTEN 2>/dev/null | xargs kill 2>/dev/null || true; \
	pkill -f "bin/litellm" 2>/dev/null || true; \
	sleep 1; \
	$(call start_server_double_fork,$(LITELLM_PORT),\
		LITELLM_LOG=DEBUG \
		ANTHROPIC_API_KEY="$${LITELLM_MASTER_KEY}" \
		DATABASE_URL=$${DATABASE_URL:-postgresql://$$USER@localhost/litellm} \
		LM_STUDIO_API_TOKEN="$${LM_STUDIO_API_TOKEN}" \
		MOONSHOT_API_KEY="" \
		GEMINI_API_KEY="$${GEMINI_API_KEY}" \
		DEEPSEEK_API_KEY="$${DEEPSEEK_API_KEY}" \
		ALIBABA_API_KEY="$${ALIBABA_API_KEY}" \
		ALIBABA_PLAN_KEY="$${ALIBABA_PLAN_KEY}" \
		Z_AI_PLAN_KEY="$${Z_AI_PLAN_KEY}" \
		MINIMAX_API_KEY="$${MINIMAX_API_KEY}" \
		MINIMAX_PLAN_KEY="$${MINIMAX_PLAN_KEY}" \
		OPENROUTER_API_KEY="$${OPENROUTER_API_KEY}" \
		CLIPROXYAPI_KEY="$${CLIPROXYAPI_KEY}" \
		MLFLOW_TRACKING_URI="http://localhost:$(MLFLOW_PORT)" \
		MLFLOW_EXPERIMENT_NAME="tne-costs" \
		$$(command -v litellm || echo uvx litellm) --config $(LITELLM_CFG) --port $(LITELLM_PORT) --host 127.0.0.1)
	$(call check_port,$(LITELLM_PORT))

# ── Harness + model variables ─────────────────────────────────────────────────
# HARNESS: the AI coding assistant CLI. Swap without changing targets.
#   make ai                        # claude (default)
#   make ai HARNESS=aider          # aider
#   make ai HARNESS=codex          # codex CLI (plan provider via CLIProxyAPI)
# MODEL: any model_name from $(LITELLM_CFG). Run 'make ai-models' to list all.
#   make ai-run MODEL=kimi-k2.6         # Kimi K2 via $19/mo Coding Plan
#   make ai-run MODEL=gemini-2.5-flash  # Gemini Flash (PAYG)
#   make ai-run MODEL=lls/qwen/qwen3.6-27b  # local GPU via llama-server
#
# WHY --model accepts non-claude names:
#   Claude Code normally validates --model against Anthropic's allowlist.
#   Two things disable that check here:
#     1. ANTHROPIC_BASE_URL points to LiteLLM (localhost:4000), not api.anthropic.com.
#        When a custom base URL is set, Claude Code skips the model name allowlist —
#        it forwards whatever string you give to the endpoint as-is.
#     2. LiteLLM maps the model_name you pass to the real provider and model behind it.
#        "kimi-k2.6" → claude-code-proxy (localhost:3457) → Kimi API
#        "lls/google/gemma-4-e2b" → llama-server (localhost:8081) → local GGUF
#   So any model_name registered in config.yaml (~/.config/litellm/config.yaml) works.
#   Run 'make ai-models' to list all available names.
#
# HARNESS_ARGS: extra flags forwarded to the harness binary.
#   make ai HARNESS_ARGS="--continue"
HARNESS            ?= claude
HARNESS_ARGS       ?=
MODEL              ?=

# ── Run-only targets (servers already up) ─────────────────────────────────────
# ONE-MECHANISM RULE: ai-run / ai-p are the sole model selectors.
# Set MODEL= here; engine batch jobs inherit ANTHROPIC_BASE_URL via os.environ.
# All providers route through LiteLLM at :$(LITELLM_PORT) — no per-tool config needed.
# Auth must already be set up (make ai-auth) — subscription bridges need valid OAuth tokens.
# OTEL: CLAUDE_CODE_ENABLE_TELEMETRY=1 sends traces to MLflow experiment tne-training (id=2).
# tne-training = conversation traces (prompts, tool calls) — fine-tuning corpus.
# tne-costs    = LiteLLM per-call metrics (model, tokens, spend) — cost/billing analysis.
## ai-run: launch interactive AI harness with LiteLLM routing
##
## Billing legend:
##   [PLAN] flat-rate subscription — no per-token cost once subscribed
##   [PAYG] pay-as-you-go per token — watch spend; no flat-rate plan available
##   [FREE] local GPU — zero cloud cost
##
## Provider billing model:
##   Anthropic : PLAN  — Max plan OAuth token forwarded by LiteLLM; no api_key = no PAYG billing
##   Kimi      : PLAN  — $19/mo Coding Plan via claude-code-proxy bridge (:3457)
##   Gemini    : PLAN  — Google One AI Premium OAuth via cliproxyapi bridge (:8317)
##   Z.AI/GLM  : PLAN  — same API key routes to coding plan quota via api.z.ai/api/anthropic
##   MiniMax   : PLAN  — Token Plan ~$10/mo; MINIMAX_PLAN_KEY routes to plan quota
##   Qwen      : PLAN  — Alibaba Plan key (ALIBABA_PLAN_KEY) via dashscope-intl endpoint
##   DeepSeek  : PAYG  — no flat-rate plan exists; cheap ($0.14/1M tokens for flash)
##   OpenRouter: PAYG  — markup on underlying models; use for models with no direct plan
##
##   make ai-run                               # claude via Max plan (default)   [PLAN]
##   make ai-run MODEL=kimi-k2.6              # Kimi K2.6 Coding Plan $19/mo    [PLAN]
##   make ai-run MODEL=glm-5.1               # GLM-5.1 Z.AI coding plan         [PLAN]
##   make ai-run MODEL=minimax-m2.7          # MiniMax M2.7 Token Plan          [PLAN]
##   make ai-run MODEL=gpt-5.5               # ChatGPT/Codex plan (auth: make ai-auth PROVIDER=codex) [PLAN]
##   make ai-run MODEL=gpt-5.4-mini          # ChatGPT/Codex plan — mini (auth: make ai-auth PROVIDER=codex) [PLAN]
##   make ai-run MODEL=deepseek-v4-flash     # DeepSeek V4 Flash                [PAYG]
##   make ai-run MODEL=deepseek-v4-pro       # DeepSeek V4 Pro                  [PAYG]
##   make ai-run MODEL=or-nemotron-nano-30b         # Nemotron 30B via OpenRouter       [FREE]
##   make ai-run MODEL=or-nemotron-nano-30b-reasoning # Nemotron 30B reasoning          [FREE]
##   make ai-run MODEL=or-nemotron-super-120b       # Nemotron 120B 1M ctx             [FREE]
##   make ai-run MODEL=or-qwen3-coder               # Qwen3 Coder 1M ctx               [FREE]
##   make ai-run MODEL=or-qwen3-coder-30b           # Qwen3 Coder 30B                  [PAYG]
##   make ai-run MODEL=or-qwen3-235b                # Qwen3 235B (cheap)               [PAYG]
##   make ai-run MODEL=or-qwen3.6-35b               # Qwen3.6 35B MoE                  [PAYG]
##   make ai-run MODEL=lls/qwen/qwen3.6-27b  # local GPU (llama-server router)  [FREE]
##   make ai-run MODEL=lms/qwen/qwen3.6-27b  # local GPU (LM Studio — legacy)   [FREE]
##   make ai-run HARNESS=aider               # swap harness, same model
# Auth modes (MODEL gates everything):
#   MODEL=<empty>    → default Claude Max path. OAuth keychain auth, full Claude UX.
#                      LiteLLM forwards the Bearer to Anthropic (Max plan passthrough)
#                      via model_group_settings.forward_client_headers_to_llm_api.
#   MODEL=<provider> → alt-provider via LiteLLM. OAuth keychain still used (no
#                      ANTHROPIC_API_KEY set) so claudeai-mcp stays enabled for all
#                      models. LiteLLM no_auth=true accepts OAuth Bearer without key
#                      validation. Non-Anthropic backends use their own api_key from
#                      litellm_params (forward_client_headers_to_llm_api: false).
.PHONY: ai-run
ai-run:
	@curl -sf http://localhost:$(LITELLM_PORT)/health/readiness >/dev/null 2>&1 \
		|| { echo "LiteLLM not ready on :$(LITELLM_PORT) — auto-restarting..."; \
			$(MAKE) --no-print-directory litellm; } \
		&& curl -sf http://localhost:$(LITELLM_PORT)/health/readiness >/dev/null 2>&1 \
		|| { echo "LiteLLM still not ready — check: make ai-log"; exit 1; }
	@$(if $(filter lls/%,$(MODEL)), \
		$(call port_ready,8081) \
		|| { echo "llama-server not running on :8081 — run: make lls-start"; exit 1; },)
	@$(if $(filter lms/%,$(MODEL)), \
		lms load "$$(echo '$(MODEL)' | sed 's|^lms/||')" --gpu max \
		|| echo "⚠️  lms load failed — model may already be loaded",)
	ANTHROPIC_BASE_URL=http://localhost:$(LITELLM_PORT) \
	OPENAI_BASE_URL=http://localhost:$(LITELLM_PORT) \
	$(if $(MODEL),ANTHROPIC_CUSTOM_MODEL_OPTION=$(MODEL),) \
	TNE_SESSION_MODEL="$(MODEL)" \
	CLAUDE_CODE_ENABLE_TELEMETRY=1 \
	OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf \
	OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:$(MLFLOW_PORT) \
	OTEL_EXPORTER_OTLP_HEADERS="x-mlflow-experiment-id=2" \
	env -u CLAUDECODE -u ANTHROPIC_MAX $(HARNESS) $(if $(MODEL),--model $(MODEL),) $(HARNESS_ARGS)

## ai-p: run a single claude -p batch invocation via LiteLLM routing
## Same env as ai-run — engine invoker.py inherits ANTHROPIC_BASE_URL via os.environ.
##   make ai-p MODEL=kimi-k2.5 PROMPT='summarize foo.md'
##   make ai-p MODEL=gemini-2.5-flash AI_P_ARGS='--output-format json' PROMPT='classify: ...'
PROMPT ?=
AI_P_ARGS ?=
.PHONY: ai-p
ai-p:
	@curl -sf http://localhost:$(LITELLM_PORT)/health/readiness >/dev/null 2>&1 \
		|| { echo "LiteLLM not ready on :$(LITELLM_PORT) — run: make litellm"; exit 1; }
	ANTHROPIC_BASE_URL=http://localhost:$(LITELLM_PORT) \
	OPENAI_BASE_URL=http://localhost:$(LITELLM_PORT) \
	$(if $(MODEL),ANTHROPIC_CUSTOM_MODEL_OPTION=$(MODEL),) \
	TNE_SESSION_MODEL="$(MODEL)" \
	CLAUDE_CODE_ENABLE_TELEMETRY=1 \
	OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf \
	OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:$(MLFLOW_PORT) \
	OTEL_EXPORTER_OTLP_HEADERS="x-mlflow-experiment-id=2" \
	env -u ANTHROPIC_MAX claude -p $(AI_P_ARGS) $(if $(MODEL),--model $(MODEL),) "$(PROMPT)"

# ── Public entry points ───────────────────────────────────────────────────────

## ai: start full sidecar stack — cloud + local GPU, all models available
## See all available models (cloud + local) after start: make ai-help
## Sidecars: postgres redis mlflow litellm temporal set-gpu-max-memory lls-start
## (ai-local was merged into ai — one stack serves all models)
.PHONY: ai ai-local
ai ai-local: mlflow-start postgres redis mlflow litellm temporal set-gpu-max-memory lls-start ai-open
	@$(MAKE) --no-print-directory ai-help
	@$(MAKE) --no-print-directory ai-warn-bridges

## ai-help: show available models — live cloud cache + dynamic lls/ollama
## Cloud models come from ~/.cache/tne/model-ids.yaml (refresh: make ai-refresh-models)
.PHONY: ai-help
ai-help:
	@echo ""
	@echo "  Stack ready. Run your AI harness (MODEL= optional):"
	@echo ""
	@echo "  ── Cloud (API keys — refresh: make ai-refresh-models) ───────────────────"
	@echo "    make ai-run                               # claude Max plan (default)"
	@yq '.model_list[].model_name' "$(LITELLM_CFG)" 2>/dev/null \
		| grep -v '^lms/\|^lls/' | sort -u \
		| while IFS= read -r name; do \
			case "$$name" in \
			claude*)   tag="PLAN -- Anthropic Max" ;; \
			kimi*)     tag="PLAN -- Kimi Coding Plan" ;; \
			glm*)      tag="PLAN -- Z.AI coding plan" ;; \
			qwen*)     tag="PLAN -- Alibaba plan (ALIBABA_PLAN_KEY)" ;; \
			minimax*)  tag="PLAN -- MiniMax token plan" ;; \
			gemini*)   tag="PLAN -- Google CLI sub" ;; \
			deepseek*) tag="PAYG -- no flat-rate plan" ;; \
			routellm*) tag="PLAN+PLAN -- auto-router" ;; \
			*)         tag="PAYG" ;; \
			esac; \
			printf "    make ai-run MODEL=%-36s# %s\n" "$$name" "$$tag"; \
		done \
		|| echo "    (litellm config not found — run make ai-install)"
	@echo ""
	@echo "  ── Local GPU (llama-server) ─────────────────────────────────────────────"
	@if nc -z localhost $(LLS_PORT) 2>/dev/null; then \
		curl -sf http://localhost:$(LLS_PORT)/v1/models 2>/dev/null \
		| yq -p json '.data[].id' 2>/dev/null \
		| while IFS= read -r id; do printf '    make ai-run MODEL=lls/%-28s # FREE\n' "$$id"; done \
		|| echo "    (lls running but models unavailable)"; \
	else \
		yq '.model_list[].model_name' "$(LITELLM_CFG)" 2>/dev/null | grep '^lls' | sort \
		| while IFS= read -r name; do printf '    make ai-run MODEL=%-36s # FREE (lls offline)\n' "$$name"; done; \
		[ -z "$$(yq '.model_list[].model_name' "$(LITELLM_CFG)" 2>/dev/null | grep -c '^lls')" ] \
		  && echo "    (lls not running — start with: make lls-start)"; \
	fi
	@echo ""
	@echo "  ── Ollama ───────────────────────────────────────────────────────────────"
	@if nc -z localhost 11434 2>/dev/null; then \
		curl -sf http://localhost:11434/api/tags 2>/dev/null \
		| yq -p json '.models[].name' 2>/dev/null \
		| while IFS= read -r name; do printf '    make ai-run MODEL=ollama/%-28s # FREE\n' "$$name"; done \
		|| echo "    (ollama running — run: ollama list)"; \
	else \
		echo "    (ollama not running — start with: ollama serve)"; \
	fi
	@echo ""
	@echo "  ── Batch (claude -p) ────────────────────────────────────────────────────"
	@echo "    make ai-p MODEL=<model> PROMPT='<prompt>'   # single batch invocation"
	@echo "    make ai-run HARNESS=aider                   # swap harness"
	@echo ""

## ai-warn-bridges: start subscription bridges if not running; warn to auth if they stay down
## Called automatically by make ai. Non-interactive — never prompts for credentials.
## If a bridge needs first-time auth, run: make ai-auth PROVIDER=kimi|gemini|codex
##   kimi         — claude-code-proxy  :3457  starts automatically if already authenticated
##   gemini/codex — CLIProxyAPI        :8317  starts automatically if already authenticated
.PHONY: ai-warn-bridges
ai-warn-bridges:
	@if ! nc -z localhost $(KIMI_CLAUDE_PROXY_PORT) 2>/dev/null; then \
		echo "  → kimi bridge (:$(KIMI_CLAUDE_PROXY_PORT)) not running — starting..."; \
		if command -v claude-code-proxy >/dev/null 2>&1; then \
			PORT=$(KIMI_CLAUDE_PROXY_PORT) nohup claude-code-proxy serve </dev/null >$(TNE_LOG_DIR)/kimi-proxy.log 2>&1 & \
			sleep 2; \
			if nc -z localhost $(KIMI_CLAUDE_PROXY_PORT) 2>/dev/null; then \
				echo "  ✓  kimi bridge started"; \
			else \
				echo "  ⚠️  kimi bridge not up — last log lines:"; \
				tail -5 $(TNE_LOG_DIR)/kimi-proxy.log 2>/dev/null | sed 's/^/       /'; \
				echo "       Fix: make ai-auth PROVIDER=kimi   (authenticate first, then retry)"; \
			fi; \
		else \
			echo "  ⚠️  claude-code-proxy not installed — brew install raine/claude-code-proxy/claude-code-proxy"; \
		fi; \
	fi
	@if ! nc -z localhost $(CLIPROXYAPI_PORT) 2>/dev/null; then \
		echo "  → gemini/codex bridge (:$(CLIPROXYAPI_PORT)) not running — starting..."; \
		if command -v cliproxyapi >/dev/null 2>&1; then \
			nohup cliproxyapi -config "$(HOME)/.config/cliproxyapi/config.yaml" </dev/null >$(TNE_LOG_DIR)/sidecar-$(CLIPROXYAPI_PORT).log 2>&1 & \
			sleep 2; \
			if nc -z localhost $(CLIPROXYAPI_PORT) 2>/dev/null; then \
				echo "  ✓  gemini/codex bridge started"; \
			else \
				echo "  ⚠️  gemini/codex bridge not up — last log lines:"; \
				tail -5 $(TNE_LOG_DIR)/sidecar-$(CLIPROXYAPI_PORT).log 2>/dev/null | sed 's/^/       /'; \
				echo "       Fix: make ai-auth PROVIDER=gemini|codex   (authenticate first, then retry)"; \
			fi; \
		else \
			echo "  ⚠️  cliproxyapi not installed — brew install cliproxyapi"; \
		fi; \
	fi
	@nc -z localhost $(KIMI_CLAUDE_PROXY_PORT) 2>/dev/null \
		&& nc -z localhost $(CLIPROXYAPI_PORT) 2>/dev/null \
		&& echo "  ✓  Subscription bridges: kimi :$(KIMI_CLAUDE_PROXY_PORT) gemini/codex :$(CLIPROXYAPI_PORT)" || true

## ai-cli: CLI-auth providers via CLIProxyAPI adapter  [PLAN — flat-rate subscriptions]
## Authenticates via provider CLI login, not per-token API key.
##   make ai-cli MODEL=codex        # ChatGPT/Codex plan (codex login)        [PLAN]
##   make ai-cli MODEL=gemini-proxy # Google Gemini plan (gemini auth login)  [PLAN]
.PHONY: ai-cli
ai-cli: postgres redis mlflow litellm cliproxyapi ai-open
	@echo "  CLI stack ready. Run: make ai-run MODEL=codex"

## ai-auto: difficulty-routing — cheap for simple tasks, strong for hard  [PLAN+PLAN]
## Easy prompts → kimi-k2.6 (Coding Plan $19/mo), hard → claude-sonnet (Max plan)
.PHONY: ai-auto
ai-auto: postgres redis mlflow litellm routellm
	@echo "  Auto-routing stack ready. Run: make ai-run MODEL=routellm"

## ai-auth: log in to all AI providers (run once per machine or after token expiry)
##   make ai-auth              # all providers
##   make ai-auth PROVIDER=claude   # claude /login
##   make ai-auth PROVIDER=kimi     # claude-code-proxy kimi auth login
##   make ai-auth PROVIDER=gemini   # cliproxyapi -login  (Google OAuth → ~/.cli-proxy-api/)
##   make ai-auth PROVIDER=codex    # cliproxyapi -codex-login
PROVIDER ?=
.PHONY: ai-auth
ai-auth:
	@if [[ -z "$(PROVIDER)" || "$(PROVIDER)" == "claude" ]]; then \
		echo "==> claude /login"; claude /login; \
	fi
	@if [[ -z "$(PROVIDER)" || "$(PROVIDER)" == "kimi" ]]; then \
		echo "==> claude-code-proxy kimi auth login"; \
		command -v claude-code-proxy >/dev/null \
			&& claude-code-proxy kimi auth login \
			|| echo "  (claude-code-proxy not installed — brew install raine/claude-code-proxy/claude-code-proxy)"; \
	fi
	@if [[ -z "$(PROVIDER)" || "$(PROVIDER)" == "gemini" ]]; then \
		echo "==> cliproxyapi -login  (Google OAuth for Gemini — stores in ~/.cli-proxy-api/)"; \
		command -v cliproxyapi >/dev/null \
			&& echo "2" | cliproxyapi -login \
			|| echo "  (cliproxyapi not installed — brew install cliproxyapi)"; \
	fi
	@if [[ -z "$(PROVIDER)" || "$(PROVIDER)" == "codex" ]]; then \
		echo "==> cliproxyapi -codex-login"; \
		command -v cliproxyapi >/dev/null \
			&& cliproxyapi -codex-login \
			|| echo "  (cliproxyapi not installed — brew install cliproxyapi)"; \
	fi

# ── Supporting sidecars ───────────────────────────────────────────────────────

## cliproxyapi: CLIProxyAPI — wraps codex/gemini CLI auth as OpenAI-compatible API
## Install: brew install cliproxyapi  Login: codex login  or  gemini auth login
## Config is managed by chezmoi (~/.local/share/chezmoi/dot_config/cliproxyapi/config.yaml.tmpl)
## which resolves the API key from 1Password at apply time (r-cto-dev105 Law IV Pattern B).
CLIPROXYAPI_PORT ?= 8317
.PHONY: cliproxyapi
cliproxyapi:
	command -v cliproxyapi >/dev/null || { echo "cliproxyapi not installed — run: brew install cliproxyapi"; exit 1; }
	$(call start_server_self,$(CLIPROXYAPI_PORT),cliproxyapi -config $(HOME)/.config/cliproxyapi/config.yaml)
	$(call check_port,$(CLIPROXYAPI_PORT))

## routellm: RouteLLM difficulty-routing server
ROUTELLM_PORT ?= 6060
ROUTELLM_CFG  ?= $(HOME)/.config/routellm/config.yaml
.PHONY: routellm
routellm:
	$(call start_server_double_fork,$(ROUTELLM_PORT),uvx routellm.server --config $(ROUTELLM_CFG) --port $(ROUTELLM_PORT))
	$(call check_port,$(ROUTELLM_PORT))

## ai-open: open service UIs in Chrome — once per session (stamp in /tmp, resets on reboot)
## Skips any port not yet listening. Safe to call multiple times — no duplicate tabs.
AI_OPEN_STAMP ?= /tmp/.make-ai-open-$(shell id -u)
.PHONY: ai-open
ai-open:
	@if [ -f "$(AI_OPEN_STAMP)" ]; then \
		echo "  (UIs already opened this session — run: make ai-open-force to reopen)"; \
	else \
		nc -z localhost $(LITELLM_PORT) 2>/dev/null && open -a "Google Chrome" "http://localhost:$(LITELLM_PORT)/ui" || true; \
		nc -z localhost $(MLFLOW_PORT) 2>/dev/null && open -a "Google Chrome" "http://localhost:$(MLFLOW_PORT)" || true; \
		nc -z localhost $(TEMPORAL_UI_PORT) 2>/dev/null && open -a "Google Chrome" "http://localhost:$(TEMPORAL_UI_PORT)" || true; \
		nc -z localhost $(CCR_PORT) 2>/dev/null && open -a "Google Chrome" "http://localhost:$(CCR_PORT)" || true; \
		nc -z localhost $(KTAP_PORT) 2>/dev/null && open -a "Google Chrome" "http://localhost:$(KTAP_PORT)" || true; \
		nc -z localhost $(LLS_PORT) 2>/dev/null && open -a "Google Chrome" "http://localhost:$(LLS_PORT)/" || true; \
		open -a "Google Chrome" "https://console.anthropic.com/settings/usage" || true; \
		open -a "Google Chrome" "https://platform.openai.com/usage" || true; \
		open -a "Google Chrome" "https://platform.moonshot.cn/console/account" || true; \
		open -a "Google Chrome" "https://aistudio.google.com/app/usage?timeRange=last-28-days" || true; \
		open -a "Google Chrome" "https://z.ai/manage-apikey/billing" || true; \
		open -a "Google Chrome" "https://platform.minimax.io/user-center/payment/token-plan" || true; \
		open -a "Google Chrome" "https://platform.deepseek.com/usage" || true; \
		open -a "Google Chrome" "https://openrouter.ai/activity" || true; \
		open -a "Google Chrome" "https://console.groq.com/settings/usage" || true; \
		open -a "Google Chrome" "https://cloud.cerebras.ai/platform/usage" || true; \
		open -a "Google Chrome" "https://dashscope.console.aliyun.com/billing" || true; \
		touch "$(AI_OPEN_STAMP)"; \
	fi

## ai-open-force: open all service UIs unconditionally (clears once-per-session guard)
.PHONY: ai-open-force
ai-open-force:
	@rm -f "$(AI_OPEN_STAMP)"
	@$(MAKE) -f $(firstword $(MAKEFILE_LIST)) ai-open

## ai-status: health check for all sidecars
.PHONY: ai-status
ai-status:
	echo "PostgreSQL :$(POSTGRES_PORT): $$($(call port_ready,$(POSTGRES_PORT)) && echo ok || echo stopped)"
	echo "Redis      :$(REDIS_PORT): $$($(call port_ready,$(REDIS_PORT)) && echo ok || echo stopped)"
	echo "LiteLLM    :$(LITELLM_PORT): $$($(call port_ready,$(LITELLM_PORT)) && echo ok || echo stopped)"
	echo "MLflow     :$(MLFLOW_PORT): $$($(call port_ready,$(MLFLOW_PORT)) && echo ok || echo stopped)"
	echo "Temporal   :$(TEMPORAL_PORT): $$($(call port_ready,$(TEMPORAL_PORT)) && echo ok || echo stopped)"
	echo "CCR        :$(CCR_PORT): $$($(call port_ready,$(CCR_PORT)) && echo ok || echo stopped)"
	echo "kimi-proxy :$(KIMI_CLAUDE_PROXY_PORT): $$($(call port_ready,$(KIMI_CLAUDE_PROXY_PORT)) && echo ok || echo stopped)"
	echo "ktap       :$(KTAP_PORT): $$($(call port_ready,$(KTAP_PORT)) && echo ok || echo stopped)"
	echo "LM Studio  : $$(pgrep -x 'LM Studio' >/dev/null 2>&1 && echo ok || echo stopped)"

## ai-models: list available models with make invocation examples
.PHONY: ai-models
ai-models:
	echo ""
	echo "Cloud models — make ai MODEL=<name>"
	echo "──────────────────────────────────────────────────────"
	yq '.model_list[].model_name' "$(LITELLM_CFG)" 2>/dev/null | sort -u | grep -v '^lms/' | \
		while IFS= read -r name; do \
			case "$$name" in \
			*-free)    tag="FREE  -- provider free tier via OpenRouter" ;; \
			claude*)   tag="PLAN  -- Anthropic Max (~\$$20-100/mo flat)" ;; \
			kimi*)     tag="PLAN  -- Kimi Coding Plan (\$$19/mo flat)" ;; \
			glm*)      tag="PLAN  -- ZAI GLM Coding Plan \$$18/mo → Z_AI_PLAN_KEY" ;; \
			qwen*)     tag="PLAN  -- Alibaba Plan → ALIBABA_PLAN_KEY" ;; \
			minimax*)  tag="PLAN  -- MiniMax Token Plan \$$10-20/mo → MINIMAX_PLAN_KEY" ;; \
			routellm*) tag="PLAN+PLAN -- auto-routes kimi->claude by difficulty" ;; \
			gemini*)   tag="PLAN  -- Google CLI sub → make ai-auth PROVIDER=gemini" ;; \
			deepseek*) tag="PAYG  -- no flat-rate plan; use sparingly" ;; \
			or-*nemotron*free*)  tag="FREE  -- NVIDIA Nemotron via OpenRouter (rate-limited) → OPENROUTER_API_KEY" ;; \
			or-*nemotron*)       tag="PAYG  -- NVIDIA Nemotron via OpenRouter → OPENROUTER_API_KEY" ;; \
			or-*qwen*coder*free*)tag="FREE  -- Qwen3 Coder via OpenRouter (rate-limited) → OPENROUTER_API_KEY" ;; \
			or-*)                tag="PAYG  -- OpenRouter bridge → OPENROUTER_API_KEY" ;; \
			*)         tag="PAYG" ;; \
			esac; \
			printf '  make ai MODEL=%-32s # %s\n' "$$name" "$$tag"; \
		done || echo "  (config not found — run make ai-install)"
	echo ""
	echo "Local models — make ai-local, then: make ai-run MODEL=lms/<vendor>/<model>"
	echo "──────────────────────────────────────────────────────"
	lms ls 2>/dev/null | awk 'NF>=5 && $$4~/^[0-9]/ {printf "  make ai-run MODEL=lms/%-42s # FREE — %.1f GB\n", $$1, $$4+0}' | sort -k6 -n \
		|| echo "  (lms not running — start LM Studio or run: make lms-server)"
	echo ""
	echo "Entry points:"
	echo "  make ai                              # PLAN  — Anthropic Max (default)"
	echo "  make ai MODEL=kimi-k2.6              # PLAN  — any cloud model above"
	echo "  make ai HARNESS=aider                # swap AI harness"
	echo "  make ai-local                        # FREE  — local GPU (run make ai-run MODEL=lms/...)"
	echo "  make ai-cli MODEL=codex              # PLAN  — codex login"
	echo "  make ai-cli MODEL=gemini-proxy       # PLAN  — gemini auth login"
	echo "  make ai-auto                         # PLAN+PLAN — kimi (easy) → claude (hard)"

## ai-keys: show which env vars are required for each PLAN provider and where to get them
## Sources:
##   Z.AI:    https://z.ai/subscribe → account → API Keys (regular key, no special prefix)
##   MiniMax: https://platform.minimax.io/subscribe/token-plan — Token Plan $10-20/mo
##   Alibaba: https://bailian.console.aliyun.com/ → API Keys → ALIBABA_PLAN_KEY
##   Gemini:  make ai-auth PROVIDER=gemini — Google OAuth via cliproxyapi
##   Kimi:    claude-code-proxy handles auth — no extra key needed
.PHONY: ai-keys
ai-keys:
	@echo "══ PLAN provider keys (set in .envrc or 1Password) ══════"
	@printf "  %-28s %s\n" "Z_AI_PLAN_KEY" \
		"$$([ -n "$$Z_AI_PLAN_KEY" ] && echo "✓ set" || echo "✗ missing — z.ai → account → API Keys")"
	@printf "  %-28s %s\n" "MINIMAX_PLAN_KEY" \
		"$$([ -n "$$MINIMAX_PLAN_KEY" ] && echo "✓ set" || echo "✗ missing — platform.minimax.io/subscribe/token-plan")"
	@printf "  %-28s %s\n" "ALIBABA_PLAN_KEY" \
		"$$([ -n "$$ALIBABA_PLAN_KEY" ] && echo "✓ set" || echo "✗ missing — bailian.console.aliyun.com → API Keys")"
	@printf "  %-28s %s\n" "LITELLM_MASTER_KEY" \
		"$$([ -n "$$LITELLM_MASTER_KEY" ] && echo "✓ set" || echo "✗ missing — generate random, set in 1Password")"
	@echo ""
	@echo "══ PLAN providers requiring OAuth (no API key) ══════════"
	@printf "  %-28s %s\n" "Gemini (CLIProxyAPI)" \
		"$$(cliproxyapi status 2>/dev/null | grep -q authenticated && echo "✓ authenticated" || echo "✗ run: make ai-auth PROVIDER=gemini")"
	@printf "  %-28s %s\n" "Kimi (claude-code-proxy)" \
		"$$($(call port_ready,3457) && echo "✓ running :3457" || echo "✗ run: make ai")"

## ai-logs: push Claude Code session logs to MLflow
.PHONY: ai-logs
ai-logs:
	uv run "$(MLFLOW_LOG_SCRIPT)"

## ai-log: tail all sidecar logs from TNE_LOG_DIR (Ctrl-C to stop)
.PHONY: ai-log
ai-log:
	@mkdir -p "$(TNE_LOG_DIR)"
	@echo "Tailing logs from $(TNE_LOG_DIR) — Ctrl-C to stop"
	@tail -f \
		"$(TNE_LOG_DIR)/sidecar-$(LITELLM_PORT).log" \
		"$(TNE_LOG_DIR)/sidecar-$(MLFLOW_PORT).log" \
		"$(TNE_LOG_DIR)/sidecar-$(KTAP_PORT).log" \
		"$(TNE_LOG_DIR)/ktap.log" \
		"$(TNE_LOG_DIR)/tne-engine.log" \
		2>/dev/null || echo "(no log files yet — start services with make ai-local)"

## ai-test: canonical end-to-end check for the ai-* stack
##   Runs all three phases unconditionally — bias toward complete since ai-test
##   is invoked rarely (after `make ai` startup, not on every change):
##     Phase 1: tools, config, sidecars (no model calls) — ai-test-infra
##     Phase 2: live round-trip to every cloud model     — ai-test-models
##     Phase 3: quality probe ("2+2") on one per backend  — ai-test-quality
##   Reports ✓/✗ per check; exits 1 if Phase 3 quality probe regresses.
##   Sub-targets above are runnable individually for debugging.
.PHONY: ai-test test-ai
ai-test: ai-test-infra ai-test-models ai-test-quality
test-ai: ai-test

.PHONY: ai-test-infra
ai-test-infra:
	@echo "══ make ai (base stack) ══════════════════════════════"
	@command -v litellm >/dev/null 2>&1 || uvx litellm --version >/dev/null 2>&1 \
		&& echo "✓ litellm installed" \
		|| echo "✗ litellm missing — run: make ai-install"
	@command -v mlflow >/dev/null 2>&1 || uvx mlflow --version >/dev/null 2>&1 \
		&& echo "✓ mlflow installed" \
		|| echo "✗ mlflow missing — run: make ai-install"
	@command -v temporal >/dev/null 2>&1 \
		&& echo "✓ temporal installed" \
		|| echo "✗ temporal missing — run: brew install temporal"
	@command -v ccr >/dev/null 2>&1 \
		&& echo "✓ ccr (claude-code-router) installed" \
		|| echo "✗ ccr missing — run: npm install -g @anthropic-ai/claude-code-router"
	@test -f "$(LITELLM_CFG)" \
		&& echo "✓ litellm config found: $(LITELLM_CFG)" \
		|| echo "✗ litellm config missing at $(LITELLM_CFG) — run: make ai-install"
	@echo "  ports:"
	@$(call port_ready,5432) && echo "  ✓ postgres :5432" || echo "  ✗ postgres :5432 stopped"
	@$(call port_ready,6379) && echo "  ✓ redis    :6379" || echo "  ✗ redis    :6379 stopped"
	@$(call port_ready,$(MLFLOW_PORT))   && echo "  ✓ mlflow   :$(MLFLOW_PORT)"   || echo "  ✗ mlflow   :$(MLFLOW_PORT) stopped"
	@$(call port_ready,$(LITELLM_PORT))  && echo "  ✓ litellm  :$(LITELLM_PORT)"  || echo "  ✗ litellm  :$(LITELLM_PORT) stopped  → make litellm"
	@$(call port_ready,$(TEMPORAL_PORT)) && echo "  ✓ temporal :$(TEMPORAL_PORT)" || echo "  ✗ temporal :$(TEMPORAL_PORT) stopped  → make temporal"
	@# Verify temporal is using the persistent DB (not in-memory mode — workflows lost on restart)
	@if $(call port_ready,$(TEMPORAL_PORT)); then \
		_tpid=$$(pgrep -f "temporal server start-dev" | head -1); \
		if [ -n "$$_tpid" ] && lsof -p "$$_tpid" 2>/dev/null | grep -q "$(TEMPORAL_DB)"; then \
			echo "  ✓ temporal DB: $(TEMPORAL_DB) (persistent)"; \
		else \
			echo "  ✗ temporal DB: in-memory mode (workflows lost on restart) — run: make ai-stop && make temporal"; \
		fi; \
	fi
	@$(call port_ready,$(CCR_PORT))      && echo "  ✓ ccr      :$(CCR_PORT)"      || echo "  ✗ ccr      :$(CCR_PORT) stopped      → make ccr"
	@echo ""
	@echo "══ make ai-local (+ LM Studio local inference) ═══════"
	@command -v lms >/dev/null 2>&1 \
		&& echo "✓ lms (LM Studio CLI) installed" \
		|| echo "✗ lms missing — install LM Studio from lmstudio.ai"
	@$(call port_ready,1234) && echo "  ✓ lms-server :1234" || echo "  ✗ lms-server :1234 stopped  → make lms-server"
	@echo ""
	@echo "══ make ai-cli (+ CLIProxyAPI for Gemini/Codex subs) ══"
	@command -v cliproxyapi >/dev/null 2>&1 \
		&& echo "✓ cliproxyapi installed" \
		|| echo "✗ cliproxyapi missing — run: brew install cliproxyapi"
	@$(call port_ready,$(CLIPROXYAPI_PORT)) \
		&& echo "  ✓ cliproxyapi :$(CLIPROXYAPI_PORT)" \
		|| echo "  ✗ cliproxyapi :$(CLIPROXYAPI_PORT) stopped  → make cliproxyapi"
	@echo ""
	@echo "══ make ai-plan (+ claude-code-proxy for Kimi/ChatGPT) "
	@command -v claude-code-proxy >/dev/null 2>&1 \
		&& echo "✓ claude-code-proxy installed" \
		|| echo "✗ claude-code-proxy missing — run: brew install raine/claude-code-proxy/claude-code-proxy"
	@grep -q "token-plan.*maas.aliyuncs.com" "$(LITELLM_CFG)" 2>/dev/null \
		&& echo "✓ litellm kimi-k2.6 → Alibaba MaaS (PLAN)" \
		|| echo "✗ litellm config: kimi-k2.6 not on MaaS plan"
	@grep -q "localhost:$(KIMI_CLAUDE_PROXY_PORT)" "$(LITELLM_CFG)" 2>/dev/null \
		&& echo "✓ litellm kimi-k2.6-proxy → localhost:$(KIMI_CLAUDE_PROXY_PORT) (PLAN fallback)" \
		|| echo "⚠ litellm config: kimi-k2.6-proxy not wired to claude-code-proxy"
	@grep -q "localhost:$(CLIPROXYAPI_PORT)" "$(LITELLM_CFG)" 2>/dev/null \
		&& echo "✓ litellm gemini → localhost:$(CLIPROXYAPI_PORT) (PLAN)" \
		|| echo "✗ litellm config: gemini still PAYG (expected localhost:$(CLIPROXYAPI_PORT))"
	@$(call port_ready,$(KIMI_CLAUDE_PROXY_PORT)) \
		&& echo "  ✓ claude-code-proxy :$(KIMI_CLAUDE_PROXY_PORT)" \
		|| echo "  ✗ claude-code-proxy :$(KIMI_CLAUDE_PROXY_PORT) stopped  → make kimi-claude-proxy"
	@echo ""
	@echo "══ make ai-auto (+ RouteLLM difficulty router) ════════"
	@$(call port_ready,$(ROUTELLM_PORT)) \
		&& echo "  ✓ routellm :$(ROUTELLM_PORT)" \
		|| echo "  ✗ routellm :$(ROUTELLM_PORT) stopped  → make routellm"
	@echo ""
	@echo "══ command smoke tests ════════════════════════════════"
	@$(MAKE) --no-print-directory ai-help >/dev/null 2>&1 \
		&& echo "✓ ai-help" || echo "✗ ai-help"
	@$(MAKE) --no-print-directory ai-status >/dev/null 2>&1 \
		&& echo "✓ ai-status" || echo "✗ ai-status"
	@yq e '.' "$(LITELLM_CFG)" >/dev/null 2>&1 \
		&& echo "✓ litellm config is valid YAML" \
		|| echo "✗ litellm config is invalid YAML — check $(LITELLM_CFG)"
	@if $(call port_ready,$(CLIPROXYAPI_PORT)); then \
		if [[ -n "${CLIPROXYAPI_KEY}" ]]; then \
			_resp=$$(curl -sf -w "\n%{http_code}" "http://localhost:$(CLIPROXYAPI_PORT)/v1/models" \
				-H "Authorization: Bearer $${CLIPROXYAPI_KEY}"); \
			_code=$$(echo "$$_resp" | tail -1); \
			if [[ "$$_code" == "200" ]]; then \
				_count=$$(echo "$$_resp" | sed '$$d' | jq '.data | length'); \
				echo "✓ cliproxyapi auth OK ($$_count models)"; \
			else \
				echo "⚠ cliproxyapi auth failed HTTP $$_code — key may be stale"; \
			fi; \
		else \
			echo "⚠ ai-sync: CLIPROXYAPI_KEY missing — export it to enable sync"; \
		fi; \
	else \
		echo "⚠ ai-sync: cliproxyapi not running — run: make cliproxyapi"; \
	fi
	@echo ""
	@echo "══ quick health ═══════════════════════════════════════"
	@$(call port_ready,$(LITELLM_PORT)) \
		&& curl -sf http://localhost:$(LITELLM_PORT)/health/readiness >/dev/null 2>&1 \
		&& echo "✓ LiteLLM /health/readiness" \
		|| echo "✗ LiteLLM /health/readiness failed"
	@echo ""
	@echo "══ MLflow callback wiring ════════════════════════════"
	@ps ewww $$(pgrep -f "litellm --config" | head -1) 2>/dev/null | tr ' ' '\n' | grep -q "^MLFLOW_TRACKING_URI=" \
		&& echo "✓ LiteLLM process has MLFLOW_TRACKING_URI" \
		|| echo "✗ LiteLLM missing MLFLOW_TRACKING_URI — run: make litellm.stop litellm"
	@ps ewww $$(pgrep -f "litellm --config" | head -1) 2>/dev/null | tr ' ' '\n' | grep -q "^MLFLOW_EXPERIMENT_NAME=" \
		&& echo "✓ LiteLLM process has MLFLOW_EXPERIMENT_NAME=tne-costs" \
		|| echo "✗ LiteLLM missing MLFLOW_EXPERIMENT_NAME — run: make litellm.stop litellm"
	@$(call port_ready,$(MLFLOW_PORT)) \
		&& { _exps=$$(curl -sf -X POST "http://localhost:$(MLFLOW_PORT)/api/2.0/mlflow/experiments/search" \
				-H "Content-Type: application/json" \
				-d '{"max_results":10}' \
				| jq -r '[.experiments[].name] | join(", ")' 2>/dev/null); \
			echo "✓ MLflow experiments: $$_exps"; } \
		|| echo "✗ MLflow API unreachable at :$(MLFLOW_PORT)"
	@echo ""
	@echo "══ E2E: LiteLLM → MLflow trace round-trip ════════════"
	@$(MAKE) --no-print-directory litellm-test-trace 2>&1 | sed 's/^/  /'

## litellm-test-trace: E2E round-trip — sends a real prompt directly to LiteLLM via curl,
##   waits up to 10s, then checks MLflow tne-costs for a new run created after the call.
##   Verifies: LiteLLM routes the call AND fires the MLflow success_callback.
##   Uses deepseek-v4-flash (cheap PAYG) by default; override with TRACE_TEST_MODEL=.
##   Auth: uses LITELLM_MASTER_KEY (resolved from 1Password if needed).
TRACE_TEST_MODEL ?= deepseek-v4-flash
.PHONY: litellm-test-trace
litellm-test-trace:
	@$(call port_ready,$(LITELLM_PORT)) || { echo "✗ LiteLLM not running — run: make ai"; exit 1; }
	@$(call port_ready,$(MLFLOW_PORT)) || { echo "✗ MLflow not running — run: make mlflow"; exit 1; }
	@_key=$${LITELLM_MASTER_KEY}; \
	[[ "$$_key" == op://* ]] && _key=$$(op read "$$_key" 2>/dev/null) || true; \
	[ -n "$$_key" ] || { echo "✗ LITELLM_MASTER_KEY not set — source .envrc or run op signin"; exit 1; }; \
	_before=$$(curl -sf -X POST "http://localhost:$(MLFLOW_PORT)/api/2.0/mlflow/runs/search" \
		-H "Content-Type: application/json" \
		-d '{"experiment_ids":["1"],"max_results":1,"order_by":["start_time DESC"]}' \
		| jq -r '.runs[0].info.run_id // "none"'); \
	echo "  baseline run_id: $$_before"; \
	echo "  sending prompt via LiteLLM curl ($(TRACE_TEST_MODEL))..."; \
	_resp=$$(curl -sf -X POST "http://localhost:$(LITELLM_PORT)/v1/chat/completions" \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer $$_key" \
		-d "{\"model\":\"$(TRACE_TEST_MODEL)\",\"messages\":[{\"role\":\"user\",\"content\":\"Say: pong\"}],\"max_tokens\":5}" 2>&1); \
	echo "$$_resp" | jq -r '.choices[0].message.content // empty' 2>/dev/null \
		|| { echo "✗ LiteLLM call failed: $$(echo $$_resp | head -c 200)"; exit 1; }; \
	echo "  call succeeded, waiting 10s for MLflow callback..."; \
	sleep 10; \
	_after=$$(curl -sf -X POST "http://localhost:$(MLFLOW_PORT)/api/2.0/mlflow/runs/search" \
		-H "Content-Type: application/json" \
		-d '{"experiment_ids":["1"],"max_results":1,"order_by":["start_time DESC"]}' \
		| jq -r '.runs[0].info.run_id // "none"'); \
	if [ "$$_after" != "$$_before" ] && [ "$$_after" != "none" ]; then \
		echo "✓ MLflow trace created: run_id=$${_after:0:8}"; \
		echo "  → http://localhost:$(MLFLOW_PORT)/#/experiments/1/runs/$$_after"; \
	else \
		echo "✗ No new trace in MLflow tne-costs after call — check LiteLLM mlflow callback"; \
		echo "  run: make ai-log  to inspect sidecar-$(LITELLM_PORT).log"; \
	fi

## litellm-test-mlflow: live end-to-end check — writes a test run to MLflow tne-costs experiment.
##   Requires: make litellm mlflow (both running). Confirms MLFLOW_TRACKING_URI is wired correctly.
.PHONY: litellm-test-mlflow
litellm-test-mlflow:
	@echo "==> testing LiteLLM → MLflow trace pipeline"
	@$(call port_ready,$(MLFLOW_PORT)) || { echo "✗ MLflow not running on :$(MLFLOW_PORT) — run: make mlflow"; exit 1; }
	@$(call port_ready,$(LITELLM_PORT)) || { echo "✗ LiteLLM not running on :$(LITELLM_PORT) — run: make litellm"; exit 1; }
	@ps ewww $$(pgrep -f "litellm --config" | head -1) 2>/dev/null | tr ' ' '\n' | grep -q "^MLFLOW_TRACKING_URI=" \
		|| { echo "✗ LiteLLM missing MLFLOW_TRACKING_URI — run: make litellm.stop litellm"; exit 1; }
	@_uri=http://localhost:$(MLFLOW_PORT); \
	_exp_id=$$(curl -sf "$$_uri/api/2.0/mlflow/experiments/get-by-name?experiment_name=tne-costs" \
		| jq -r '.experiment.experiment_id // empty'); \
	[ -n "$$_exp_id" ] || { echo "✗ tne-costs experiment not found in MLflow"; exit 1; }; \
	_run_id=$$(curl -sf -X POST "$$_uri/api/2.0/mlflow/runs/create" \
		-H "Content-Type: application/json" \
		-d "{\"experiment_id\":\"$$_exp_id\",\"run_name\":\"litellm-test-mlflow-$$(date +%Y-%m-%d)\",\"tags\":[{\"key\":\"source\",\"value\":\"make litellm-test-mlflow\"}]}" \
		| jq -r '.run.info.run_id // empty'); \
	[ -n "$$_run_id" ] || { echo "✗ Failed to create MLflow run"; exit 1; }; \
	curl -sf -X POST "$$_uri/api/2.0/mlflow/runs/log-metric" \
		-H "Content-Type: application/json" \
		-d "{\"run_id\":\"$$_run_id\",\"key\":\"latency_ms\",\"value\":42,\"timestamp\":$$(date +%s000),\"step\":0}" >/dev/null; \
	curl -sf -X POST "$$_uri/api/2.0/mlflow/runs/update" \
		-H "Content-Type: application/json" \
		-d "{\"run_id\":\"$$_run_id\",\"status\":\"FINISHED\",\"end_time\":$$(date +%s000)}" >/dev/null; \
	echo "✓ MLflow run written: run_id=$${_run_id:0:8}"; \
	echo "  → $$_uri/#/experiments/$$_exp_id/runs/$$_run_id"

## ai-test-models: Phase 2 of `make ai-test` — live round-trip per cloud model
##   Sends 'pong' prompt to every model in LITELLM_CFG. Skips local (lms/*, lls/*).
##   claude-* models tested via `claude -p` (OAuth token flow, not curl).
##   Thinking models (deepseek-reasoner, minimax-*): checks reasoning_content fallback.
##   Reports ✓/✗ per model with response preview and final pass/fail count.
.PHONY: ai-test-models
ai-test-models:
	@$(call port_ready,$(LITELLM_PORT)) || { echo "✗ LiteLLM not running — run: make ai"; exit 1; }
	@echo "==> live model round-trips via LiteLLM :$(LITELLM_PORT)"
	@pass=0; fail=0; \
	for model in $$(yq '.model_list[].model_name' "$(LITELLM_CFG)" 2>/dev/null \
			| grep -v '^lms/' | grep -v '^lls/'); do \
		case "$$model" in \
		claude-*) \
			echo "  – $$model: skipped (Max plan OAuth — tested implicitly via Claude Code session)"; \
			continue; \
			;; \
		*-proxy) \
			result=$$(curl -sf --max-time 30 -X POST \
				http://localhost:$(LITELLM_PORT)/v1/chat/completions \
				-H "Content-Type: application/json" \
				-H "Authorization: Bearer $${LITELLM_MASTER_KEY}" \
				-d "{\"model\":\"$$model\",\"stream\":true,\"messages\":[{\"role\":\"user\",\"content\":\"reply with the single word: pong\"}],\"max_tokens\":200}" \
				2>&1); \
			reply=$$(echo "$$result" \
				| python3 -c 'import sys,json; chunks=[l for l in sys.stdin if l.startswith("data:") and l.strip()!="data: [DONE]"]; print("".join(json.loads(c[5:])["choices"][0]["delta"].get("content","") for c in chunks if json.loads(c[5:]).get("choices",[{}])[0].get("delta",{}).get("content")).strip()[:60])' \
				2>/dev/null); \
			;; \
		*) \
			result=$$(curl -sf --max-time 30 -X POST \
				http://localhost:$(LITELLM_PORT)/v1/chat/completions \
				-H "Content-Type: application/json" \
				-H "Authorization: Bearer $${LITELLM_MASTER_KEY}" \
				-d "{\"model\":\"$$model\",\"messages\":[{\"role\":\"user\",\"content\":\"reply with the single word: pong\"}],\"max_tokens\":200}" \
				2>&1); \
			reply=$$(echo "$$result" | python3 -c \
				'import sys,json; r=json.load(sys.stdin); m=r["choices"][0]["message"]; print((m.get("content") or m.get("reasoning_content","")).strip()[:60])' \
				2>/dev/null); \
			;; \
		esac; \
		if [ -n "$$reply" ]; then \
			echo "  ✓ $$model: $$reply"; pass=$$((pass+1)); \
		else \
			err=$$(echo "$${result:-}" | python3 -c \
				'import sys,json; d=json.load(sys.stdin); print(d.get("error",{}).get("message","?")[:80])' \
				2>/dev/null || echo "$${result:-}" | head -c 80); \
			echo "  ✗ $$model: $$err"; fail=$$((fail+1)); \
		fi; \
	done; \
	echo ""; echo "==> $$pass passed / $$fail failed"

## ai-test-quality: Phase 3 of `make ai-test` — quality probe per backend
##   Sends a specific prompt ("2+2") and checks output matches expected pattern.
##   Uses one representative model per backend (override via AI_QUALITY_MODELS).
##   Exits 1 if any model misses — turns ai-test into a real CI pre-flight.
AI_QUALITY_MODELS ?= qwen-max gpt-5.4-mini gemini-2.5-flash deepseek-v4-pro kimi-k2.6 minimax-m2.7 glm-4.7-flash or-nemotron-super-120b
.PHONY: ai-test-quality
ai-test-quality:
	@$(call port_ready,$(LITELLM_PORT)) || { echo "✗ LiteLLM not running — run: make ai"; exit 1; }
	@echo ""
	@echo "══ Tier 3: quality gate ══════════════════════════════"
	@_key=$${LITELLM_MASTER_KEY}; \
	[[ "$$_key" == op://* ]] && _key=$$(op read "$$_key" 2>/dev/null) || true; \
	pass=0; fail=0; \
	for model in $(AI_QUALITY_MODELS); do \
		result=$$(curl -sf --max-time 45 -X POST \
			http://localhost:$(LITELLM_PORT)/v1/chat/completions \
			-H "Content-Type: application/json" \
			-H "Authorization: Bearer $$_key" \
			-d "{\"model\":\"$$model\",\"messages\":[{\"role\":\"user\",\"content\":\"What is 2+2? Reply with just the digit.\"}],\"max_tokens\":10}" \
			2>/dev/null); \
		reply=$$(echo "$$result" | python3 -c \
			'import sys; raw=sys.stdin.buffer.read().decode("utf-8","replace"); import json; d=json.loads(raw); m=d["choices"][0]["message"]; print((m.get("content") or m.get("reasoning_content","")).strip()[:20])' \
			2>/dev/null); \
		if echo "$$reply" | grep -q "4"; then \
			echo "  ✓ $$model: '$$reply'"; pass=$$((pass+1)); \
		else \
			echo "  ✗ $$model: expected '4', got '$$reply'"; fail=$$((fail+1)); \
		fi; \
	done; \
	echo ""; echo "==> quality gate: $$pass passed / $$fail failed"; \
	[ "$$fail" -eq 0 ] || exit 1

## ai-sync: write-back sync — upsert new models from live provider catalogs into LITELLM_CFG
##   Currently syncs CLIProxyAPI :$(CLIPROXYAPI_PORT) (gemini + codex/gpt-5 subscriptions).
##   Add-only: existing entries are preserved; nothing is removed.
##   After sync: restart LiteLLM to activate new entries (make litellm).
##   Extend: add ai-sync-<provider> targets and list them as prerequisites here.
.PHONY: ai-sync ai-sync-cliproxyapi
ai-sync: ai-sync-cliproxyapi
	@echo "  restart LiteLLM to activate: make litellm"

ai-sync-cliproxyapi:
	@$(call port_ready,$(CLIPROXYAPI_PORT)) \
		|| { echo "✗ cliproxyapi not running — run: make cliproxyapi"; exit 1; }
	@_key="${CLIPROXYAPI_KEY}"; \
	if [[ -z "$$_key" ]]; then \
		echo "✗ CLIPROXYAPI_KEY not set — run a new shell after install-1password.sh loads it via op inject"; \
		exit 1; \
	fi; \
	echo "==> syncing CLIProxyAPI :$(CLIPROXYAPI_PORT) → $(LITELLM_CFG)"; \
	_resp=$$(curl -s -w "\n%{http_code}" "http://localhost:$(CLIPROXYAPI_PORT)/v1/models" \
		-H "Authorization: Bearer $$_key"); \
	_code=$$(echo "$$_resp" | tail -1); \
	_body=$$(echo "$$_resp" | sed '$$d'); \
	if [[ "$$_code" != "200" ]]; then \
		echo "✗ CLIProxyAPI returned HTTP $$_code (expected 200)"; \
		echo "  body: $$_body"; \
		exit 1; \
	fi; \
	echo "$$_body" | python3 -c "import sys,json,subprocess; data=json.load(sys.stdin); cfg='$(LITELLM_CFG)'; port='$(CLIPROXYAPI_PORT)'; existing=set(subprocess.check_output(['yq','.model_list[].model_name',cfg],text=True).split()); new=[m['id'] for m in sorted(data['data'],key=lambda x:x['id']) if m['id'] not in existing]; [subprocess.run(['yq','-i','.model_list+=['+json.dumps({'model_name':mid,'litellm_params':{'model':'openai/'+mid,'api_base':'http://localhost:'+port,'api_key':'os.environ/CLIPROXYAPI_KEY'}})+']',cfg]) for mid in new]; print('  ✓ added: '+', '.join(new) if new else '  ✓ already in sync — no new models')"

## ai-latest-models: query each provider API for their current model list; diff against config
##   Requires: provider API keys in env. Reports new models not yet in LITELLM_CFG.
.PHONY: ai-latest-models
ai-latest-models:
	@echo "==> querying providers for latest model names"
	@echo ""
	@echo "── Anthropic ────────────────────────────────────────"
	@curl -sf https://api.anthropic.com/v1/models \
		-H "x-api-key: $${ANTHROPIC_API_KEY}" -H "anthropic-version: 2023-06-01" \
		| python3 -c 'import sys,json; [print(" ", m["id"]) for m in json.load(sys.stdin).get("data",[])]' \
		2>/dev/null || echo "  (skipped — ANTHROPIC_API_KEY not set or request failed)"
	@echo ""
	@echo "── Moonshot / Kimi ──────────────────────────────────"
	@curl -sf https://api.moonshot.ai/v1/models \
		-H "Authorization: Bearer $${MOONSHOT_API_KEY}" \
		| python3 -c 'import sys,json; [print(" ", m["id"]) for m in json.load(sys.stdin).get("data",[])]' \
		2>/dev/null || echo "  (skipped — MOONSHOT_API_KEY not set or request failed)"
	@echo ""
	@echo "── Z.AI / GLM ───────────────────────────────────────"
	@curl -sf https://api.z.ai/api/anthropic/v1/models \
		-H "x-api-key: $${Z_AI_PLAN_KEY}" -H "anthropic-version: 2023-06-01" \
		| python3 -c 'import sys,json; [print(" ", m.get("id","?")) for m in json.load(sys.stdin).get("data",[])]' \
		2>/dev/null || echo "  (skipped — Z_AI_PLAN_KEY not set or request failed)"
	@echo ""
	@echo "── MiniMax ──────────────────────────────────────────"
	@curl -sf https://api.minimax.io/v1/models \
		-H "Authorization: Bearer $${MINIMAX_API_KEY}" \
		| python3 -c 'import sys,json; [print(" ", m["id"]) for m in json.load(sys.stdin).get("data",[])]' \
		2>/dev/null || echo "  (skipped — MINIMAX_API_KEY not set or request failed)"
	@echo ""
	@echo "── DeepSeek ─────────────────────────────────────────"
	@curl -sf https://api.deepseek.com/models \
		-H "Authorization: Bearer $${DEEPSEEK_API_KEY}" \
		| python3 -c 'import sys,json; [print(" ", m["id"]) for m in json.load(sys.stdin).get("data",[])]' \
		2>/dev/null || echo "  (skipped — DEEPSEEK_API_KEY not set or request failed)"
	@echo ""
	@echo "── Qwen / DashScope ─────────────────────────────────"
	@curl -sf https://dashscope-intl.aliyuncs.com/compatible-mode/v1/models \
		-H "Authorization: Bearer $${ALIBABA_API_KEY}" \
		| python3 -c 'import sys,json; [print(" ", m["id"]) for m in json.load(sys.stdin).get("data",[])]' \
		2>/dev/null || echo "  (skipped — ALIBABA_API_KEY not set or request failed)"
	@echo ""
	@echo "── CLIProxyAPI :$(CLIPROXYAPI_PORT) (gemini/codex/gpt-5 subscription) ──"
	@$(call port_ready,$(CLIPROXYAPI_PORT)) \
		&& curl -sf http://localhost:$(CLIPROXYAPI_PORT)/v1/models \
			-H "Authorization: Bearer $${CLIPROXYAPI_KEY}" \
			| python3 -c \
				'import sys,json; ids=sorted(m["id"] for m in json.load(sys.stdin)["data"]); [print("  ",i) for i in ids]' \
			2>/dev/null \
		|| echo "  (skipped — cliproxyapi not running on :$(CLIPROXYAPI_PORT))"
	@echo ""
	@echo "── In $(LITELLM_CFG) ────────────────────────────────"
	@yq '.model_list[].model_name' "$(LITELLM_CFG)" 2>/dev/null \
		| grep -v '^lms/' | grep -v '^lls/' | sed 's/^/  /'

## ai-test-ui: playwright smoke test — verify each service UI renders correctly
##   Requires: make ai (sidecars up). Saves failure screenshots to /tmp.
.PHONY: ai-test-ui
ai-test-ui:
	@echo "==> AI sidecar UI smoke tests (playwright)"
	@python3 $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../bin/check-ai-ui.py

## ai-test-ui-litellm: check only LiteLLM Admin UI
.PHONY: ai-test-ui-litellm
ai-test-ui-litellm:
	@python3 $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../bin/check-ai-ui.py --service litellm

## ai-test-ui-mlflow: check only MLflow UI
.PHONY: ai-test-ui-mlflow
ai-test-ui-mlflow:
	@python3 $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../bin/check-ai-ui.py --service mlflow

## ai-ps: process status of all sidecars
.PHONY: ai-ps
ai-ps: mlflow.ps litellm.ps temporal.ps ccr.ps
	brew services list | grep -E "postgresql|redis" | awk '{printf "%-10s %s\n", $$1, $$2}'

## ai-stop: stop all sidecars (brew services stop for postgres/redis, SIGTERM for others)
.PHONY: ai-stop
ai-stop: $(MLFLOW_PORT).stop litellm.stop $(TEMPORAL_PORT).stop $(CCR_PORT).stop
	brew services stop temporal 2>/dev/null || true
	brew services stop redis 2>/dev/null || true
	brew services stop postgresql@17 2>/dev/null || brew services stop postgresql 2>/dev/null || true

## ai-local-stop: stop sidecars + LM Studio + restore GPU memory limit
.PHONY: ai-local-stop
ai-local-stop: ai-stop
	lms server stop
	sudo sysctl iogpu.wired_limit_mb=0

## ai-install: install AI CLI tools via brew + uv (run once per machine, no external scripts)
##   Installs: litellm mlflow redis postgresql@17 codex gemini-cli kimi-cli qwen-code lm-studio
##   Then runs: make ai-server  to start sidecars
.PHONY: ai-install
ai-install:
	echo "==> brew: core AI infrastructure"
	for pkg in redis postgresql@17 yq; do \
		command -v "$$pkg" >/dev/null 2>&1 || brew install "$$pkg"; \
	done
	echo "==> brew: AI CLI coding plan providers"
	for pkg in codex gemini-cli qwen-code kimi-cli; do \
		command -v "$$pkg" >/dev/null 2>&1 || brew install "$$pkg" 2>/dev/null || echo "  ($$pkg not in brew — skip)"; \
	done
	echo "==> brew: CLIProxyAPI (wraps gemini-cli/codex as OpenAI-compatible API on :8317)"
	command -v cliproxyapi >/dev/null 2>&1 || brew install cliproxyapi 2>/dev/null || echo "  (cliproxyapi not in brew — skip)"
	echo "==> uv: litellm proxy + mlflow tracking"
	uv tool install 'litellm[proxy]' 2>/dev/null || uvx litellm --version >/dev/null
	uv tool install mlflow 2>/dev/null || uvx mlflow --version >/dev/null
	uv tool install prisma 2>/dev/null || command -v prisma >/dev/null
	echo "==> prisma: generate client for LiteLLM spend tracking"
	_venv=$$(pipx environment --value PIPX_LOCAL_VENVS 2>/dev/null)/litellm; \
	_schema=$$_venv/lib/python*/site-packages/litellm/proxy/schema.prisma; \
	$$_venv/bin/python -m prisma generate --schema $$_schema
	mkdir -p $$(dirname $(PRISMA_STAMP)) && touch $(PRISMA_STAMP)
	echo "==> brew: tne-engine-worker (persistent Temporal worker — r-cto-dev129)"
	brew tap tne-ai/tne-tap 2>/dev/null || true
	brew list tne-engine-worker &>/dev/null 2>&1 || brew install tne-ai/tne-tap/tne-engine-worker 2>/dev/null || echo "  (tne-engine-worker install failed — worker will start transiently at session start)"
	echo "==> brew services: start redis + postgresql + tne-engine-worker"
	brew services start redis 2>/dev/null || true
	brew services start postgresql@17 2>/dev/null || brew services start postgresql 2>/dev/null || true
	brew list tne-engine-worker &>/dev/null 2>&1 && brew services start tne-engine-worker 2>/dev/null || true
	echo "==> creating litellm database"
	createdb $(LITELLM_DB) 2>/dev/null || true
	echo "==> litellm config"
	mkdir -p "$(HOME)/.config/litellm"
	[[ -f "$(LITELLM_CFG)" ]] && echo "  config exists: $(LITELLM_CFG)" || echo "  WARNING: $(LITELLM_CFG) missing — copy from tne-plugins or install-ai.sh"
	echo "==> Done. Run: make ai-status  to verify  |  make ai  to launch"

## ai-server: start all background sidecars without launching the AI harness
## Use this to pre-warm sidecars before a session (postgres redis mlflow litellm)
.PHONY: ai-server
ai-server: postgres redis mlflow litellm
	echo "Sidecars running. Launch with: make ai [MODEL=...]"

## set-gpu-max-memory: allocate maximum RAM to GPU (needed for large local models)
.PHONY: set-gpu-max-memory
set-gpu-max-memory:
	MEMORY="$$(($$(sysctl -n hw.memsize) / 2 ** 30))" && \
	if ((MEMORY <= 16)); then MEMORY_GPU=2; \
	elif ((MEMORY <= 32)); then MEMORY_GPU=4; \
	elif ((MEMORY <= 64)); then MEMORY_GPU=5; \
	elif ((MEMORY <= 128)); then MEMORY_GPU=9; \
	else MEMORY_GPU=10; fi && \
	sudo sysctl iogpu.wired_limit_mb=$$(bc -l <<<"($$MEMORY - $$MEMORY_GPU)*1024") || echo "set-gpu-max-memory: sudo failed — run manually or add to sudoers"

## lms-server: start LM Studio local inference server
.PHONY: lms-server
lms-server:
	lms server start

## lls-start: start llama-server router (llama.cpp b9200+ native multi-model swap)
## Uses ~/.config/litellm/llama-presets.ini — add new models there after downloading via LM Studio.
## One model loaded at a time (--models-max 1); swaps automatically on model field change.
## Port 8081 (8080 is reserved for CLIProxyAPI/Gemini).
.PHONY: lls-start
lls-start: lls-sync
	@$(call port_ready,8081) && echo "llama-server already running on :8081" || \
		(llama-server \
			--models-preset "$(HOME)/.config/litellm/llama-presets.ini" \
			--models-max 1 \
			--port 8081 \
			--log-disable & \
		for i in $$(seq 1 20); do \
			sleep 1; \
			out=$$(curl -sf http://localhost:8081/v1/models 2>/dev/null) && \
			echo "$$out" | yq -p json '.data | length | "llama-server ready — " + tostring + " models available"' 2>/dev/null && \
			break; \
			[ "$$i" = "20" ] && echo "⚠️  llama-server did not start within 20s" && exit 1; \
		done)

## lls-stop: stop llama-server router
.PHONY: lls-stop
lls-stop:
	@pkill -f "llama-server.*8081" && echo "llama-server stopped" || echo "llama-server not running"

## lls-sync: sync lls/* litellm entries + llama-presets.ini from lms ls --json (GGUF only)
## Setup: open LM Studio → Browse → Staff Picks → download GGUF variants → run make lls-sync
## Discovers all GGUF LLMs via `lms ls --json`; skips safetensors (llama-server can't load them).
## lls/<vendor>/<model> → openai/<gguf-basename> in litellm; preset pinned to ctx=100000, kv=q8_0.
## lls/auto = largest (most capable) GGUF; fallback chain escalates down to smallest.
## Run after adding/removing models; safe to re-run (idempotent).
LLS_CTX ?= 100000
LLS_PRESETS ?= $(HOME)/.config/litellm/llama-presets.ini
.PHONY: lls-sync
lls-sync:
	@command -v lms >/dev/null 2>&1 || { echo "lms CLI not found — install LM Studio first"; exit 1; }
	@command -v jq  >/dev/null 2>&1 || { echo "jq not found — brew install jq"; exit 1; }
	@mkdir -p $$(dirname $(LLS_PRESETS))
	@echo "==> Removing old lls/* entries from $(LITELLM_CFG)"
	@yq -i 'del(.model_list[] | select(.model_name | test("^lls/")))' "$(LITELLM_CFG)"
	@echo "==> Discovering GGUF models via lms ls --json (sorted largest → smallest)"
	@_lls_index=/tmp/lls-index-$$$$.tsv; \
	  lms ls --json 2>/dev/null \
	  | jq -r '[.[] | select(.type=="llm" and .format=="gguf")] | .[] | [.modelKey, .quantization.name] | @tsv' \
	  | while IFS=$$'\t' read -r model_key quant; do \
	      model_leaf=$$(basename "$$model_key"); \
	      gguf=$$(find "$(HOME)/.cache/lm-studio/models" -name "*$${quant}*.gguf" \
	               ! -name "mmproj*" -ipath "*$${model_leaf}*" 2>/dev/null | head -1); \
	      [[ -z "$$gguf" ]] && { echo "  skip $$model_key (no GGUF found for $${model_leaf}/$${quant})"; continue; }; \
	      base=$$(basename "$$gguf" .gguf); \
	      size=$$(stat -f%z "$$gguf" 2>/dev/null || stat -c%s "$$gguf" 2>/dev/null || echo 0); \
	      echo "$$size	$$model_key	$$base	$$gguf"; \
	    done | sort -rn > "$$_lls_index"; \
	  while IFS=$$'\t' read -r _sz model_key base gguf; do \
	      lls_name="lls/$$model_key"; \
	      grep -qF "[$$base]" "$(LLS_PRESETS)" 2>/dev/null || \
	        printf '\n[%s]\nmodel = %s\nctx-size = %s\nflash-attn = on\ncache-type-k = q8_0\ncache-type-v = q8_0\n' \
	          "$$base" "$$gguf" "$(LLS_CTX)" >> "$(LLS_PRESETS)"; \
	      yq -i ".model_list += [{\"model_name\": \"$$lls_name\", \"litellm_params\": {\"model\": \"openai/$$base\", \"api_base\": \"http://localhost:$(LLS_PORT)/v1\", \"api_key\": \"none\", \"extra_body\": {\"cache_prompt\": true}}}]" "$(LITELLM_CFG)"; \
	      echo "  + $$lls_name → $$base ($$(( _sz / 1024 / 1024 / 1024 ))GB)"; \
	    done < "$$_lls_index"; \
	  echo "==> Setting lls/auto (largest GGUF) + fallback chain (largest → smallest)"; \
	  first_base=$$(head -1 "$$_lls_index" | cut -f3); \
	  first_gguf=$$(head -1 "$$_lls_index" | cut -f4); \
	  yq -i ".model_list += [{\"model_name\": \"lls/auto\", \"litellm_params\": {\"model\": \"openai/$$first_base\", \"api_base\": \"http://localhost:$(LLS_PORT)/v1\", \"api_key\": \"none\", \"extra_body\": {\"cache_prompt\": true}}}]" "$(LITELLM_CFG)"; \
	  fallbacks=$$(awk -F'\t' 'BEGIN{s=""} {s=s (s?",":"") "\"lls/" $$2 "\""}  END{print s}' "$$_lls_index"); \
	  yq -i ".router_settings.routing_strategy = \"simple-shuffle\"" "$(LITELLM_CFG)"; \
	  yq -i ".router_settings.fallbacks = [{\"lls/auto\": [$$fallbacks]}]" "$(LITELLM_CFG)"; \
	  echo "  lls/auto → $$first_base"; \
	  rm -f "$$_lls_index"
	@echo "==> Done. Restart litellm: make litellm.stop && make litellm"

## lms-sync: sync litellm config model_names with lms ls output
## Removes all lms/* entries and re-adds them as lms/<vendor>/<model> to match lms ls IDs.
## Also writes local-only fallbacks (smallest → next-smallest) so ai-local never leaks to cloud.
## Run after installing new models in LM Studio.
.PHONY: lms-sync
lms-sync:
	@echo "==> Removing old lms/* entries from $(LITELLM_CFG)"
	@yq -i 'del(.model_list[] | select(.model_name | test("^lms/")))' "$(LITELLM_CFG)"
	@echo "==> Adding lms/<vendor>/<model> entries from lms ls"
	@lms ls 2>/dev/null | awk 'NF>=5 && $$4~/^[0-9]/ {print $$1}' | grep -v 'text-embedding' | \
		while IFS= read -r id; do \
			name="lms/$$id"; \
			yq -i ".model_list += [{\"model_name\": \"$$name\", \"litellm_params\": {\"model\": \"openai/$$id\", \"api_base\": \"http://localhost:1234/v1\", \"api_key\": \"os.environ/LM_STUDIO_API_TOKEN\"}}]" "$(LITELLM_CFG)"; \
			echo "  + $$name"; \
		done
	@echo "==> Writing local-only fallbacks (ordered smallest → largest)"
	@yq -i 'del(.router_settings.fallbacks)' "$(LITELLM_CFG)"
	@lms ls 2>/dev/null | awk 'NF>=5 && $$4~/^[0-9]/ {print $$4+0, $$1}' | grep -v 'text-embedding' | sort -n | awk '{print $$2}' > /tmp/lms-ordered.txt; \
		models=($$(cat /tmp/lms-ordered.txt)); \
		count=$${#models[@]}; \
		for i in $$(seq 0 $$((count-2))); do \
			src="lms/$${models[$$i]}"; \
			dst="lms/$${models[$$((i+1))]}"; \
			yq -i ".router_settings.fallbacks += [{\"$$src\": [\"$$dst\"]}]" "$(LITELLM_CFG)"; \
		done; \
		echo "  fallback chain: $$(cat /tmp/lms-ordered.txt | sed 's|^|lms/|' | tr '\n' ' → ' | sed 's| → $$||')"
	@echo "==> Done. Restart litellm: make litellm.stop && make litellm"

# ── Commented-out stacks ──────────────────────────────────────────────────────

## temporal: Temporal workflow server at http://localhost:$(TEMPORAL_PORT)
##   Uses a custom brew services plist so --db-filename + --ui-port are honored
##   across reboots and brew lifecycle (vanilla brew plist has no flags → in-memory
##   mode; launchctl auto-respawns the unflagged process so start_server skips).
##   See TNE-CONTEXT/cco/bug-fix-brief-temporal-in-memory-startup.md for full RCA.
TEMPORAL_PLIST ?= $(TNE_DB_DIR)/temporal/homebrew.mxcl.temporal-tne.plist
.PHONY: temporal
temporal:
	mkdir -p "$(dir $(TEMPORAL_DB))"
	@# Regenerate plist each run — pulls in current $(TEMPORAL_DB) / $(TEMPORAL_UI_PORT) paths
	@printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'  <key>KeepAlive</key><true/>' \
		'  <key>Label</key><string>homebrew.mxcl.temporal</string>' \
		'  <key>RunAtLoad</key><true/>' \
		'  <key>ProgramArguments</key>' \
		'  <array>' \
		'    <string>/opt/homebrew/opt/temporal/bin/temporal</string>' \
		'    <string>server</string><string>start-dev</string>' \
		'    <string>--db-filename</string><string>$(TEMPORAL_DB)</string>' \
		'    <string>--ui-port</string><string>$(TEMPORAL_UI_PORT)</string>' \
		'  </array>' \
		'  <key>StandardErrorPath</key><string>$(TNE_LOG_DIR)/temporal.log</string>' \
		'  <key>StandardOutPath</key><string>$(TNE_LOG_DIR)/temporal.log</string>' \
		'  <key>WorkingDirectory</key><string>$(TNE_DB_DIR)/temporal</string>' \
		'</dict></plist>' \
		> "$(TEMPORAL_PLIST)"
	@# Start via brew services with custom plist; if already running with correct DB, skip
	@if ! lsof -p "$$(pgrep -f 'temporal server start-dev' | head -1)" 2>/dev/null | grep -q "$(TEMPORAL_DB)"; then \
		brew services stop temporal >/dev/null 2>&1 || true; \
		brew services start temporal --file="$(TEMPORAL_PLIST)" >/dev/null 2>&1 \
			|| { echo "⚠ brew services failed — falling back to nohup direct start"; \
				 $(call start_server,$(TEMPORAL_PORT),temporal server start-dev --db-filename $(TEMPORAL_DB) --ui-port $(TEMPORAL_UI_PORT)); }; \
	fi
	$(call check_port,$(TEMPORAL_PORT))
	@# tne-engine-worker: start via brew services if formula installed (r-cto-dev129)
	@brew list tne-engine-worker &>/dev/null 2>&1 \
		&& { pgrep -f "engine.temporal_worker" >/dev/null 2>&1 || brew services start tne-engine-worker 2>/dev/null || true; } \
		|| echo "  (tne-engine-worker formula not installed — run: make ai-install)"

# ktap is tne-plugin-only — override in project Makefile if needed
# ## ktap: KTAP knowledge graph viewer at http://localhost:$(KTAP_PORT)
# .PHONY: ktap
# ktap:
# 	cd "$(KTAP_DIR)" && $(call start_server,$(KTAP_PORT),python3 ktap.py viz --port $(KTAP_PORT))
# 	$(call check_port,$(KTAP_PORT))

## ccr: Claude Code Router at http://localhost:$(CCR_PORT)
# BUG(2026-05-10): ccr start exits with code 1 even on success — daemon runs fine, launcher
# has wrong exit convention. Track: github.com/musistudio/claude-code-router/issues/544
# CHECK: 2026-06-10 — if fixed upstream, remove || true from start_server_self call.
.PHONY: ccr
ccr:
	$(call start_server_self,$(CCR_PORT),ccr start)
	$(call check_port,$(CCR_PORT))

## kimi-claude-proxy: claude-code-proxy sidecar — bridges Kimi/ChatGPT subscription to Claude Code
## Uses OAuth login (not PAYG API key). Login once: make kimi-claude-login
## Supports: kimi (kimi.com Coding Plan $19/mo) | chatgpt (ChatGPT Plus/Pro)
KIMI_CLAUDE_PROXY_PORT ?= 3457
KIMI_CLAUDE_PROVIDER   ?= kimi
.PHONY: kimi-claude-proxy
kimi-claude-proxy:
	command -v claude-code-proxy >/dev/null || { echo "claude-code-proxy not installed — run: brew install raine/claude-code-proxy/claude-code-proxy"; exit 1; }
	$(call start_server,$(KIMI_CLAUDE_PROXY_PORT),PORT=$(KIMI_CLAUDE_PROXY_PORT) claude-code-proxy serve)
	$(call check_port,$(KIMI_CLAUDE_PROXY_PORT))

## kimi-claude-login: log in to Kimi (or ChatGPT) for claude-code-proxy subscription auth
##   make kimi-claude-login                       # login to kimi (default)
##   make kimi-claude-login KIMI_CLAUDE_PROVIDER=chatgpt  # login to ChatGPT
.PHONY: kimi-claude-login
kimi-claude-login:
	claude-code-proxy login $(KIMI_CLAUDE_PROVIDER)

## kimi-claude: run Claude Code against Kimi Coding Plan via claude-code-proxy  [PLAN — $19/mo]
## Uses OAuth subscription — no PAYG API key required.
## Login first: make kimi-claude-login
##   make kimi-claude                             # Kimi plan (default)
##   make kimi-claude KIMI_CLAUDE_PROVIDER=chatgpt  # ChatGPT Plus/Pro plan
.PHONY: kimi-claude
kimi-claude: kimi-claude-proxy
	ANTHROPIC_BASE_URL=http://localhost:$(KIMI_CLAUDE_PROXY_PORT) \
	ANTHROPIC_API_KEY=placeholder \
	claude $(HARNESS_ARGS)

# ── Commented-out local inference stacks ─────────────────────────────────────

# ## ollama: Ollama local inference at http://localhost:11434
# OLLAMA_CONTEXT_LENGTH ?= 131072
# OLLAMA_FLASH_ATTENTION ?= 1
# OLLAMA_KV_CACHE_TYPE   ?= q4_0
# OLLAMA_BASE_URL        ?= http://localhost:$(OLLAMA_SERVER_PORT)
# define start_ollama
# 	$(call start_server,$(2),OLLAMA_CONTEXT_LENGTH=$(OLLAMA_CONTEXT_LENGTH) \
# 		OLLAMA_HOST=$(3) OLLAMA_FLASH_ATTENTION=$(OLLAMA_FLASH_ATTENTION) \
# 		OLLAMA_KV_CACHE_TYPE=$(OLLAMA_KV_CACHE_TYPE) $(1) serve)
# 	$(call check_port,$(2))
# endef
# .PHONY: ollama
# ollama:
# 	$(call start_ollama,ollama,$(OLLAMA_SERVER_PORT),127.0.0.1:$(OLLAMA_SERVER_PORT))
# .PHONY: ollama-ls
# ollama-ls:
# 	ollama ls | sort -k3 -hr

# ## open-webui: Open WebUI frontend for Ollama
# .PHONY: open-webui
# open-webui:
# 	-export OLLAMA_BASE_URL="$(OLLAMA_BASE_URL)" DATA_DIR="$(OPEN_WEBUI_DATA_DIR)" && \
# 		$(call start_server,$(OPEN_WEBUI_PORT),open-webui serve --port $(OPEN_WEBUI_PORT))
# 	$(call check_port,$(OPEN_WEBUI_PORT))

## llama-server: llama.cpp inference server at $(LLAMA_SERVER_PORT)
# Note: does not support Mistral or Gemma architecture models
LLAMA_SERVER_PORT ?= 8082
OLLAMA_MODEL  ?= $(HOME)/.ollama/models/blobs
PHI4-14B-GGUF ?= sha256-fd7b6731c33c57f61767612f56517460ec2d1e2e5a3f0163e0eb3d8d8cb5df20
.PHONY: llama-server
llama-server:
	$(call start_server,$(LLAMA_SERVER_PORT),llama-server \
		--ctx-size 131072 --port $(LLAMA_SERVER_PORT) --flash-attn --split-mode row \
		-m "$(OLLAMA_MODEL)/$(PHI4-14B-GGUF)" \
		--cache-type-k q8_0 --cache-type-v q8_0)
	$(call check_port,$(LLAMA_SERVER_PORT))

## mlx: MLX inference server (Apple Silicon) at $(MLX_PORT)
MLX_PORT        ?= 9000
HF_HUB_CACHE    ?= $(HOME)/.cache/huggingface/hub
GLM-4.5-AIR-4BIT ?= models--mlx-community--GLM-4.5-Air-4bit/snapshots/60837794f3caafc4682dd1a9188a82c55a9100ef
.PHONY: mlx
mlx:
	$(call start_server,$(MLX_PORT),mlx_lm.server --port $(MLX_PORT) \
		--model "$(HF_HUB_CACHE)/$(GLM-4.5-AIR-4BIT)")
	$(call check_port,$(MLX_PORT))

## tika: Apache Tika document extraction server at port 9998
TIKA_VERSION ?= 2.9.2
TIKA_JAR     ?= tika-server-standard-$(TIKA_VERSION).jar
.PHONY: tika
tika:
	$(call start_server,9998,java -jar "$$HOME/jar/$(TIKA_JAR)")
	$(call check_port,9998)

## comfy: start ComfyUI Desktop
.PHONY: comfy
comfy:
	open -a "ComfyUI.app"

LIB_AI      ?= $(WS_DIR)/git/src/lib/lib-ai.sh
LIB_SECRETS ?= $(WS_DIR)/git/src/lib/lib-secrets.sh
LIB_UTIL    ?= $(WS_DIR)/git/src/lib/lib-util.sh

## ai-check-keys: curl each AI provider's /v1/models — reports valid/expired/unreachable
.PHONY: ai-check-keys
ai-check-keys:
	@bash -c 'source "$(LIB_UTIL)" && source "$(LIB_AI)" && ai_check_api_keys'

## ai-refresh-models: query providers for latest model IDs, patch CCR + LiteLLM configs
## Uses 7-day cache (~/.cache/tne/model-ids.yaml). Force refresh: make ai-refresh-models AI_MODEL_CACHE_TTL_DAYS=0
.PHONY: ai-refresh-models
ai-refresh-models:
	@bash -c 'source "$(LIB_UTIL)" && source "$(LIB_AI)" && \
		ai_resolve_model_names && ai_patch_ccr_config && ai_patch_litellm_config && \
		echo "Done — restart ccr and litellm to pick up changes"'

# ## mcpo: MCP → OpenAPI adapter (exposes MCP servers as REST endpoints)
# MCPO_PORT    ?= 8001
# MCPO_CONFIG  ?= $(HOME)/.config/mcp/claude-desktop.json
# MCPO_API_KEY ?= secret_mcpo_api_key
# .PHONY: mcpo
# mcpo:
# 	$(call start_server,$(MCPO_PORT),uvx mcpo --port "$(MCPO_PORT)" \
# 		--api-key "$(MCPO_API_KEY)" --config "$(MCPO_CONFIG)")
