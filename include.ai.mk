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

# usage: $(call start_server,port of service, app, arguments...)
# this generations a strange problem
# if ! pgrep -fL $(1) || ! lsof -i :$(2) ; then; $(3) $(4) $(5) $(6) $(7) $(8) $(9) $(10)
start_server = if ! lsof -i :$(1); then $(2) $(3) $(4) $(5) $(6) $(7) $(8) $(9) $(10); fi &

# usage $(call check_ports to see if the command wowrked)
check_port = sleep 5 && lsof -i :$(1)

## %.ps: [ ollama | open-webui | ... ].ps process status
%.ps:
	@-pgrep -fL "$*"

## ai.ps: process status of all ai processes
.PHONY: ai.ps
ai.ps: ollama.ps open_webui.ps ngrok.ps tika.ps llama-server.ps vite.ps code-runner.ps
	-ollama ps

## ai.kill: kill all ai all ai servers
# open-webui exists in pip packages, open_webui in builds from source
.PHONY: ai.kill
ai.kill: ollama.kill open-webui.kill open_webui.kill tika.kill llama-server.kill vite.kill code-runner.kill ngrok.kill

## %.kill:
# ignore with a dash in gnu make so || true isn't needed but there in case
# https://www.gnu.org/software/make/manual/make.html#Errors
# -f means find anywhere in the argument field
## %.kill : [ollama | open-web | ngrok | ... ].kill the % running p$rocess
%.kill:
	-pkill -f "$*" || true


## ai: start all packaged ollama:11434, open-webui:5173, 8080, tika: 9998, comfy: 8188, llama.cpp 8081
.PHONY: ai
ai: ollama open-webui tika comfyui ngrok

## ai.res: starts research packages reseaearch
.PHONY: ai.res
ai.res: ollama open-webui-res llama-server tika comfyui ngrok-res comfyui
	@echo comfy takes up lots of ram so only use if necessary

USER ?= rich
## ai.user: start a specific users version
ai.user: ollama open-webui-user llama-server tika ngrok-res comfyui
	@echo comfy takes up lots of ram so only use if necessary

## comfyui: Start ComfyUI Desktop
.PHONE: comfyui
comfyui:
	open -a "ComfyUI.app"

## ai.dev: start your orgs dev servers
# note ollama-dev is not needed now that 0.5.5 is shipped
.PHONY: ai.dev
ai.dev: ollama open-webui-dev code-runner orion ngrok-dev

# usage: $(call start_ollama,port,executable,url)
# the export cannot be inside the if statement
define start_ollama =
	$(call start_server,$(2),OLLAMA_HOST=$(3) OLLAMA_FLASH_ATTENTION=1 OLLAMA_KV_CACHE_TYPE=q4_0 $(1) serve)
	$(call check_port,$(2))
	OLLAMA_OST="$(3)" ollama run tulu3:8b "hello how are you?"
endef
## ollama: run ollama at http://localhost:11434 change with OLLAMA_HOST=127.0.0.1:port
# https://docs.openwebui.com/troubleshooting/connection-error/
# 0.0.0.0 means it will serve remote openwebui clients
# https://github.com/ollama/ollama/blob/main/docs/faq.md
# port where tne.ai taking up the real one
# note must be lower than 64K
# standard port overridden by our special one
OLLAMA_PORT ?=11434
.PHONY: ollama
ollama:
	$(call start_ollama,ollama,$(OLLAMA_PORT),127.0.0.1:$(OLLAMA_PORT))
	$(call check_port,$(OLLAMA_PORT))

# if ou have your own private version
## ollama-res: runs private version on 21434 (deprecated with 0.5.5)
OLLAMA_PORT_RES ?= 21434
.PHONY: ollama-res
ollama-res:
	$(call start_ollama,ollama,$(OLLAMA_PORT_RES),127.0.0.1:$(OLLAMA_PORT_RES))
	$(call check_port,$(OLLAMA_PORT_RES))

# if ou have organization's dev version
## ollama-res: runs private version on 21434 (deprecated with o.5.5)
OLLAMA_PORT_DEV ?= 11434
.PHONY: ollama-dev
ollama-dev:
	cd "$(WS_DIR)/git/src/sys/ollama" && \
	make -j 5 && \
	$(call start_ollama,./ollama,$(OLLAMA_PORT_DEV),127.0.0.1:$(OLLAMA_HOST_DEV))
	$(call check_port,$(OLLAMA_PORT_DEV))

# usage $(call start_open-webui,OLLAMA_BASE_URL,open_webui_backend port)
define start_open-webui
	@echo if Internet flaky turnoff WiFi before starting
	@echo the webui.db configuration on the python venv where you start
	export OLLAMA_BASE_URL="$(1)" && \
		$(call start_server,$(2),open-webui,serve --port $(2))
	$(call check_port,$2)
