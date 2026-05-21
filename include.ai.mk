##
## AI tools
PYTHON ?= 3.12
FLAGS ?=
SHELL := /usr/bin/env bash
WS_DIR ?= $(HOME)/ws
BIN_DIR ?= $(WS_DIR)/git/src/bin
TNE_DB_DIR  ?= $(WS_DIR)/db
TNE_LOG_DIR ?= $(WS_DIR)/log
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
# kill is last resort only; this target implements the normal stop lifecycle term.
# run in background (&) as the sleep makes this slow
%.stop:
	@for signal in "" "-9"; do \
		if echo "$*" | grep -qE '^[0-9]+$$'; then \
			lsof -ti :$* -sTCP:LISTEN 2>/dev/null | xargs -r kill $$signal 2>/dev/null || true; \
		else \
			pgrep -fl "$*" | grep -vE '^[0-9]+ make|pgrep' | awk '{print $$1}' | xargs -r kill $$signal 2>/dev/null || true; \
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
.PHONY: mlflow
mlflow:
	if ! command -v mlflow >/dev/null 2>&1 && ! uvx mlflow --version >/dev/null 2>&1; then \
		echo "mlflow not installed — running make ai-install first"; \
		$(MAKE) -f $(firstword $(MAKEFILE_LIST)) ai-install; \
	fi
	mkdir -p "$(MLFLOW_DIR)/artifacts"
	$(call start_server_double_fork,$(MLFLOW_PORT),$$(command -v mlflow || echo uvx mlflow) server --host 127.0.0.1 --port $(MLFLOW_PORT) \
		--backend-store-uri sqlite:///$(MLFLOW_DIR)/mlflow.db \
		--default-artifact-root $(MLFLOW_DIR)/artifacts)
	$(call check_port,$(MLFLOW_PORT))

## Pin litellm to a known-good version. Unpin by setting LITELLM_VERSION=latest.
## WHY: litellm has shipped broken UI builds (HTML/JS chunk hash mismatch in 1.83.x)
## that cause a blank "gigantic zero" dashboard. Pinning ensures a tested coherent build.
LITELLM_VERSION ?= 1.84.0

