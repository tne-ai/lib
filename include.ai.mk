##
## AI tools
PYTHON ?= 3.12
FLAGS ?=
SHELL := /usr/bin/env bash
WS_DIR ?= $(HOME)/wsn
BIN_DIR ?= $(WS_DIR)/git/src/bin

AI_USER ?= $(USER)
AI_ORG ?= tne.ai

# variables must be definte before their use so put high
MLFLOW_PORT    ?= 5001
LITELLM_PORT   ?= 4000
TEMPORAL_PORT  ?= 7233
KTAP_PORT      ?= 8765
CCR_PORT       ?= 3456
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
MLFLOW_DIR   ?= $(HOME)/.local/share/mlflow
KTAP_DIR     ?= $(WS_DIR)/git/src/demo/demo-do178c
TEMPORAL_DB  ?= $(WS_DIR)/data/temporal/temporal.db
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

# usage: $(call start_server,port of service, app, arguments...)
# this generations a strange problem
# if ! pgrep -fL $(1) || ! lsof -i :$(2) ; then; $(3) $(4) $(5) $(6) $(7) $(8) $(9) $(10)
start_server = if ! lsof -i:$(1) -sTCP:LISTEN; then nohup bash -c '$(2) $(3) $(4) $(5) $(6) $(7) $(8) $(9) $(10)' >/tmp/sidecar-$(1).log 2>&1; fi &

# usage: $(call open_server,port of service, url_suffix)
open_server = if lsof -i:$(1) -sTCP:LISTEN; then open "http://localhost:$(1)$(2)"; fi &

# usage $(call check_ports to see if the command wowrked)
check_port = -sleep 5 && lsof -i:$(1) -sTCP:LISTEN

## %.ps: process status for any service (e.g. make litellm.ps)
%.ps:
	if ! pgrep -fl $*; then echo "$* not running"; fi

## [service].kill: gracefully stop then SIGKILL any service matched by name
# -f means find anywhere in the argument field; SIGTERM first, SIGKILL after 5s
# xargs -r means do not run kill if there are no matching processes
# grep -vE strips the make process itself and pgrep from the match list
# run in background (&) as the sleep makes this slow
%.kill:
	for signal in "" "-9"; do \
		echo "pid only" && pgrep -fl "$*" | grep -vE '^[0-9]+ make|pgrep' | awk '{print $$1}' || true; \
		echo "$$signal" && pgrep -fl "$*" | grep -vE '^[0-9]+ make|pgrep' | awk '{print $$1}' | xargs -r kill $$signal || true && sleep 5; \
	done &


# note never use brew for status very slow
	# brew services start postgresql@17 2>/dev/null || brew services start postgresql 2>/dev/null || true
## postgres: start PostgreSQL via brew services (needed for LiteLLM spend tracking)
.PHONY: postgres
postgres:
	if ! command -v psql >/dev/null 2>&1; then \
		$(MAKE) -f $(firstword $(MAKEFILE_LIST)) ai-install; \
	fi
	until pg_isready -q; do sleep 1; done
	psql -lqt | grep -q "$(LITELLM_DB)" || createdb "$(LITELLM_DB)"

	# brew services start redis 2>/dev/null || true
## redis: start Redis via brew services (needed for LiteLLM response caching)
.PHONY: redis
redis:
	if ! command -v redis-cli >/dev/null 2>&1; then \
		$(MAKE) -f $(firstword $(MAKEFILE_LIST)) ai-install; \
	fi
	until redis-cli ping 2>/dev/null | grep -q PONG; do sleep 1; done

## mlflow: start MLflow tracking server at http://localhost:$(MLFLOW_PORT)
## mlflow has no Homebrew formula — install chain is: uv tool install → uvx (ephemeral).
## uv tool install puts the binary in ~/.local/bin which may not be in Make's PATH,
## so we resolve at runtime with `command -v mlflow || echo uvx mlflow`.
.PHONY: mlflow
mlflow:
	if ! command -v mlflow >/dev/null 2>&1 && ! uvx mlflow --version >/dev/null 2>&1; then \
		echo "mlflow not installed — running make ai-install first"; \
		$(MAKE) -f $(firstword $(MAKEFILE_LIST)) ai-install; \
	fi
	mkdir -p "$(MLFLOW_DIR)/artifacts"
	$(call start_server,$(MLFLOW_PORT),$$(command -v mlflow || echo uvx mlflow) server --host 127.0.0.1 --port $(MLFLOW_PORT) \
		--backend-store-uri sqlite:///$(MLFLOW_DIR)/mlflow.db \
		--default-artifact-root $(MLFLOW_DIR)/artifacts)
	$(call check_port,$(MLFLOW_PORT))

