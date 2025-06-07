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
OLLAMA_SERVER_PORT ?=11434
OPEN_WEBUI_PORT ?= 8080
VITE_PORT ?= 5173
TIKA_PORT ?= 9998
LLAMA_SERVER_PORT ?= 8082
MLX_PORT ?= 9000
COMFY_PORT ?= 8000
MCPO_PORT ?= 8001
DOCLING_PORT ?= 5001


# different location depending on linux or Mac (Darwin)
# note: OSTYPE is set
ifneq (,$(findstring Darwin,$(shell uname -msr)))
	OPEN_WEBUI_DATA_DIR ?= $(HOME)/Library/CloudStorage/GoogleDrive-$(AI_USER)@$(AI_ORG)/Shared drives/app/open-webui-data/$(AI_USER)
else
	OPEN_WEBUI_DATA_DIR ?= $(WS_DIR)/cache/open-webui-data/$(AI_USER)
endif

## debug: environment troubleshooting
.PHONY: debug
debug:
	echo "OSTYPE=$(shell uname -msr)"
	echo "findstring=$(findstring Darwin,$(shell uname -msr))"

## rclone: rclone sync the Linux clone of Google Drive back up
# https://rclone.org/local/
# this is very hard have to make an OAuth 2.0 consent screen and then an id with the right scopes
# https://rclone.org/drive/#making-your-own-client-id
# https://rclone.org/drive/
# Gnome sync is easier but then you deal with GUIDs
# https://askubuntu.com/questions/1368874/can-google-drive-desktop-be-used-on-ubuntu
.PHONY: rclone
rclone:
	mkdir -p "$(OPEN_WEBUI_DATA_DIR)"
	rclone bisync --resync --interactive "$(OPEN_WEBUI_DATA_DIR)" "app:open-webui-data/$(AI_USER)"

# port does not work use 8080 default and is deprecated
# PORT ?= 1314

# usage: $(call start_server,port of service, app, arguments...)
# this generations a strange problem
# if ! pgrep -fL $(1) || ! lsof -i :$(2) ; then; $(3) $(4) $(5) $(6) $(7) $(8) $(9) $(10)
start_server = if ! lsof -i:$(1) -sTCP:LISTEN; then $(2) $(3) $(4) $(5) $(6) $(7) $(8) $(9) $(10); fi &

# usage: $(call open_server,port of service, url_suffix)
open_server = if lsof -i:$(1) -sTCP:LISTEN; then open "http://localhost:$(1)$(2)"; fi &

# usage $(call check_ports to see if the command wowrked)
check_port = -sleep 5 && lsof -i:$(1) -sTCP:LISTEN

## ai.install: installation requires ./src/bin
.PHONY: ai.install
ai.install:
	$(BIN_DIR)/install-ai.sh -v

## %.ps: [ ollama | open-webui | ... ].ps process status
	# @-pgrep -fL "$*"
%.ps:
	if ! pgrep -fl $*; then echo $*; fi

## %.kill:
# ignore with a dash in gnu make so || true isn't needed but there in case
# https://www.gnu.org/software/make/manual/make.html#Errors
# -f means find anywhere in the argument field
#  https://www.stackstate.com/blog/sigkill-vs-sigterm-a-developers-guide-to-process-termination/
#  Send SIGTERM 15 and wait 10 seconds then SIGKILL 9
## %.kill : [ollama | open-web | ngrok | ... ].kill the % running p$rocess
# if a pkill does not work,  on stderr you can get a "Signal 15 ignored"
# If this happens, then you need to do a kill -9
# the bug is that in doing a pgrep, it will find the search process itself as
# Make generates a new sheell
# https://stackoverflow.com/questions/49040992/pgrep-returning-true-in-makefile-but-not-in-shell
# note that you have to use the pipe because otherwise it will see the $$ in the
# bash line
# also the make itself may be there an give a false positive
# echo hello
# which pgrep
# if ! pgrep -fl ollama; then echo "no ollama"; else echo "found ollama"; fi
# if ! pgrep -fl ollama; then echo "no ollama"; else echo pkill -f ollama; fi
# if grep -q "^$$$$" <<<"$$(pgrep -f ollama)"; then echo "no ollama"; else pkill -f ollama; fi
	# if grep -q "^$$$$" <<<"$$(pgrep -f ollama)"; then echo "no ollama"; else pkill -f ollama; fi
	# if pgrep -fl %*; then pkill -l $*; fi
	# grep -q "^$$$$" <<<"$$(pgrep -f ollama)"
	# if grep -v "^$$$$" <<<"$$(pgrep -fl ollama)"; then echo "no foo"; else echo pkill -f $*; fi
	# There is always going to be the current process in addition to anything
	# running
	#