endef

OPEN_WEBUI_PORT ?= 8080
OLLAMA_BASE_URL ?= http://localhost:$(OLLAMA_PORT)
# if you have your own ollama build
# the default if you have trouble note the package is open-webui and ps is
# open_webui with an underscore
## open-webui: run packaged open webui as frontend port 5173 and backend 8080
.PHONY: open-webui
open-webui:
	@echo recommend starting in $(WS_DIR)/git/src
	$(call start_open-webui,$(OLLAMA_BASE_URL),$(OPEN_WEBUI_PORT))

OPEN_WEBUI_USER_DIR ?= $(WS_DIR)/git/src/user/$(USER)/ml/open-webui
PYTHON ?= 3.12
define run_open_webui_backup
		cp "$(2)/webui.db" \
			"$(WS_DIR)/data/webui.$(1).$(shell date +"%Y-%m-%d.%H-%M-%S").db"
endef

OPEN_WEBUI_DB ?= "$(HOME)/.local/pipx/venvs/open-webui/lib/python$(PYTHON)/site-packages/open_webui/data"
## open-webui-backup: backup the webui.db with configs and chats
.PHONY: open-webui-backup
open-webui-backup:
	$(call run_open_webui_backup,pipx,$(OPEN_WEBUI_DB))


## open-webui-backup-user: backup the webui.db for user
.PHONY: open-webui-backup-user
open-webui-backup-user:
	$(call run_open_webui_backup,$(USER),$(OPEN_WEBUI_USER_DIR)/backend/data/)

## open-webui-backup-res: backup the webui.db for research
.PHONY: open-webui-backup-res
open-webui-backup-res:
	$(call run_open_webui_backup,res,$(WS_DIR)/git/src/res/open-webui/backend/data/)


OPEN_WEBUI_FRONTEND_RES_PORT ?= 25173
OPEN_WEBUI_BACKEND_RES_PORT ?= 28080
# usage $(call start_open_webui,source directory)
define start_open_webui
	@echo start frontend http://localhost:$(OPEN_WEBUI_FRONTEND_RES_PORT)
	if ! lsof -i :$(OPEN_WEBUI_FRONTEND_RES_PORT); then \
		cd "$(1)" && npm install && \
		npm run build && \
		npm run pyodide:fetch && \
		vite dev --host --port "$(OPEN_WEBUI_FRONTEND_RES_PORT)";\
	fi &
	@echo start backend at http://localhost:$(OPEN_WEBUI_BACKEND_RES_PORT)
	if ! lsof -i :$(OPEN_WEBUI_BACKEND_RES_PORT); then cd "$(1)/backend" && \
		uv sync && uv pip install -r requirements.txt && uv lock && \
		PORT="$(OPEN_WEBUI_BACKEND_RES_PORT)" uv run dev.sh; fi &
	@echo "webui.db is in $(1)/.venv)"
	@echo "start open-webui at localhost:$(OPEN_WEBUI_BACKEND_RES_PORT)"
	$(call check_port,$(OPEN_WEBUI_BACKEND_RES_PORT))
	$(call check_port,$(OPEN_WEBUI_FRONTEND_RES_PORT))
endef

OPEN_WEBUI_RES_DIR ?= $(WS_DIR)/git/src/res/open-webui
## open-webui-res: Run local for the research group
.PHONY: open-webui-res
open-webui-res:
	$(call start_open_webui,$(OPEN_WEBUI_RES_DIR))


## open-webui-user: Run local for a specific user (default on non standard frontend port 25173 and backedn 28080)
.PHONY: open-webui-user
open-webui-user:
	@echo "Make sure that you are on the right branch like rich-dev"
	@echo "Make sure you brew install asdf direnv"
	@echo "Make sure you run to right python version asdf direnv local python 3.12.7"
	@echo "Check with command -v python it points to a .venv in that directory"
	$(call start_open_webui,$(OPEN_WEBUI_USER_DIR))


OPEN_WEBUI_DEV_DIR ?= $(WS_DIR)/git/src/sys/orion/extern/open-webui
## open-webui-dev: Run local for a specific org front-end port 5174 (nonstandard) and port 8081 (nonstandard)
.PHONY: open-webui-dev
open-webui-dev:
	@echo start frontend
	if ! lsof -i :5174; then cd "$(OPEN_WEBUI_DEV_DIR)" && yarn install && yarn dev; fi &
	@echo start backend
	if ! lsof -i :8081; then cd $(OPEN_WEBUI_DEV_DIR)/backend && uv run dev.sh; fi &
	@echo "webui.db is in $(OPEN_WEBUI_DEV_DIR/.venv)"
	@echo "start open-webui at localhost:8081"
	$(call check_port,8081)

