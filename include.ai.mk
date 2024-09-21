##
## AI tools
#
FLAGS ?=
SHELL := /usr/bin/env bash
# does not work the EXCLUDEd directories are still listed
# https://www.theunixschool.com/2012/07/find-command-15-examples-to-EXCLUDE.html
# EXCLUDE := -type d \( -name extern -o -name .git \) -prune -o
# https://stackoverflow.com/questions/4210042/how-to-EXCLUDE-a-directory-in-find-command
#
# https://www.oreilly.com/library/view/managing-projects-with/0596006101/ch04.html
define START_SERVER
	if (($$(pfind "$1" | wc -l) == 0)); then "$1" serve; fi &
endef

## ai: start all ai servers
.PHONY: ai
ai: ollama open-webui

## open-webui: run open webui as frontend to ollama
.PHONY: open-webui
open-webui:
	$(call START_SERVER,open-webui)

## ollama: run ollama at http://localhost:144854
.PHONY: ollama
ollama:
	$(call START_SERVER,ollama)

## ai.kill: kill all ai all ai servers
.PHONY: ai.kill
ai.kill: ollama.kill open-webui.kill


## ollama.kill: kill the ollama server
## open-webui.kill: kill the open webui server
%.kill:
	pkill -f "$*" || true