## litellm: start LiteLLM proxy at http://localhost:$(LITELLM_PORT)
## Mixed-auth mode: ANTHROPIC_BASE_URL routes through LiteLLM for caching/observability,
## but Claude Code's Max plan OAuth token passes through unchanged — no PAYG API key used.
## ANTHROPIC_API_KEY is set to LITELLM_MASTER_KEY (not a real Anthropic key).
## This is LiteLLM's virtual-key pass-through pattern: Claude Code sends it as Bearer token,
## LiteLLM validates against its own master_key and routes to real providers with their keys.
## See: docs.litellm.ai/docs/proxy/virtual_keys
## litellm binary also lives in ~/.local/bin (uv tool install) — same PATH fix as mlflow.
.PHONY: litellm
litellm:
	if ! command -v litellm >/dev/null 2>&1 && ! uvx litellm --version >/dev/null 2>&1; then \
		echo "litellm not installed — running make ai-install first"; \
		$(MAKE) -f $(firstword $(MAKEFILE_LIST)) ai-install; \
	fi
	if [ ! -f "$(PRISMA_STAMP)" ]; then \
		_venv=$$(pipx environment --value PIPX_LOCAL_VENVS 2>/dev/null)/litellm; \
		_schema=$$_venv/lib/python*/site-packages/litellm/proxy/schema.prisma; \
		$$_venv/bin/python -m prisma generate --schema $$_schema; \
		mkdir -p $$(dirname $(PRISMA_STAMP)) && touch $(PRISMA_STAMP); \
	fi
	$(call start_server,$(LITELLM_PORT),ANTHROPIC_API_KEY=$${LITELLM_MASTER_KEY} DATABASE_URL=postgresql://$$USER@localhost/litellm $$(command -v litellm || echo uvx litellm) --config $(LITELLM_CFG) --port $(LITELLM_PORT) --host 127.0.0.1)
	$(call check_port,$(LITELLM_PORT))

# ── Harness + model variables ─────────────────────────────────────────────────
# HARNESS: the AI coding assistant CLI. Swap without changing targets.
#   make ai                        # claude (default)
#   make ai HARNESS=aider          # aider
#   make ai HARNESS=codex          # codex CLI (plan provider via CLIProxyAPI)
# MODEL: any model_name from $(LITELLM_CFG). Run 'make ai-models' to list all.
#   make ai MODEL=kimi-k2.6
# HARNESS_ARGS: extra flags forwarded to the harness binary.
#   make ai HARNESS_ARGS="--continue"
HARNESS            ?= claude
HARNESS_ARGS       ?=
MODEL              ?=
# Pick smallest installed LM Studio model by size; fallback if lms not running
LOCAL_MODEL        ?= $(or $(shell lms ls 2>/dev/null | awk 'NF>=5 && $$4~/^[0-9]/ {print $$4+0, "lms-" $$1}' | sort -n | awk 'NR==1{print $$2}'),lms-google/gemma-4-e4b)

# ── Internal runner macro ─────────────────────────────────────────────────────
# Inlined into each entry point via $(call _run_harness,MODEL).
# Sets ANTHROPIC_BASE_URL + OPENAI_BASE_URL so any OpenAI-compatible harness works.
# ANTHROPIC_CUSTOM_HEADERS passes the LiteLLM master key — required because Make
# does not source shell profiles, so the profile-set ANTHROPIC_CUSTOM_HEADERS is absent.
define _run_harness
	ANTHROPIC_BASE_URL=http://localhost:$(LITELLM_PORT) \
	OPENAI_BASE_URL=http://localhost:$(LITELLM_PORT) \
	ANTHROPIC_CUSTOM_HEADERS="x-litellm-api-key: $${LITELLM_MASTER_KEY}" \
	$(if $(1),CLAUDE_MODEL=$(1),$(if $(MODEL),CLAUDE_MODEL=$(MODEL),)) \
	$(HARNESS) $(HARNESS_ARGS)
endef

# ── Run-only target (servers already up) ──────────────────────────────────────
## ai-run: launch the AI harness against already-running sidecars
##   make ai-run                    # claude (default)
##   make ai-run MODEL=kimi-k2.6   # different model
##   make ai-run HARNESS=aider
.PHONY: ai-run
ai-run:
	$(call _run_harness,$(MODEL))

# ── Public entry points ───────────────────────────────────────────────────────

## ai: start sidecars (postgres redis mlflow litellm temporal ccr)  [PLAN — Anthropic Max]
##   make ai                             # start servers, then run: make ai-run
##   make ai-run                         # launch claude against running servers
##   make ai-run MODEL=kimi-k2.6         # Kimi K2 Coding Plan ($19/mo flat)  [PLAN]
##   make ai-run MODEL=gemini-2.5-flash  # Gemini Flash                       [PAYG]
##   make ai-run HARNESS=aider           # swap harness, same sidecar stack
##   See all models: make ai-models
## Sidecars: postgres redis mlflow litellm temporal ccr
.PHONY: ai
ai: postgres redis mlflow litellm temporal ccr
	@echo ""
	@echo "  Sidecars are up. Run your AI harness in a separate terminal:"
	@echo "    make ai-run                  # claude (Max plan)"
	@echo "    make ai-run MODEL=kimi-k2.6  # Kimi K2 (Coding plan)"
	@echo "    make ai-run HARNESS=aider    # aider"
	@echo ""

## ai-local: full sidecar stack + GPU + LM Studio — servers only  [FREE]
##   make ai-local                              # start servers, then: make ai-run LOCAL_MODEL=...
##   make ai-local LOCAL_MODEL=lms-qwen3.6-27b
## Zero marginal cost — inference runs on your GPU via LM Studio
.PHONY: ai-local
ai-local: postgres redis mlflow litellm temporal ccr set-gpu-max-memory lms-server
	@echo ""
	@echo "  Local stack ready. Run your harness in a separate terminal:"
	@echo "    make ai-run LOCAL_MODEL=$(LOCAL_MODEL)"
	@echo ""

## ai-cli: CLI-auth providers via CLIProxyAPI adapter  [PLAN — flat-rate subscriptions]
## Authenticates via provider CLI login, not per-token API key.
##   make ai-cli MODEL=codex        # ChatGPT/Codex plan (codex login)        [PLAN]
##   make ai-cli MODEL=gemini-proxy # Google Gemini plan (gemini auth login)  [PLAN]
.PHONY: ai-cli
ai-cli: postgres redis mlflow litellm cliproxyapi
	@echo "  CLI stack ready. Run: make ai-run MODEL=codex"

## ai-auto: difficulty-routing — cheap for simple tasks, strong for hard  [PLAN+PLAN]
## Easy prompts → kimi-k2.6 (Coding Plan $19/mo), hard → claude-sonnet (Max plan)
.PHONY: ai-auto
ai-auto: postgres redis mlflow litellm routellm
	@echo "  Auto-routing stack ready. Run: make ai-run MODEL=routellm"

## ai-auth: log in to all AI providers (run once per machine or after token expiry)
##   make ai-auth              # all providers
##   make ai-auth PROVIDER=claude   # claude /login
##   make ai-auth PROVIDER=gemini   # gemini auth login
##   make ai-auth PROVIDER=codex    # codex login
PROVIDER ?=
.PHONY: ai-auth
ai-auth:
	if [[ -z "$(PROVIDER)" || "$(PROVIDER)" == "claude" ]]; then \
		echo "==> claude /login"; claude /login; \
	fi
	if [[ -z "$(PROVIDER)" || "$(PROVIDER)" == "gemini" ]]; then \
		echo "==> gemini auth login"; gemini auth login 2>/dev/null || echo "  (gemini CLI not installed — brew install gemini)"; \
	fi
	if [[ -z "$(PROVIDER)" || "$(PROVIDER)" == "codex" ]]; then \
		echo "==> codex login"; codex login 2>/dev/null || echo "  (codex CLI not installed — npm install -g @openai/codex)"; \
	fi

# ── Supporting sidecars ───────────────────────────────────────────────────────

## cliproxyapi: CLIProxyAPI — wraps codex/gemini CLI auth as OpenAI-compatible API
## Install: brew install cliproxyapi  Login: codex login  or  gemini auth login
CLIPROXYAPI_PORT ?= 8080
.PHONY: cliproxyapi
cliproxyapi:
	command -v cliproxyapi >/dev/null || { echo "cliproxyapi not installed — run: brew install cliproxyapi"; exit 1; }
	$(call start_server,$(CLIPROXYAPI_PORT),cliproxyapi start)
	$(call check_port,$(CLIPROXYAPI_PORT))

## routellm: RouteLLM difficulty-routing server
ROUTELLM_PORT ?= 6060
ROUTELLM_CFG  ?= $(HOME)/.config/routellm/config.yaml
.PHONY: routellm
routellm:
	$(call start_server,$(ROUTELLM_PORT),uvx routellm.server --config $(ROUTELLM_CFG) --port $(ROUTELLM_PORT))
	$(call check_port,$(ROUTELLM_PORT))

## ai-open: open all service UIs in Chrome
.PHONY: ai-open
ai-open:
	open -a "Google Chrome" "http://localhost:$(LITELLM_PORT)/ui/login"
	open -a "Google Chrome" "http://localhost:$(MLFLOW_PORT)"
	open -a "Google Chrome" "http://localhost:$(TEMPORAL_PORT)"

## ai-status: health check for all sidecars
.PHONY: ai-status
ai-status:
	echo "PostgreSQL :$(POSTGRES_PORT): $$(pg_isready -q 2>/dev/null && echo ok || echo stopped)"
	echo "Redis      :$(REDIS_PORT): $$(redis-cli ping 2>/dev/null | grep -q PONG && echo ok || echo stopped)"
	echo "LiteLLM    :$(LITELLM_PORT): $$(nc -z localhost $(LITELLM_PORT) 2>/dev/null && echo ok || echo stopped)"
	echo "MLflow     :$(MLFLOW_PORT): $$(nc -z localhost $(MLFLOW_PORT) 2>/dev/null && echo ok || echo stopped)"
	echo "Temporal   :$(TEMPORAL_PORT): $$(nc -z localhost $(TEMPORAL_PORT) 2>/dev/null && echo ok || echo stopped)"
	echo "CCR        :$(CCR_PORT): $$(nc -z localhost $(CCR_PORT) 2>/dev/null && echo ok || echo stopped)"
	echo "LM Studio  : $$(pgrep -x 'LM Studio' >/dev/null 2>&1 && echo ok || echo stopped)"

## ai-models: list available models with make invocation examples
.PHONY: ai-models
ai-models:
	echo ""
	echo "Cloud models — make ai MODEL=<name>"
	echo "──────────────────────────────────────────────────────"
	yq '.model_list[].model_name' "$(LITELLM_CFG)" 2>/dev/null | sort -u | grep -v '^lms-' | \
		while IFS= read -r name; do \
			case "$$name" in \
			*-free)    tag="FREE  -- provider free tier via OpenRouter" ;; \
			claude*)   tag="PLAN  -- Anthropic Max (~\$$20-100/mo flat)" ;; \
			kimi*)     tag="PLAN  -- Kimi Coding Plan (\$$19/mo flat)" ;; \
			glm*)      tag="PLAN  -- ZAI Coding Plan (~\$$10/mo flat)" ;; \
			qwen3*)    tag="PLAN  -- Qwen Coding Plan (\$$50/mo flat)" ;; \
			minimax*)  tag="PLAN  -- MiniMax plan" ;; \
			routellm*) tag="PLAN+PLAN -- auto-routes kimi->claude by difficulty" ;; \
			gemini*)   tag="PAYG  -- pay per token (flash: free tier available)" ;; \
			deepseek*) tag="PAYG  -- pay per token" ;; \
			*)         tag="PAYG" ;; \
			esac; \
			printf '  make ai MODEL=%-32s # %s\n' "$$name" "$$tag"; \
		done || echo "  (config not found — run make ai-install)"
	echo ""
	echo "Local models — make ai-local LOCAL_MODEL=<name>"
	echo "──────────────────────────────────────────────────────"
	lms ls 2>/dev/null | awk 'NF>=5 && $$4~/^[0-9]/ {printf "  make ai-local LOCAL_MODEL=lms-%-38s # FREE — %.1f GB\n", $$1, $$4+0}' | sort -k6 -n \
		|| echo "  (lms not running — start LM Studio or run: make lms-server)"
	echo ""
	echo "Entry points:"
	echo "  make ai                              # PLAN  — Anthropic Max (default)"
	echo "  make ai MODEL=kimi-k2.6              # PLAN  — any cloud model above"
	echo "  make ai HARNESS=aider                # swap AI harness"
	echo "  make ai-local [LOCAL_MODEL=lms-*]    # FREE  — local GPU via LM Studio"
	echo "  make ai-cli MODEL=codex              # PLAN  — codex login"
	echo "  make ai-cli MODEL=gemini-proxy       # PLAN  — gemini auth login"
	echo "  make ai-auto                         # PLAN+PLAN — kimi (easy) → claude (hard)"