foo:
	@pgrep -fl ollama || true
	@pgrep -fl ollama | wc -l
	@if (( $$(pgrep -fl ollama | wc -l) >  1 )); \
		then \
			echo ollama;  \
			pkill -f ollama \
		; else echo \
			no ollama \
	; fi

# kill -f $* 2>/dev/null || echo "no $*"
# if grep -v "^$$$$" <<<"$$(pgrep -fl $*)"; then echo "no $*"; else echo pkill -f $*; fi
# note some need a hard kill -9 SIGKILL while this only gives a -15 SIGTERM
# so after a pkill we wait 5 an$d
# if (( $$(pgrep -fl $* | wc -l) > 1 )) && ! pkill -f $*; then
#
grep-kill = (( $$(pgrep -fl $* | wc -l) > 1 )) && ! pkill $2 -f $1

%.kill:
	if $(call grep-kill,$*); then echo pkill error; else sleep 2 && \
			if $(call grep-kill,$*,-9); then \
				echo pkill -9 error \
			; fi \
	; fi &

## ai: start minimal ai debug set
.PHONY: ai
ai: ollama open-webui tika

## ai-open: open ai ports ports ollama:11434, open-webui:8080
.PHONY: ai-open
ai-open:
	$(call open_server,$(OPEN_WEBUI_PORT))
	$(call open_server,$(OLLAMA_SERVER_PORT),/api/tags)
	$(call open_server,$(TIKA_PORT))

## ai-ps: process status of all ai processe
.PHONY: ai-ps
ai-ps: ollama.ps open_webui.ps tika.ps
	-ollama ps

# open-webui exists in pip packages, open_webui in builds from source
# 9099 is pipelines
## ai-kill: kill all ai all ai servers
.PHONY: ai-kill
ai-kill: ollama.kill $(OLLAMA_SERVER_PORT).kill \
	open_webui.kill open-webui.kill $(OPEN_WEBUI_PORT).kill \
	tika.kill $(TIKA_PORT).kill \
	vite.kill $(VITE_PORT).kill

# usage: $(call start_ollama,command,port,url_port)
# the export cannot be inside the if statement
# Note ollama takes a little time to start
# Add OLLAMA_DEBUG=1 if there are problems
OLLAMA_CONTEXT_LENGTH ?= 131072
OLLAMA_FLASH_ATTENTION ?= 1
OLLAMA_KV_CACHE_TYPE ?= q4_0
define start_ollama
	$(call start_server,$(2),OLLAMA_CONTEXT_LENGTH=$(OLLAMA_CONTEXT_LENGTH) \
		OLLAMA_HOST=$(3) OLLAMA_FLASH_ATTENTION=$(OLLAMA_FLASH_ATTENTION) \
		OLLAMA_KV_CACHE_TYPE=$(OLLAMA_KV_CACHE_TYPE) $(1) serve)
	$(call check_port,$(2))
	OLLAMA_HOST="$(3)" ollama run llama3.2:1b "hello how are you?"
endef
## ollama: run ollama at http://localhost:11434 change with OLLAMA_HOST=127.0.0.1:port
# https://docs.openwebui.com/troubleshooting/connection-error/
# 0.0.0.0 means it will serve remote openwebui clients
# https://github.com/ollama/ollama/blob/main/docs/faq.md
# note must be lower than 64K
# set the default context high for coding apps
.PHONY: ollama
ollama:
	$(call start_ollama,ollama,$(OLLAMA_SERVER_PORT),127.0.0.1:$(OLLAMA_SERVER_PORT))
	$(call check_port,$(OLLAMA_SERVER_PORT))

