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
ai: ollama open-webui tika ngrok

## ai.res: starts research packages reseaearch
.PHONY: ai.res
ai.res: ollama open-webui.res llama-server tika comfyui ngrok.res comfyui
	@echo comfy takes up lots of ram so only use if necessary

USER ?= rich
## ai.user: start a specific users version
ai.user: ollama open-webui-user llama-server tika ngrok.res comfyui
	@echo comfy takes up lots of ram so only use if necessary

## exo: Start the exo LLM cluster system set EXO Home to 4TB Drive
# the --directory does not work
EXO_HOME ?= /Volumes/Hagibis ASM2464PD/Exo
EXO_REPO ?= $(WS_DIR)/git/src/res/exo
.PHONY: exo
exo:
	cd "$(EXO_REPO)" && EXO_HOME="$(EXO_HOME)" uv run exo

## comfyui: Start ComfyUI Desktop
# this seems to fail unless given more time
.PHONY: comfyui
comfyui:
	open -a "ComfyUI.app"

## ai.dev: start your orgs dev servers
# note ollama-dev is not needed now that 0.5.5 is shipped
.PHONY: ai.dev
ai.dev: ollama open-webui.dev code-runner orion ngrok.dev

# usage: $(call start_ollama,port,executable,url)
# the export cannot be inside the if statement
define start_ollama =
	$(call start_server,$(2),OLLAMA_DEBUG=1 OLLAMA_HOST=$(3) OLLAMA_FLASH_ATTENTION=1 OLLAMA_KV_CACHE_TYPE=q4_0 $(1) serve)
	$(call check_port,$(2))
	OLLAMA_HOST="$(3)" ollama run tulu3:8b "hello how are you?"
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

# usage $(call start_open-webui,OLLAMA_BASE_URL,data_dir,open_webui_backend port)
define start_open-webui
	@echo if Internet flaky turnoff set OFFLINE_MODE=1
	@echo the webui.db configuration on the python venv where you start
	-export OLLAMA_BASE_URL="$(1)" DATA_DIR="$(2)" && $(call start_server,$(3),open-webui,serve --port $(3))
	$(call check_port,$(3))
endef

OPEN_WEBUI_PORT ?= 8080
OLLAMA_BASE_URL ?= http://localhost:$(OLLAMA_PORT)
# if you have your own ollama build
# the default if you have trouble note the package is open-webui and ps isAmake
# open_webui with an underscore
## open-webui: run packaged open webui as frontend port 5173 and backend 8080
.PHONY: open-webui
open-webui:
	@echo recommend starting in $(WS_DIR)/git/src
	-$(call start_open-webui,$(OLLAMA_BASE_URL),$(OPEN_WEBUI_DATA_DIR),$(OPEN_WEBUI_PORT))

# the webui.db is 300MB so blows through github LFS quota too quicklk move to
# Google Drive
# OPEN_WEBUI_USER_DIR ?= $(WS_DIR)/git/src/user/$(USER)/ml/open-webui
# https://docs.openwebui.com/getting-started/env-configuration/#directories
OPEN_WEBUI_DATA_DIR ?= $(HOME)/Library/CloudStorage/GoogleDrive-$(USER)@tne.ai/Shared drives/app/open-webui-data/demo

PYTHON ?= 3.12

# usage $(call start_open_webui_dev,source directory,data_dir,frontend port,backend port)
# this starts the git cloned development frontend and backend
define start_open-webui_dev
	@echo start frontend http://localhost:$(3)
	if ! lsof -i :$(3); then \
		cd "$(1)" && npm install && \
		npm run build && \
		npm run pyodide:fetch && \
		DATA_DIR="$(2)" uv run vite dev --host --port "$(3)";\
	fi &
	@echo start backend at http://localhost:$(4)
	if ! lsof -i :$(4); then cd "$(1)/backend" && \
		uv sync && uv pip install -r requirements.txt && uv lock && \
		DATA_DIR="$(2)" OLLAMA_BASE_URL="$(OLLAMA_BASE_URL)" PORT="$(4)" uv run dev.sh; fi &
	@echo "webui.db is in $(2)"
	@echo "start open-webui at localhost:$(4)"
	$(call check_port,$(3))
	$(call check_port,$(4))
endef

OPEN_WEBUI_RES_DIR ?= $(WS_DIR)/git/src/res/open-webui
OPEN_WEBUI_RES_FRONTEND_PORT ?= 25173
OPEN_WEBUI_RES_BACKEND_PORT ?= 28080
## open-webui-res: Run local for the research group
.PHONY: open-webui-res
open-webui-res:
	$(call start_open-webui_dev,$(OPEN_WEBUI_RES_DIR),$(OPEN_WEBUI_DATA_DIR),$(OPEN_WEBUI_RES_FRONTEND_PORT),$(OPEN_WEBUI_RES_BACKEND_PORT))