CODE_RUNNER_DIR ?= $(WS_DIR)/git/src/sys/troopship/code-runner
## code-runner: Dev code-runner on port 8080
.PHONY: code-runner
code-runner:
	if ! lsof -i :8080; then cd "$(CODE_RUNNER_DIR)" && \
			source .venv/bin/activate && make run; fi  &
	$(call check_port,8080)

## orion: start the Max app Orion
.PHONY: orion
orion:
	open -a Orion.app

# usage: $(call start_server,1password item,local port,ngrok url)
define start_ngrok
	command -v ngrok >/dev/null && \
		ngrok config add-authtoken "$$(op item get "$(1)" --fields "auth token" --reveal)" && \
		$(call start_server,4040,ngrok,http "$(2)" --url "$(3)" --oauth google --oauth-allow-domain tne.ai --oauth-allow-domain tongfamily.com)
	$(call check_port,4040)
endef

## ngrok-dev: authentication front-end using ngrok Dev
# doing a pkill before seems to stop the run so only ai.kill does the stopping
# development port
DEV_PORT ?= 5174
# default
DEFAULT_PORT ?= 8080
# port for experimental builds
RESEARCH_PORT ?= 28080

## ngrok-dev: development port on early-lenient-goldfish.ngrok-free.app
.PHONY: ngrok-dev
ngrok-dev:
	$(call start_ngrok,ngrok Dev,$(DEV_PORT),early-lenient-goldfish.ngrok-free.app)

## ngrok2: SEcond default on early-lenient-goldfish.ngrok-free.app
.PHONY: ngrok2
ngrok2:
	$(call start_ngrok,ngrok Dev,$(DEFAULT_PORT),early-lenient-goldfish.ngrok-free.app)

## ngrok-res: Sepcial build on 28880 at organic-pegasus-solely.ngrok-free.app
.PHONY: ngrok-res
ngrok-res:
	$(call start_ngrok,ngrok,$(RESEARCH_PORT),organic-pegasus-solely.ngrok-free.app)

## ngrok: authentication for 8080 at organic-pegasus-solely.ngrok-free.app
.PHONY: ngrok
ngrok:
	$(call start_ngrok,ngrok,$(DEFAULT_PORT),organic-pegasus-solely.ngrok-free.app)

TIKA_VERSION ?= 2.9.2
TIKA_JAR ?= tika-server-standard-$(TIKA_VERSION).jar
## tika: run the tika server at 9998
.PHONY: tika
tika:
	$(call start_server,9998,java -jar "$$HOME/jar/$(TIKA_JAR)")
	$(call check_port,9998)


OLLAMA_MODEL ?= $(HOME)/.ollama/models/blobs
QWENCODER2.5-32B_GGUF ?= sha256-ac3d1ba8aa77755dab3806d9024e9c385ea0d5b412d6bdf9157f8a4a7e9fc0d9
# find this model in $HOME/.ollama/models/library/manifest and look for sha
# and insert sha256- in front of the blob number
LLAMA3.2-3B_GGUF ?= sha256-dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff
		# -m "$(OLLAMA_MODEL)/$(LLAMA3.2-3B_GGUF)" \
# this phi4 not compatible
PHI4-14B_GGUF ?= sha256-fd7b6731c33c57f61767612f56517460ec2d1e2e5a3f0163e0eb3d8d8cb5df20
# system prmpt is deprecated
# LLAMA_SYSTEM_PROMPT ?= $(WS_DIR)/git/src/res/system-prompt/system-prompt.txt
# https://github.com/abetlen/llama-python/issues/1359
# https://github.com/open-webui/open-webui/discussions/7543
# https://github.com/ggerganov/llama/discussions/8947
## to use cache prompting must set cahce_prompt
# https://www.reddit.com/r/LocalLLaMA/comments/1fkv940/caching_some_prompts_when_using_llamaserver/

# usage: $(call start_llama,port)
define start_llama =
@echo "Start dedicate llama.cpp server with Phi4:14B search for sha"
	$(call start_server,$(1),llama-server, \
		-c 131072 --port "$(1)"  \
		--verbose-prompt -v --metrics \
		--flash-attn -sm row \
		--cache-type-k q8_0 --cache-type-v q8_0 \
		-m "$(OLLAMA_MODEL)/$(PHI4-14B_GGUF)" \
		)
	$(call check_port,$(1))
endef

## llama-server: run llama.cpp server at port 8081 (default is 8080) with qwen
LLAMA_PORT ?= 8081
.PHONY: llama-server
llama-server:
	$(call start_llama,$(LLAMA_PORT))