# usage $(call start_open-webui,OLLAMA_BASE_URL,data_dir,open_webui_backend port)
define start_open-webui
	@echo if Internet flaky turnoff set OFFLINE_MODE=1
	@echo the webui.db configuration on the python venv where you start
	-export OLLAMA_BASE_URL="$(1)" DATA_DIR="$(2)" && $(call start_server,$(3),open-webui,serve --port $(3))
	$(call check_port,$(3))
endef

## ollama-ls: List models by size
.PHONY: ollama-ls
ollama-ls:
	ollama ls | sort -k3 -hr

OLLAMA_BASE_URL ?= http://localhost:$(OLLAMA_SERVER_PORT)
# if you have your own ollama build
# the default if you have trouble note the package is open-webui and ps isAmake
# open_webui with an underscore
## open-webui: run packaged open webui as frontend port 5173 and backend 8080
.PHONY: open-webui
open-webui:
	@echo recommend starting in $(WS_DIR)/git/src/lib
	-$(call start_open-webui,$(OLLAMA_BASE_URL),$(OPEN_WEBUI_DATA_DIR),$(OPEN_WEBUI_PORT))


# the webui.db is 300MB so blows through github LFS quota too quicklk move to
# Google Drive
# OPEN_WEBUI_USER_DIR ?= $(WS_DIR)/git/src/user/$(USER)/ml/open-webui
# https://docs.openwebui.com/getting-started/env-configuration/#directories
# note that these strings are always quoted so do not put a backslash in Shared drievs

# this starts the original source version of openwebui and not the tne.ai dev
# branch TOPO merge with the tne.ai version which uses yarn instead of npm
# for some reason ahve to to an export && before the if
# usage $(call start_open_webui_src,ollama base url,source directory,data_dir,frontend port,backend port,frontend start_script)
define start_open-webui_src
  $(call start_open-webui_src_frontend,$(2),$(3),$(4),$(6))
	$(call start_open-webui_src_backend,$(1),$(2),$(3),$(4),$(5))
endef

# usage $(call start_open_webui_src_frontend,source directory,data_dir,frontend port,start_script)
# these both fail for some reason so ignore the errors with a dash
define start_open-webui_src_frontend
	-export DATA_DIR="$(2)" && \
		if ! lsof -i:$(3) -sTCP:LISTEN | grep LISTEN; then \
		cd "$(1)" && \
		$(4) ; fi &
	@echo start frontend http://localhost:$(3)
	$(call check_port,$(3))
endef

# note that pyproject is above backend and you have to start bash to run dev.sh
# usage $(call start_open_webui_src_backend,ollama base url,source directory,data_dir,backend port)
define start_open-webui_src_backend
	@echo start backend at http://localhost:$(4)
	-export DATA_DIR="$(3)" OLLAMA_BASE_URL="$(1)" PORT="$(4)"  && \
		if ! lsof -i:$(4) -sTCP:LISTEN; then \
				cd "$(2)/backend" && \
				if [[ -r requirements.txt ]]; then uv pip install -r requirements.txt; fi && \
				uv run ./dev.sh; \
			fi &
	@echo "webui.db is in $(3)"
	@echo "start open-webui at localhost:$(4)"
	$(call check_port,$(4))
endef

TIKA_VERSION ?= 2.9.2
TIKA_JAR ?= tika-server-standard-$(TIKA_VERSION).jar
## tika: run the tika server at 9998
.PHONY: tika
tika:
	$(call start_server,9998,java -jar "$$HOME/jar/$(TIKA_JAR)")
	$(call check_port,9998)

## docling: Alternative to tika for pdf, md, html, csv and images
# https://docling-project.github.io/docling/usage/supported_formats/#supported-input-formats
.PHONY: docling
docling:
	$(call start_server,$(DOCLING_PORT),docling-serve run --enable-ui --port $(DOCLING_PORT))
	$(call check_port,$(DOCLING_PORT))
	@echo "docling at http://locahost:$(DOCLING_PORT)/ui"



OLLAMA_MODEL ?= $(HOME)/.ollama/models/blobs
# look in the blog list to match this find this model in
# $HOME/.ollama/models/manifests/registry/<model name> and look for sha of the
# largest blob and insert sha256- in front of the blob number

