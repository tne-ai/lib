##
## AI tools
#
FLAGS ?=
SHELL := /usr/bin/env bash
# port does not work use 8080 default and is deprecated
# PORT ?= 1314
# does not work the EXCLUDEd directories are still listed
# https://www.theunixschool.com/2012/07/find-command-15-examples-to-EXCLUDE.html
# EXCLUDE := -type d \( -name extern -o -name .git \) -prune -o
# https://stackoverflow.com/questions/4210042/how-to-EXCLUDE-a-directory-in-find-command
#
# https://www.oreilly.com/library/view/managing-projects-with/0596006101/ch04.html

# usage: $(call start_server,pgrep string, app, arguments...)
define start_server
if ! pgrep -fL $(1) ; then $(2) $(3) $(4) $(5) $(6) $(7) $(8) $(9) $(10) \
	$(11) $(12) $(13) $(14) $(15) $(16) $(17) $(18) $(19) $(20); fi &
endef

# usage $(call check_ports to see if the command wowrked)
define check_ports
	sleep 5 && lsof -i @localhost
endef

## %.ps: [ ollama | open-webui | ... ].ps process status
%.ps:
	-pgrep -fL "$*"

## ai.ps: process status of all ai processes
.PHONY: ai.ps
ai.ps: ollama.ps open_webui.ps ngrok.ps tika.ps llama.ps
	-ollama ps

## ai.kill: kill all ai all ai servers
.PHONY: ai.kill
ai.kill: ollama.kill open_webui.kill tika.kill llama.kill

## %.kill:
# ignore with a dash in gnu make so || true isn't needed but there in case
# https://www.gnu.org/software/make/manual/make.html#Errors
# -f means find anywhere in the argument field
## %.kill : [ollama | open-web | ngrok | ... ].kill the % running process
%.kill:
	-pkill -f "$*" || true


## ai: start all packaged ollama:11434, open-webui:5173, 8080, tika: 9998, comfy: 8188, llama.cpp 8081
.PHONY: ai
ai: ollama open-webui llama tika

## ai.user: starts user paackages
.PHONY: ai.user
ai.user: ollama-user open-webui-user tika

## ai.dev: start your orgs dev servers
.PHONY: ai.dev
ai.dev: ollama-dev open-webui-dev tika

# usage: $(call start_ollama,executable,host:port)
# the export cannot be inside the if statement
define start_ollama
		$(call start_server,"$(2).*$(1)", \
				OLLAMA_HOST=$(2), \
				OLLAMA_FLASH_ATTENTION=1, \
				OLLAMA_KV_CACHE_TYPE=q4_0, \
			$(1) serve)
	$(call check_ports)
	OLLAMA_HOST="$(2)" ollama run tulu3:8b "hello how are you?"
endef
## ollama: run ollama at http://localhost:11434 change with OLLAMA_HOST=127.0.0.1:port
# https://docs.openwebui.com/troubleshooting/connection-error/
# 0.0.0.0 means it will serve remote openwebui clients
# https://github.com/ollama/ollama/blob/main/docs/faq.md
# port where tne.ai taking up the real one
# note must be lower than 64K
# standard port overridden by our special one
OLLAMA_HOST ?= 127.0.0.1:11434
.PHONY: ollama
ollama:
	$(call start_ollama,ollama,$(OLLAMA_HOST))

# if ou have your own private version
## ollama-user: runs private version on 21434
OLLAMA_HOST_USER ?= 127.0.0.1:21434
.PHONY: ollama-user
ollama-user:
	$(call start_ollama,ollama,$(OLLAMA_HOST_USER))

# if ou have organization's dev version
## ollama-user: runs private version on 21434
OLLAMA_HOST_DEV ?= 127.0.0.1:11434
.PHONY: ollama-dev
ollama-dev:
	cd "$(WS_DIR)/git/src/sys/ollama" && \
	make -j 5 && \
	$(call start_ollama,./ollama,$(OLLAMA_HOST_DEV))

# usage $(call start_open-webui, OLLAMA_BASE_URL, open_webui backend port)
define start_open-webui
	@echo if Internet flaky turnoff WiFi before starting
	@echo the webui.db configuration on the python venv where you start
	export OLLAMA_BASE_URL="$(1)" && \
		$(call start_server,open-webui,open-webui,serve --port $(2))
	$(call check_ports)
endef

OLLAMA_BASE_URL ?= http://localhost/$(OLLAMA_HOST)
OPEN_WEBUI_PORT ?= 8080
# if you have your own ollama build
# the default if you have trouble note the package is open-webui and ps is
# open_webui with an underscore
## open-webui: run packaged open webui as frontend port 5173 and backend 8080
.PHONY: open-webui
open-webui:
	@echo recommend starting in $(WS_DIR)/git/src
	$(call start_open-webui, $(OLLAMA_BASE_URL),$(OPEN_WEBUI_PORT))

