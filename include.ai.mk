##
## AI tools
#
FLAGS ?=
SHELL := /usr/bin/env bash
PORT ?= 1314
# does not work the EXCLUDEd directories are still listed
# https://www.theunixschool.com/2012/07/find-command-15-examples-to-EXCLUDE.html
# EXCLUDE := -type d \( -name extern -o -name .git \) -prune -o
# https://stackoverflow.com/questions/4210042/how-to-EXCLUDE-a-directory-in-find-command
#
# https://www.oreilly.com/library/view/managing-projects-with/0596006101/ch04.html
define START_SERVER
	if (($$(pfind $(1) | wc -l) == 0)); then $(1) serve $(2) $(3) $(4) $(5); fi &
endef

## ai: start all ai servers
.PHONY: ai
ai: ollama open-webui

## open-webui: run open webui as frontend to ollama at port 1314 change with PORT=port
.PHONY: open-webui
open-webui:
	$(call START_SERVER,open-webui,--port $(PORT))

## ollama: run ollama at http://localhost:11434 change with OLLAMA_HOST=127.0.0.1:port
.PHONY: ollama
ollama:
	$(call START_SERVER,ollama)

## ai.kill: kill all ai all ai servers
.PHONY: ai.kill
ai.kill: ollama.kill open-webui.kill


## ollama.kill: kill the ollama server
## open-webui.kill: kill the open webui server
# ignore with a dash in gnu make
# https://www.gnu.org/software/make/manual/make.html#Errors
%.kill:
	-pkill -f ".*$*.*" || true