PHI4-14B-GGUF ?= sha256-fd7b6731c33c57f61767612f56517460ec2d1e2e5a3f0163e0eb3d8d8cb5df20
DEEPSEEK-R1-14B-GGUF ?= sha256-6e9f90f02bb3b39b59e81916e8cfce9deb45aeaeb9a54a5be4414486b907dc1e
DEEPSEEK-R1-32B-GGUF ?= sha256-6150cb382311b69f09cc0f9a1b69fc029cbd742b66bb8ec531aa5ecf5c613e93
DEEPSEEK-R1-70B-GGUF ?= sha256-4cd576d9aa16961244012223abf01445567b061f1814b57dfef699e4cf8df339
# llama-server cannot  use Mistral architecture models or Gemma
MISTRAL-SMALL-3.1-24B-GGUF ?= sha256-1fa8532d986d729117d6b5ac2c884824d0717c9468094554fd1d36412c740cfc
GEMMA3-27B-GGUF ?= e796792eba26c4d3b04b0ac5adb01a453dd9ec2dfd83b6c59cbf6fe5f30b0f68
# deprecated with Qwen3
QWENCODER2.5-32B-GGUF ?= sha256-ac3d1ba8aa77755dab3806d9024e9c385ea0d5b412d6bdf9157f8a4a7e9fc0d9
QWEN2.5-14B-GGUF ?= sha256-2049f5674b1e92b4463e5729975c9689fcfbf0b0e4443ccf10b5339f370f9a54
LLAMA3.2-3B-GGUF ?= sha256-dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff

# system prmpt is deprecated
# LLAMA_SYSTEM_PROMPT ?= $(WS_DIR)/git/src/res/system-prompt/system-prompt.txt
# https://github.com/abetlen/llama-python/issues/1359
# https://github.com/open-webui/open-webui/discussions/7543
# https://github.com/ggerganov/llama/discussions/8947
## to use cache prompting must set cahce_prompt
# https://www.reddit.com/r/LocalLLaMA/comments/1fkv940/caching_some_prompts_when_using_llamaserver/

		# -m "$(OLLAMA_MODEL)/$(DEEPSEEK-R1-14B-GGUF)" \
		# -m "$(OLLAMA_MODEL)/$(PHI4-14B-GGUF)"
# Q8_0 cache is faster
# usage: $(call start_llama,port)
define start_llama
	@echo "Start dedicate llama.cpp server with specific model"
	$(call start_server,$(1),llama-server, \
		--ctx-size 131072 --port "$(1)"  \
		--verbose-prompt -v --metrics \
		--flash-attn --split-mode row \
		--keep -1 \
		 -m "$(OLLAMA_MODEL)/$(PHI4-14B-GGUF)" \
		--cache-type-k q8_0 --cache-type-v q8_0 \
		)
	$(call check_port,$(1))
endef

## llama-server: run llama.cpp server at port 8082 (default is 8080) with qwen
.PHONY: llama-server
llama-server:
	$(call start_llama,$(LLAMA_SERVER_PORT))

## comfy: Start ComfyUI Desktop
# this seems to fail unless given more time
.PHONY: comfy
comfy:
	open -a "ComfyUI.app"

## mlx: start the MacOS mlx server using huggingface cli download on port 9000
# assumes you did a download of these
QWEN2.5-14B-MLX ?= models--mlx-community--Qwen2.5-Coder-14B-Instruct-abliterated-4bit
DEEPSEEK-R1-DISTILL-LLAMA-70B-4bit ?= models--mlx-community--DeepSeek-R1-Distill-Llama-70B-4bit
HF_HUB_CACHE ?= $(HOME)/.cache/huggingface/hub
.PHONY: mlx
mlx:
	$(call start_server,$(MLX_PORT),mlx_lm.server --port $(MLX_PORT))

MCPO_CONFIG ?= $(HOME)/.config/mcp/claude-desktop.json
# set default if not set outside
MCPO_API_KEY ?= secret_mcpo_api_key
## mcpo: allow openAPI/Swagger REST API called to MCP Servers from claude-desktop.json
## see https://github.com/punkpeye/awesome-mcp-servers
#
.PHONY: mcpo
mcpo:
	$(call start_server,$(MCPO_PORT),mcpo --port "$(MCPO_PORT)" --api-key "$(MCPO_API_KEY)" --config "$(MCPO_CONFIG)")
