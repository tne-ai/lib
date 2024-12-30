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
PORT ?= 8080
define START_SERVER
if ! pgrep -L $(1) ; then echo start $(2) && $(2) $(3) $(4) $(5) $(6) $(7) $(8) $(9) $(10); fi &
endef

## ai: start all ai servers
.PHONY: ai
ai: ollama tika open-webui
ai: ollama open-webui

## open-webui: run open webui as frontend which is hard coded at 8080
.PHONY: open-webui
open-webui:
	$(call START_SERVER,open-webui,open-webui,serve)

## ollama: run ollama at http://localhost:11434 change with OLLAMA_HOST=127.0.0.1:port
# https://docs.openwebui.com/troubleshooting/connection-error/
# 0.0.0.0 means it will serve remote openwebui clients
.PHONY: ollama
ollama:
	export OLLAMA_HOST=0.0.0.0 && $(call START_SERVER,ollama,ollama,serve)

## ngrok: authentication front-end for open-webui uses 1Password to 8080 onlyi 1 active at a time
# doing a pkill before seems to stop the run so only ai.kill does the stopping
.PHONY: ngrok
ngrok:
	$(call START_SERVER,ngrok,ngrok,http,--url="$$(op item get 'ngrok' --field 'static domain')","$(PORT)", \
		--oauth=google,--oauth-allow-domain=tne.ai, --oauth-allow-domain=tongfamily.com)


TIKA_VERSION ?= 2.9.2
TIKA_JAR ?= tika-server-standard-$(TIKA_VERSION).jar

## tika: run the tika server at 9998
.PHONY: tika
tika:
	$(call START_SERVER,$(TIKA_JAR),java,-jar,"$$HOME/jar/$(TIKA_JAR)")

## ai.kill: kill all ai all ai servers
.PHONY: ai.kill
ai.kill: ollama.kill open-webui.kill ngrok.kill tika.kill

## %.kill:
# ignore with a dash in gnu make so || true isn't needed but there in case
# https://www.gnu.org/software/make/manual/make.html#Errors
# -f means find anywhere in the argument field
## %.kill : [ollama | open-web | ngrok | ... ].kill the % running process
%.kill:
	-pkill -f "$*" || true
	sleep 5

## %.ps: [ ollama | open-webui | ... ].ps process status
%.ps:
	@pgrep -fl "$*"
	ollama ps

## ai.ps: process status of all ai processes
.PHONY: ai.ps
ai.ps: ollama.ps open-webui.ps ngrok.ps
	ollama ps


## ngrok: authentication front-end for open-webui uses 1Password to 8080
# doing a pkill before seems to stop the run so only ai.kill does the stopping
.PHONY: ngrok
ngrok: ngrok.kill
	$(call START_SERVER,ngrok,http,--url="$$(op item get 'ngrok' --field 'static domain')","$(PORT)", \
		--oauth=google,--oauth-allow-domain=tne.ai, --oauth-allow-domain=tongfamily.com)