## open-webui.user: Run local for a specific user (default on non standard frontend port 25173 and backedn 28080)
.PHONY: open-webui.user
open-webui.user:
	@echo "Make sure that you are on the right branch like rich-dev"
	@echo "Make sure you brew install asdf direnv"
	@echo "Make sure you run to right python version asdf direnv local python 3.12.7"
	@echo "Check with command -v python it points to a .venv in that directory"
	$(call start_open-webui_dev,$(OPEN_WEBUI_USER_DIR),$(OPEN_WEBUI_DATA_DIR),$(OPEN_WEBUI_USER_FRONTEND_PORT),$(OPEN_WEBUI_USER_BACKEND_PORT


OPEN_WEBUI_DEV_DIR ?= $(WS_DIR)/git/src/sys/orion/extern/open-webui
## open-webui.dev: Run local for a specific org front-end port 5174 (nonstandard) and port 8081 (nonstandard)
.PHONY: open-webui.dev
open-webui.dev:
	@echo start frontend
	if ! lsof -i :5174; then cd "$(OPEN_WEBUI_DEV_DIR)" && DATA_DIR="$(OPEN_WEBUI_DATA_DIR)" yarn install && yarn dev; fi &
	@echo start backend
	if ! lsof -i :8081; then cd $(OPEN_WEBUI_DEV_DIR)/backend && DATA_DIR=$(OPEN_WEBUI_DATA_DIR) PORT=8081 uv run dev.sh; fi &
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
		ngrok config add-authtoken "$$(op item get "$(1)" --fields "auth token" --reveal)"
	$(call start_server,4040,ngrok,http "$(2)" --url "$(3)" --oauth google --oauth-allow-domain tne.ai --oauth-allow-domain tongfamily.com)
	$(call check_port,4040)
endef

## ngrok.dev: authentication front-end using ngrok Dev
# doing a pkill before seems to stop the run so only ai.kill does the stopping
# development port
DEV_PORT ?= 5174
# default
DEFAULT_PORT ?= 8080
# port for experimental builds
RESEARCH_PORT ?= 28080

## ngrok.dev: development port on early-lenient-goldfish.ngrok.free.app
.PHONY: ngrok.dev
ngrok.dev:
	$(call start_ngrok,ngrok Dev,$(DEV_PORT),early-lenient-goldfish.ngrok.free.app)

## ngrok2: SEcond default on early-lenient-goldfish.ngrok.free.app
.PHONY: ngrok2
ngrok2:
	$(call start_ngrok,ngrok Dev,$(DEFAULT_PORT),early-lenient-goldfish.ngrok.free.app)

## ngrok.res: Sepcial build on 28880 at organic-pegasus-solely.ngrok.free.app
.PHONY: ngrok.res
ngrok.res:
	$(call start_ngrok,ngrok,$(RESEARCH_PORT),organic-pegasus-solely.ngrok.free.app)

## ngrok: authentication for 8080 at organic-pegasus-solely.ngrok.free.app
.PHONY: ngrok
ngrok:
	$(call start_ngrok,ngrok,$(DEFAULT_PORT),organic-pegasus-solely.ngrok.free.app)

TIKA_VERSION ?= 2.9.2
TIKA_JAR ?= tika-server-standard-$(TIKA_VERSION).jar
## tika: run the tika server at 9998
.PHONY: tika
tika:
	$(call start_server,9998,java -jar "$$HOME/jar/$(TIKA_JAR)")
	$(call check_port,9998)


OLLAMA_MODEL ?= $(HOME)/.ollama/models/blobs
QWENCODER2.5-32B-GGUF ?= sha256-ac3d1ba8aa77755dab3806d9024e9c385ea0d5b412d6bdf9157f8a4a7e9fc0d9
# find this model in $HOME/.ollama/models/library/manifest and look for sha
# and insert sha256- in front of the blob number
LLAMA3.2-3B-GGUF ?= sha256-dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff
#
# does not work with full skyfall
PHI4-14B-GGUF ?= sha256-fd7b6731c33c57f61767612f56517460ec2d1e2e5a3f0163e0eb3d8d8cb5df20

# doe not work with Skyfall
QWEN2.5-14B-GGUF ?= sha256-2049f5674b1e92b4464e5729975c9689fcfbf0b0e4443ccf10b5339f370f9a54

DEEPSEEK-R1-14B-GGUF ?= sha256-6e9f90f02bb3b39b59e81916e8cfce9deb45aeaeb9a54a5be4414486b907dc1e
DEEPSEEK-R1-32B-GGUF ?= sha256-6150cb382311b69f09cc0f9a1b69fc029cbd742b66bb8ec531aa5ecf5c613e93
DEEPSEEK-R1-70B-GGUF ?= sha256-4cd576d9aa16961244012223abf01445567b061f1814b57dfef699e4cf8df339


# system prmpt is deprecated
# LLAMA_SYSTEM_PROMPT ?= $(WS_DIR)/git/src/res/system-prompt/system-prompt.txt
# https://github.com/abetlen/llama-python/issues/1359
# https://github.com/open-webui/open-webui/discussions/7543
# https://github.com/ggerganov/llama/discussions/8947
## to use cache prompting must set cahce_prompt
# https://www.reddit.com/r/LocalLLaMA/comments/1fkv940/caching_some_prompts_when_using_llamaserver/

# usage: $(call start_llama,port)
		# -m "$(OLLAMA_MODEL)/$(DEEPSEEK-R1-14B-GGUF)" \
		# -m "$(OLLAMA_MODEL)/$(PHI4-14B-GGUF)"
# Q8_0 cache is faster
define start_llama =
@echo "Start dedicate llama.cpp server with specific model"
	$(call start_server,$(1),llama-server, \
		--ctx-size 131072 --port "$(1)"  \
		--verbose-prompt -v --metrics \
		--flash-attn --split-mode row \
		--keep -1 \
		 -m "$(OLLAMA_MODEL)/$(DEEPSEEK-R1-14B-GGUF)" \
		--cache-type-k q8_0 --cache-type-v q8_0 \
		)
	$(call check_port,$(1))
endef

## llama-server: run llama.cpp server at port 8081 (default is 8080) with qwen
LLAMA_PORT ?= 8081
.PHONY: llama-server
llama-server:
	$(call start_llama,$(LLAMA_PORT))