USER ?= rich
OPEN_WEBUI_USER_DIR ?= $(WS_DIR)/git/src/user/$(USER)/ml/open-webui
OPEN_WEBUI_FRONTEND_DEV_PORT ?= 25173
OPEN_WEBUI_BACKEND_DEV_PORT ?= 28080
## open-webui-user: Run local for a specific user (default rich on non standard frontend port 25173 and backedn 28080)
.PHONY: open-webui-user
open-webui-user:
	@echo start frontend http://localhost:$(OPEN_WEBUI_FRONTEND_DEV_PORT)
	cd "$(OPEN_WEBUI_USER_DIR)" && npm run pyodide:fetch && vite dev --host --port "$(OPEN_WEBUI_FRONTEND_DEV_PORT)" &
	@echo start backend at http://localhost:$(OPEN_WEBUI_BACKEND_DEV_PORT)
	cd "$(OPEN_WEBUI_USER_DIR)/backend" && \
		uv sync && uv pip install -r requirements.txt && uv lock && \
		PORT="$(OPEN_WEBUI_BACKEND_DEV_PORT)" uv run dev.sh & 
	@echo "webui.db is in $(OPEN_WEBUI_USER_DIR/.venv)"
	@echo "start open-webui at localhost:$(OPEN_WEBUI_BACKEND_DEV_PORT)"
	$(call check_ports)

OPEN_WEBUI_DEV_DIR ?= $(WS_DIR)/git/src/sys/orion/extern/open-webui
## open-webui-dev: Run local for a specific org front-end port 5174 (nonstandard) and port 8081 (nonstandard)
.PHONY: open-webui-org
open-webui-org:
	@echo start frontend
	cd "$(OPEN_WEBUI_DEV_DIR)" && yarn install && yarn dev &
	@echo start backend
	cd $(OPEN_WEBUI_DEV_DIR/backend) && uv sync && uv run dev.sh
	@echo "webui.db is in $(OPEN_WEBUI_DEV_DIR/.venv)"
	@echo "start open-webui at localhost:8081"
	$(call check_ports)

# usgae: $(call start_server,1password item,local port, ngrok url)
define start_ngrok
	command -v ngrok >/dev/null && ngrok config add-authtoken "$$(op item get $(1)" --fields "auth token" --reveal)" && \
	$(call start_server,ngrok, ngrok http "$(2)" --url "$(3)" --oauth google --oauth-domain tne.ai --oauth-domain tongfamily.com --oauth-allow-localhost)
	$(call check_ports)
endef

## ngrok-dev: authentication front-end using ngrok Dev
# doing a pkill before seems to stop the run so only ai.kill does the stopping
.PHONY: ngrok-dev
ngrok-dev:
	$(call start_ngrok,ngrok Dev, 8080,early-lenient-goldfish.ngrok-free.app )

## ngrok: authentication front-end using your personal account
.PHONY: ngrok
ngrok-user:
	$(call start_ngrok,ngrok, 8080,organic-pegasus-solely.ngrok-free.app)

TIKA_VERSION ?= 2.9.2
TIKA_JAR ?= tika-server-standard-$(TIKA_VERSION).jar
## tika: run the tika server at 9998
.PHONY: tika
tika:
	$(call start_server,$(TIKA_JAR),java,-jar,"$$HOME/jar/$(TIKA_JAR)")
	$(call check_ports)

OLLAMA_MODEL ?= $(HOME)/.ollama/models/blobs
# huge model
QWENCODER2.5-32B_GGUF: sha256-ac3d1ba8aa77755dab3806d9024e9c385ea0d5b412d6bdf9157f8a4a7e9fc0d9
# find this model in $HOME/.ollama/models/library and look for shar
# and insert sha256- in front of the blob number
LLAMA3.2-3B_GGUF ?= sha256-dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff
LLAMA_GGUF ?= $(LLAMA3.2-3B_GGUF)
LLAMA_SYSTEM_PROMPT ?= $(WS_DIR)/git/src/res/system-prompt/system-prompt.txt
# https://github.com/abetlen/llama-python/issues/1359
# https://github.com/open-webui/open-webui/discussions/7543
## llama: run llama at port 8081 (default is 8080) with qwen
# https://github.com/ggerganov/llama/discussions/8947
## to use cache prompting must set cahce_prompt
# https://www.reddit.com/r/LocalLLaMA/comments/1fkv940/caching_some_prompts_when_using_llamaserver/
LLAMA_PORT ?= 8081
LLAMA_PORT ?= 28081
.PHONY: llama
llama:
	$(call start_server,llama-server,llama-server, \
		-c 131072 --port "$(LLAMA_PORT)",  \
		--verbose-prompt -v, --metrics, \
		--flash-attn -sm row, \
		--cache-type-k q8_0 --cache-type-v q8_0, \
		-f "$(LLAMA_SYSTEM_PROMPT)", \
		-m "$(OLLAMA_MODEL)/$(LLAMA_GGUF)" \
		)
	$(call check_ports)