## litellm: start LiteLLM proxy at http://localhost:$(LITELLM_PORT)
## Mixed-auth mode: ANTHROPIC_BASE_URL routes through LiteLLM for caching/observability,
## but Claude Code's Max plan OAuth token passes through unchanged — no PAYG API key used.
## ANTHROPIC_API_KEY is set to LITELLM_MASTER_KEY (not a real Anthropic key).
## This is LiteLLM's virtual-key pass-through pattern: Claude Code sends it as Bearer token,
## LiteLLM validates against its own master_key and routes to real providers with their keys.
## See: docs.litellm.ai/docs/proxy/virtual_keys
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
.PHONY: litellm.stop 4000.stop
litellm.stop 4000.stop:
	@-lsof -ti :$(LITELLM_PORT) -sTCP:LISTEN | xargs kill 2>/dev/null || true
	@pkill -f "litellm" 2>/dev/null || true
	@sleep 1
	@pkill -9 -f "litellm" 2>/dev/null || true
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
		DATABASE_URL=postgresql://$$USER@localhost/litellm \
			PATH="$$_venv/bin:$$PATH" $$_venv/bin/prisma db push --schema "$$_schema" --accept-data-loss; \
		mkdir -p $$(dirname $(PRISMA_STAMP)) && echo "$$_schema_hash" > $(PRISMA_STAMP); \
	fi; \
	$(call start_server_double_fork,$(LITELLM_PORT),\
		ANTHROPIC_API_KEY="$${LITELLM_MASTER_KEY}" \
		DATABASE_URL=postgresql://$$USER@localhost/litellm \
		LM_STUDIO_API_TOKEN="$${LM_STUDIO_API_TOKEN}" \
		MOONSHOT_API_KEY="" \
		GEMINI_API_KEY="$${GEMINI_API_KEY}" \
		DEEPSEEK_API_KEY="$${DEEPSEEK_API_KEY}" \
		ALIBABA_API_KEY="$${ALIBABA_API_KEY}" \
		QWEN_CODING_API_KEY="$${QWEN_CODING_API_KEY}" \
		Z_AI_API_KEY="$${Z_AI_API_KEY}" \
		MINIMAX_API_KEY="$${MINIMAX_API_KEY}" \
		OPENROUTER_API_KEY="$${OPENROUTER_API_KEY}" \
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

# ── Run-only target (servers already up) ──────────────────────────────────────
## ai-run: launch harness with LiteLLM env vars — requires sidecars already running
##   make ai-run                               # claude via Max plan (default)
##   make ai-run MODEL=kimi-k2.6              # Kimi K2 Coding Plan ($19/mo flat) [PLAN]
##   make ai-run MODEL=kimi-k2.5              # Kimi K2.5 Coding Plan             [PLAN]
##   make ai-run MODEL=gemini-2.5-flash       # Gemini Flash                      [PAYG]
##   make ai-run MODEL=lls/qwen/qwen3.6-27b   # local GPU (llama-server router)   [FREE]
##   make ai-run MODEL=lms/qwen/qwen3.6-27b   # local GPU (LM Studio — legacy)    [FREE]
##   make ai-run HARNESS=aider                # swap harness, same model
.PHONY: ai-run
ai-run:
	@curl -sf http://localhost:$(LITELLM_PORT)/health/readiness >/dev/null 2>&1 \
		|| { echo "LiteLLM not ready on :$(LITELLM_PORT) — run: make litellm"; exit 1; }
	@$(if $(filter lls/%,$(MODEL)), \
		$(call port_ready,8081) \
		|| { echo "llama-server not running on :8081 — run: make lls-start"; exit 1; },)
	@$(if $(filter lms/%,$(MODEL)), \
		lms load "$$(echo '$(MODEL)' | sed 's|^lms/||')" --gpu max \
		|| echo "⚠️  lms load failed — model may already be loaded",)
	ANTHROPIC_BASE_URL=http://localhost:$(LITELLM_PORT) \
	OPENAI_BASE_URL=http://localhost:$(LITELLM_PORT) \
	ANTHROPIC_CUSTOM_HEADERS="x-litellm-api-key: $${LITELLM_MASTER_KEY}" \
	$(if $(MODEL),ANTHROPIC_CUSTOM_MODEL_OPTION=$(MODEL),) \
	env -u CLAUDECODE $(HARNESS) $(if $(MODEL),--model $(MODEL),) $(HARNESS_ARGS)

# ── Public entry points ───────────────────────────────────────────────────────

## ai: start full sidecar stack — cloud + local GPU, all models available
##   make ai                                      # start everything, then run: make ai-run
##   make ai-run                                  # claude via Max plan (default)
##   make ai-run MODEL=kimi-k2.6                 # Kimi K2 Coding Plan ($19/mo)   [PLAN]
##   make ai-run MODEL=gemini-2.5-flash          # Gemini Flash                   [PAYG]
##   make ai-run MODEL=lls/qwen/qwen3.6-27b      # local GPU via llama-server     [FREE]
##   make ai-run HARNESS=aider                   # swap harness, same model
##   See all models: make ai-models
## Sidecars: postgres redis mlflow litellm temporal set-gpu-max-memory lls-start
## (ai-local was merged into ai — one stack serves all models)
.PHONY: ai ai-local
ai ai-local: postgres redis mlflow litellm temporal set-gpu-max-memory lls-start ai-open
	@echo ""
	@echo "  Stack ready. Run your AI harness in a separate terminal:"
	@echo "    make ai-run                               # claude Max plan"
	@echo "    make ai-run MODEL=kimi-k2.6              # Kimi K2 (Coding plan)"
	@echo "    make ai-run MODEL=lls/<vendor>/<model>   # local GPU  [FREE]"
	@echo "    make ai-run HARNESS=aider                # aider"
	@echo ""
	@echo "  Local models:"
	@yq '.model_list[].model_name' "$(LITELLM_CFG)" 2>/dev/null | grep '^lls' | sort | \
		while IFS= read -r name; do printf '    make ai-run MODEL=%-36s # FREE\n' "$$name"; done
	@echo ""
	@$(MAKE) --no-print-directory ai-warn-bridges

## ai-warn-bridges: start subscription bridges if not running; warn to auth if they stay down
## Called automatically by make ai. Non-interactive — never prompts for credentials.
## If a bridge needs first-time auth, run: make ai-auth PROVIDER=kimi|gemini
##   kimi   — claude-code-proxy  :3457  starts automatically if already authenticated
##   gemini — CLIProxyAPI        :8080  starts automatically if already authenticated
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
		echo "  → gemini bridge (:$(CLIPROXYAPI_PORT)) not running — starting..."; \
		if command -v cliproxyapi >/dev/null 2>&1; then \
			nohup cliproxyapi start </dev/null >$(TNE_LOG_DIR)/sidecar-$(CLIPROXYAPI_PORT).log 2>&1 & \
			sleep 2; \
			if nc -z localhost $(CLIPROXYAPI_PORT) 2>/dev/null; then \
				echo "  ✓  gemini bridge started"; \
			else \
				echo "  ⚠️  gemini bridge not up — last log lines:"; \
				tail -5 $(TNE_LOG_DIR)/sidecar-$(CLIPROXYAPI_PORT).log 2>/dev/null | sed 's/^/       /'; \
				echo "       Fix: make ai-auth PROVIDER=gemini   (authenticate first, then retry)"; \
			fi; \
		else \
			echo "  ⚠️  cliproxyapi not installed — brew install cliproxyapi"; \
		fi; \
	fi
	@nc -z localhost $(KIMI_CLAUDE_PROXY_PORT) 2>/dev/null \
		&& nc -z localhost $(CLIPROXYAPI_PORT) 2>/dev/null \
		&& echo "  ✓  Subscription bridges: kimi :$(KIMI_CLAUDE_PROXY_PORT) gemini :$(CLIPROXYAPI_PORT)" || true

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
##   make ai-auth PROVIDER=gemini   # gemini auth login
##   make ai-auth PROVIDER=codex    # codex login
PROVIDER ?=
.PHONY: ai-auth
ai-auth:
	if [[ -z "$(PROVIDER)" || "$(PROVIDER)" == "claude" ]]; then \
		echo "==> claude /login"; claude /login; \
	fi
	if [[ -z "$(PROVIDER)" || "$(PROVIDER)" == "kimi" ]]; then \
		echo "==> claude-code-proxy kimi auth login"; \
		claude-code-proxy kimi auth login 2>/dev/null || echo "  (claude-code-proxy not installed — brew install raine/claude-code-proxy/claude-code-proxy)"; \
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
	$(call start_server_self,$(CLIPROXYAPI_PORT),cliproxyapi start)
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
		nc -z localhost $(LITELLM_PORT) 2>/dev/null && open -a "Google Chrome" "http://localhost:$(LITELLM_PORT)/ui/login" || true; \
		nc -z localhost $(MLFLOW_PORT) 2>/dev/null && open -a "Google Chrome" "http://localhost:$(MLFLOW_PORT)" || true; \
		nc -z localhost $(TEMPORAL_UI_PORT) 2>/dev/null && open -a "Google Chrome" "http://localhost:$(TEMPORAL_UI_PORT)" || true; \
		nc -z localhost $(CCR_PORT) 2>/dev/null && open -a "Google Chrome" "http://localhost:$(CCR_PORT)" || true; \
		nc -z localhost $(KTAP_PORT) 2>/dev/null && open -a "Google Chrome" "http://localhost:$(KTAP_PORT)" || true; \
		nc -z localhost $(LLS_PORT) 2>/dev/null && open -a "Google Chrome" "http://localhost:$(LLS_PORT)/" || true; \
		touch "$(AI_OPEN_STAMP)"; \
	fi

## ai-open-force: open all service UIs unconditionally (clears once-per-session guard)
.PHONY: ai-open-force
ai-open-force:
	@rm -f "$(AI_OPEN_STAMP)"
	@$(MAKE) ai-open

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

## test-ai: validate tools, config, and running sidecars for all ai-* stack variants
##   Checks installs, litellm config routing, and port health — reports ✓/✗ without failing.
##   Subsections mirror the make ai-* targets: base, local, cli, plan, auto.
.PHONY: test-ai
test-ai:
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
	@grep -q "localhost:$(KIMI_CLAUDE_PROXY_PORT)" "$(LITELLM_CFG)" 2>/dev/null \
		&& echo "✓ litellm kimi → localhost:$(KIMI_CLAUDE_PROXY_PORT) (PLAN)" \
		|| echo "✗ litellm config: kimi still PAYG (expected localhost:$(KIMI_CLAUDE_PROXY_PORT))"
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

## test-ai-plan: alias for targeted plan-mode validation only
.PHONY: test-ai-plan
test-ai-plan: test-ai

## test-ai-kimi: live round-trip test against kimi-k2.6 via claude-code-proxy + litellm
##   Requires: make ai (sidecars up) + make kimi-claude-proxy (subscription bridge up)
##   Sends a single completion to kimi-k2.6 through litellm on localhost:$(LITELLM_PORT).
.PHONY: test-ai-kimi
test-ai-kimi:
	@echo "==> kimi round-trip test via litellm :$(LITELLM_PORT)"
	@$(call port_ready,$(LITELLM_PORT)) || { echo "✗ LiteLLM not running — run: make ai"; exit 1; }
	@$(call port_ready,$(KIMI_CLAUDE_PROXY_PORT)) || { echo "✗ claude-code-proxy not running — run: make kimi-claude-proxy"; exit 1; }
	@curl -sf -X POST http://localhost:$(LITELLM_PORT)/v1/chat/completions \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer $${LITELLM_MASTER_KEY}" \
		-d '{"model":"kimi-k2.6","messages":[{"role":"user","content":"reply with the single word: pong"}],"max_tokens":10}' \
		| python3 -c "import sys,json; r=json.load(sys.stdin); print('✓ kimi response:', r['choices'][0]['message']['content'].strip()); print('  model:', r.get('model','?')); print('  provider:', r.get('x_litellm_model_group', r.get('system_fingerprint','?')))" \
		|| echo "✗ kimi round-trip failed — check litellm logs: make litellm.log"

## test-ai-ui: playwright smoke test — verify each service UI renders correctly
##   Requires: make ai (sidecars up). Saves failure screenshots to /tmp.
##   Governed by r-ai-ui-check (playwright eval rule for AI sidecar UIs).
.PHONY: test-ai-ui
test-ai-ui:
	@echo "==> AI sidecar UI smoke tests (playwright)"
	@python3 $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../bin/check-ai-ui.py

## test-ai-ui-litellm: check only LiteLLM Admin UI
.PHONY: test-ai-ui-litellm
test-ai-ui-litellm:
	@python3 $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../bin/check-ai-ui.py --service litellm

## test-ai-ui-mlflow: check only MLflow UI
.PHONY: test-ai-ui-mlflow
test-ai-ui-mlflow:
	@python3 $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../bin/check-ai-ui.py --service mlflow

## ai-ps: process status of all sidecars
.PHONY: ai-ps
ai-ps: mlflow.ps litellm.ps temporal.ps ccr.ps
	brew services list | grep -E "postgresql|redis" | awk '{printf "%-10s %s\n", $$1, $$2}'

## ai-stop: stop all sidecars (brew services stop for postgres/redis, SIGTERM for others)
.PHONY: ai-stop
ai-stop: $(MLFLOW_PORT).stop litellm.stop $(TEMPORAL_PORT).stop $(CCR_PORT).stop
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

## lls-start: start llama-server router (llama.cpp b9200+ native multi-model swap)
## Uses ~/.config/litellm/llama-presets.ini — add new models there after downloading via LM Studio.
## One model loaded at a time (--models-max 1); swaps automatically on model field change.
## Port 8081 (8080 is reserved for CLIProxyAPI/Gemini).
.PHONY: lls-start
lls-start:
	@$(call port_ready,8081) && echo "llama-server already running on :8081" || \
		(llama-server \
			--models-preset "$(HOME)/.config/litellm/llama-presets.ini" \
			--models-max 1 \
			--port 8081 \
			--log-disable & \
		sleep 3 && curl -s http://localhost:8081/v1/models | \
			python3 -c "import json,sys; d=json.load(sys.stdin); print('llama-server ready —', len(d[\"data\"]), 'models available')")

## lls-stop: stop llama-server router
.PHONY: lls-stop
lls-stop:
	@pkill -f "llama-server.*8081" && echo "llama-server stopped" || echo "llama-server not running"

## lls-sync: sync lls/* litellm entries + llama-presets.ini from lms ls --json (GGUF only)
## Setup: open LM Studio → Browse → Staff Picks → download GGUF variants → run make lls-sync
## Discovers all GGUF LLMs via `lms ls --json`; skips safetensors (llama-server can't load them).
## lls/<vendor>/<model> → openai/<gguf-basename> in litellm; preset pinned to ctx=100000, kv=q8_0.
## lls/auto = smallest GGUF with full fallback chain (opt-in escalation via MODEL=lls/auto).
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
	@echo "==> Discovering GGUF models via lms ls --json"
	@lms ls --json 2>/dev/null \
	  | jq -r '[.[] | select(.type=="llm" and .format=="gguf")] | .[] | [.modelKey, .path] | @tsv' \
	  | while IFS=$$'\t' read -r model_key path; do \
	      gguf=$$(find "$(HOME)/.cache/lm-studio/models" -name "*.gguf" -path "*$${path}*" 2>/dev/null | head -1); \
	      [[ -z "$$gguf" ]] && { echo "  skip $$model_key (no GGUF found)"; continue; }; \
	      base=$$(basename "$$gguf" .gguf); \
	      lls_name="lls/$$model_key"; \
	      grep -qF "[$$base]" "$(LLS_PRESETS)" 2>/dev/null || \
	        printf '\n[%s]\nmodel = %s\nctx-size = %s\nflash-attn = on\ncache-type-k = q8_0\ncache-type-v = q8_0\n' \
	          "$$base" "$$gguf" "$(LLS_CTX)" >> "$(LLS_PRESETS)"; \
	      yq -i ".model_list += [{\"model_name\": \"$$lls_name\", \"litellm_params\": {\"model\": \"openai/$$base\", \"api_base\": \"http://localhost:$(LLS_PORT)/v1\", \"api_key\": \"none\", \"extra_body\": {\"cache_prompt\": true}}}]" "$(LITELLM_CFG)"; \
	      echo "  + $$lls_name → $$base"; \
	    done
	@echo "==> Setting lls/auto (smallest GGUF) + fallback chain"
	@first=$$(lms ls --json 2>/dev/null \
	    | jq -r '[.[] | select(.type=="llm" and .format=="gguf")] | .[0].path' 2>/dev/null); \
	  first_gguf=$$(find "$(HOME)/.cache/lm-studio/models" -name "*.gguf" -path "*$${first}*" 2>/dev/null | head -1); \
	  first_base=$$(basename "$$first_gguf" .gguf); \
	  yq -i ".model_list += [{\"model_name\": \"lls/auto\", \"litellm_params\": {\"model\": \"openai/$$first_base\", \"api_base\": \"http://localhost:$(LLS_PORT)/v1\", \"api_key\": \"none\", \"extra_body\": {\"cache_prompt\": true}}}]" "$(LITELLM_CFG)"; \
	  fallbacks=$$(lms ls --json 2>/dev/null \
	    | jq -r '[.[] | select(.type=="llm" and .format=="gguf")] | [.[].modelKey] | map("lls/" + .) | tojson'); \
	  yq -i ".router_settings.routing_strategy = \"simple-shuffle\"" "$(LITELLM_CFG)"; \
	  yq -i ".router_settings.fallbacks = [{\"lls/auto\": $$fallbacks}]" "$(LITELLM_CFG)"; \
	  echo "  lls/auto → $$first_base"
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
.PHONY: temporal
temporal:
	mkdir -p "$(dir $(TEMPORAL_DB))"
	$(call start_server,$(TEMPORAL_PORT),temporal server start-dev --db-filename $(TEMPORAL_DB) --ui-port $(TEMPORAL_UI_PORT))
	$(call check_port,$(TEMPORAL_PORT))

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

# ## mcpo: MCP → OpenAPI adapter (exposes MCP servers as REST endpoints)
# MCPO_PORT    ?= 8001
# MCPO_CONFIG  ?= $(HOME)/.config/mcp/claude-desktop.json
# MCPO_API_KEY ?= secret_mcpo_api_key
# .PHONY: mcpo
# mcpo:
# 	$(call start_server,$(MCPO_PORT),uvx mcpo --port "$(MCPO_PORT)" \
# 		--api-key "$(MCPO_API_KEY)" --config "$(MCPO_CONFIG)")