## ai-logs: push Claude Code session logs to MLflow
.PHONY: ai-logs
ai-logs:
	uv run "$(MLFLOW_LOG_SCRIPT)"

## ai-ps: process status of all sidecars
.PHONY: ai-ps
ai-ps: mlflow.ps litellm.ps temporal.ps ccr.ps
	brew services list | grep -E "postgresql|redis" | awk '{printf "%-10s %s\n", $$1, $$2}'

## ai-kill: stop all sidecars (brew services for postgres/redis, pkill for others)
.PHONY: ai-kill
ai-kill: $(MLFLOW_PORT).kill $(LITELLM_PORT).kill $(TEMPORAL_PORT).kill $(CCR_PORT).kill
	brew services stop redis 2>/dev/null || true
	brew services stop postgresql@17 2>/dev/null || brew services stop postgresql 2>/dev/null || true

## ai-local-kill: stop sidecars + LM Studio + restore GPU memory limit
.PHONY: ai-local-kill
ai-local-kill: ai-kill
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
	echo "==> uv: litellm proxy + mlflow tracking"
	uv tool install 'litellm[proxy]' 2>/dev/null || uvx litellm --version >/dev/null
	uv tool install mlflow 2>/dev/null || uvx mlflow --version >/dev/null
	uv tool install prisma 2>/dev/null || command -v prisma >/dev/null
	echo "==> prisma: generate client for LiteLLM spend tracking"
	_venv=$$(pipx environment --value PIPX_LOCAL_VENVS 2>/dev/null)/litellm; \
	_schema=$$_venv/lib/python*/site-packages/litellm/proxy/schema.prisma; \
	$$_venv/bin/python -m prisma generate --schema $$_schema
	mkdir -p $$(dirname $(PRISMA_STAMP)) && touch $(PRISMA_STAMP)
	echo "==> brew services: start redis + postgresql"
	brew services start redis 2>/dev/null || true
	brew services start postgresql@17 2>/dev/null || brew services start postgresql 2>/dev/null || true
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

# ── Commented-out stacks ──────────────────────────────────────────────────────

## temporal: Temporal workflow server at http://localhost:$(TEMPORAL_PORT)
.PHONY: temporal
temporal:
	mkdir -p "$(dir $(TEMPORAL_DB))"
	$(call start_server,$(TEMPORAL_PORT),temporal server start-dev --db-filename $(TEMPORAL_DB) --ui-port 8080)
	$(call check_port,$(TEMPORAL_PORT))

# ktap is tne-plugin-only — override in project Makefile if needed
# ## ktap: KTAP knowledge graph viewer at http://localhost:$(KTAP_PORT)
# .PHONY: ktap
# ktap:
# 	cd "$(KTAP_DIR)" && $(call start_server,$(KTAP_PORT),python3 ktap.py viz --port $(KTAP_PORT))
# 	$(call check_port,$(KTAP_PORT))

## ccr: Claude Code Router at http://localhost:$(CCR_PORT)
.PHONY: ccr
ccr:
	$(call start_server,$(CCR_PORT),ccr start)
	$(call check_port,$(CCR_PORT))

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

# ## mcpo: MCP → OpenAPI adapter (exposes MCP servers as REST endpoints)
# MCPO_PORT    ?= 8001
# MCPO_CONFIG  ?= $(HOME)/.config/mcp/claude-desktop.json
# MCPO_API_KEY ?= secret_mcpo_api_key
# .PHONY: mcpo
# mcpo:
# 	$(call start_server,$(MCPO_PORT),uvx mcpo --port "$(MCPO_PORT)" \
# 		--api-key "$(MCPO_API_KEY)" --config "$(MCPO_CONFIG)")
