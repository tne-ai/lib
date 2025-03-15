##
## TNE.ai specific makes
## -----
ORG ?= tne

STUDIO_SUBMODULE_DIR ?= $(WS_DIR)/git/src/user
STUDIO_AWS_S3 ?= s3://bp-authoring-files/d
STUDIO_PREFIX ?= studio
STUDIO_USER ?= demo
GITHUB_ORG ?= $(ORG)-ai
STUDIO_EMAIL_ORG ?= $(ORG).ai
STUDIO_EMAIL ?= $(STUDIO_USER)@$(STUDIO_EMAIL_ORG)
STUDIO_REPO ?= $(STUDIO_PREFIX)-$(STUDIO_USER)
STUDIO_REPO_URL ?= git@github.com:$(ORG)/$(STUDIO_REPO)

MIN_SUBMODULE ?= bin lib
## install: base install of all needed repos and tools, set $(USER) and clone into ws/git
	# ./bin/pre-install.sh -vr $(USER) -- this install is too big
.PHONY: install
install:
	brew install git bash
	if [[ $$OSTYPE =~ darwin ]]; then brew install mas proctools; fi
	git submodule update --init --recursive --remote $(MIN_SUBMODULE)
	cd bin && git switch main && git pull --ff-only
	-cd bin &&	./git-submodule-update.sh -v
	cd bin && \
		./install-1password.sh -v && \
		./install-asdf.sh -v && \
		./install-git-tools.sh -v && \
		./install-node.sh -v && \
		./install-python.sh -v && \
		./install-zsh.sh -v && \
		./install-ai.sh -v
	pgrep -f ollama || (ollama serve &)
	cd bin &&
		./install-models.sh -v
	pipx upgrade-all
	brew upgrade
	git submodule foreach --recursive git pull --ff-only

## auth0-id: what is your auth0 id for your $(STUDIO_EMAIL)
# note that the shell is evaluated before the target even starts so you need
# https://auth0.github.io/auth0-cli/
# auth0 login before you can run this line so run a command which authenticates
# we need this dependency because the AUTH0_ID shell script needs a login first
# and we do not want to see the junk from tenants list as there is no way to
# query auth0 to see if you are logged in from the cli
AUTH0_ID=$(shell auth0 users search -q email:$(STUDIO_EMAIL) --json | jq '.[0].identities[0].user_id')
.PHONY: auth0-id
auth0-id:
	@echo Looking Auth0 for: $(STUDIO_EMAIL)
	@echo Found Auth0 id: $(AUTH0_ID)


## ai.res: starts research packages reseaearch
.PHONY: ai.res
ai.res: ollama open-webui.res

## ai.user: start a specific users version
ai.user: ollama open-webui.user

## ai.dev: start your orgs dev servers (but not tika or jupyter)
# note ollama-dev is not needed now that 0.5.5 is shipped
.PHONY: ai.dev
ai.dev: ollama open-webui.dev code-runner
	@echo "You cannot access this at 8081, you must access at 5174"

## whatsapp-mod: start the whatspp moderation interface
.PHONY: whatsapp-mod
whatsapp-mod:
	cd "$(WS_DIR)/git/src/app/app-saber" && \
		make install || true && \
		$(call start_server,5173,make dev)


# if ou have your own private version
## ollama.res: runs private version on 21434 (deprecated with 0.5.5)
OLLAMA_PORT_RES ?= 21434
.PHONY: ollama.res
ollama.res:
	$(call start_ollama,ollama,$(OLLAMA_PORT_RES),127.0.0.1:$(OLLAMA_PORT_RES))
	$(call check_port,$(OLLAMA_PORT_RES))

# if you have organization's dev version
# 0.5.4 build method
	# old build method
	# make -j 5 && \
	# # $(call start_ollama,./ollama,$(OLLAMA_PORT_DEV),127.0.0.1:$(OLLAMA_HOST_DEV))
## ollama.dev: runs private version on 11434 (use before 0.5.5)
# note build 0.5.5 does not support --port
OLLAMA_PORT_DEV ?= 11434
.PHONY: ollama.dev
ollama.dev:
	cd "$(WS_DIR)/git/src/sys/ollama" && \
	$(call start_ollama,go run .,$(OLLAMA_PORT_DEV),127.0.0.1:$(OLLAMA_PORT_DEV))


## exo: Start the exo LLM cluster system set EXO Home to 4TB Drive
# the cd into directory does not work you must be in that directory
# probably because asdf direnv does not pick it up
EXO_HOME ?= "/Volumes/Hagibis ASM2464PD/Exo" \
	"/Volumes/ThunderBay 8/Exo"
EXO_REPO ?= $(WS_DIR)/git/src/res/exo
# usage: $(call start_server,port of service, app, arguments...)
# bug https://stackoverflow.com/questions/61505394/make-error-gcc-make4-gcc-permission-denied-arch-linux
# exo cannot be in the path and it is the directory name of $(EXO_REPO)
# cd into a directory does not activate the .venv so need to activiate
# explicitly and call the executable
.PHONY: exo
exo:
	for exo_path in $(EXO_HOME); do \
		if [[ -e $$exo_path ]]; then \
			export EXO_HOME="$$exo_path"; break; fi; \
	done && \
	cd "$(EXO_REPO)" && source .venv/bin/activate && \
	make install && \
	$(call start_server,52415,uv run "$(EXO_REPO)/.venv/bin/exo")

OPEN_WEBUI_RES_DIR ?= $(WS_DIR)/git/src/res/open-webui
# these are the defaults work
# OPEN_WEBUI_RES_FRONTEND_PORT ?= 5173
# OPEN_WEBUI_RES_BACKEND_PORT ?= 8080
# These do not work how does the backend know where the front end is?
# used to work in older buildsA
# looks like main.py only allows 5173 or 5174 even with CORS_ALLOW_ORIGIN=*
# so ports 28080 and 25173 no longer work but these seem to
# but lower ports like 8082 work for instance
OPEN_WEBUI_RES_FRONTEND_PORT ?= 5174
OPEN_WEBUI_RES_BACKEND_PORT ?= 8084
OPEN_WEBUI_SRC_FRONTEND_RUN ?= npm install && npm run build && npm run pyodide:fetch && uv run vite dev --host --port $(OPEN_WEBUI_RES_FRONTEND_PORT)

## open-webui.res: Run local for the research group
.PHONY: open-webui.res
open-webui.res: open-webui.res.frontend open-webui.res.backend

## open-webui.res.frontend
.PHONY:  open-webui.res.frontend
open-webui.res.frontend:
	$(call start_open-webui_src_frontend,$(OPEN_WEBUI_RES_DIR),$(OPEN_WEBUI_DATA_DIR),$(OPEN_WEBUI_RES_FRONTEND_PORT),$(OPEN_WEBUI_SRC_FRONTEND_RUN))

## open-webui.res.backend: runs the backend
.PHONY: open-webui.res.backend
open-webui.res.backend:
	$(call start_open-webui_src_backend,$(OLLAMA_BASE_URL),$(OPEN_WEBUI_RES_DIR),$(OPEN_WEBUI_DATA_DIR),$(OPEN_WEBUI_RES_BACKEND_PORT))

## open-webui.user: Run local for a specific user (default on non standard frontend port 25173 and backedn 28080)
.PHONY: open-webui.user
open-webui.user:
	@echo "Make sure that you are on the right branch like rich-dev"
	@echo "Make sure you brew install asdf direnv"
	@echo "Make sure you run to right python version asdf direnv local python 3.12.7"
	@echo "Check with command -v python it points to a .venv in that directory"
	$(call start_open-webui_src,$(OLLAMA_BASE_URL),$(OPEN_WEBUI_USER_DIR),$(OPEN_WEBUI_DATA_DIR),$(OPEN_WEBUI_USER_FRONTEND_PORT),$(OPEN_WEBUI_USER_BACKEND_PORT),$(OPEN_WEBUI_SRC_FRONTEND_RUN))


OPEN_WEBUI_DEV_DIR ?= $(WS_DIR)/git/src/sys/orion/extern/open-webui
## open-webui.dev: Run local for a specific org front-end port 5174 (nonstandard) and port 8081 (nonstandard)
.PHONY: open-webui.dev
open-webui.dev: open-webui.dev.frontend open-webui.dev.backend

OPEN_WEBUI_DEV_FRONTEND_PORT ?= 5174
OPEN_WEBUI_DEV_FRONTEND_RUN ?= yarn install && yarn dev
## open-webui.dev.frontend: Run local for a specific org front-end port 5174 (nonstandard)
.PHONY: open-webui.dev.frontend
open-webui.dev.frontend:
	$(call start_open-webui_src_frontend,$(OPEN_WEBUI_DEV_DIR),$(OPEN_WEBUI_DATA_DIR),$(OPEN_WEBUI_DEV_FRONTEND_PORT),$(OPEN_WEBUI_DEV_FRONTEND_RUN))

OPEN_WEBUI_DEV_BACKEND_PORT ?= 8081
## open-webui.dev.backend: Run local for a specific org back-end port 8081 (nonstandard)
.PHONY: open-webui.dev.backend
open-webui.dev.backend:
	$(call start_open-webui_src_backend,$(OLLAMA_BASE_URL),$(OPEN_WEBUI_DEV_DIR),$(OPEN_WEBUI_DATA_DIR),$(OPEN_WEBUI_DEV_BACKEND_PORT))

CODE_RUNNER_PORT ?= 8080
CODE_RUNNER_DIR ?= $(WS_DIR)/git/src/sys/troopship/code-runner
## code-runner: Dev code-runner on port CODE_RUNNER_PORT
.PHONY: code-runner
code-runner:
	if ! lsof -i:$(CODE_RUNNER_PORT) -sTCP:LISTEN; then cd "$(CODE_RUNNER_DIR)" && \
			source .venv/bin/activate && make run; fi  &
	$(call check_port,$(CODE_RUNNER_PORT))

## orion: start the Max app Orion
.PHONY: orion
orion:
	open -a Orion.app

## ui: start the svelt user interface to port 4000
.PHONY: ui
# usage: $(call start_server,port of service, app, arguments...)
ui:
	cd "$(WS_DIR)/git/src/app/ui" && \
		$(call start_server,5172,make install && make run)

## ui.dev: start the svelte user interface to port 4000
.PHONY: ui.dev
ui.dev:
	cd $(WS_DIR)/git/src/app/ui && \
		$(call start_server,5172,make install && make run.dev)

## ngrok.dev: authentication front-end using ngrok Dev
# doing a pkill before seems to stop the run so only ai.kill does the stopping
# development port
DEV_PORT ?= 5174
# default
DEFAULT_PORT ?= 8080
# port for experimental builds
RESEARCH_PORT ?= 28080

## ngrok.dev: development port on early-lenient-goldfish.ngrok.free.app need to turn off anti-virus
.PHONY: ngrok.dev
ngrok.dev:
	$(call start_ngrok,ngrok Dev,$(DEV_PORT),early-lenient-goldfish.ngrok.free.app)

## ngrok2: SEcond default on early-lenient-goldfish.ngrok.free.app need to turn off anti-virus
.PHONY: ngrok2
ngrok2:
	$(call start_ngrok,ngrok Dev,$(DEFAULT_PORT),early-lenient-goldfish.ngrok.free.app)

## ngrok.res: Sepcial build on 28880 at organic-pegasus-solely.ngrok.free.app need to turn off anti-virus
.PHONY: ngrok.res
ngrok.res:
	$(call start_ngrok,ngrok,$(RESEARCH_PORT),organic-pegasus-solely.ngrok.free.app)

## ngrok: authentication for 8080 at organic-pegasus-solely.ngrok.free.app need to turn off anti-virus
.PHONY: ngrok
ngrok:
	$(call start_ngrok,ngrok,$(DEFAULT_PORT),organic-pegasus-solely.ngrok.free.app)
# ui.dev: start svelte and connect to developer version

## studio: create a studio repo and add to ./user with STUDIO_USER=trang make studio
# the bash variable is to get initial caps for description
# https://learnbyexample.github.io/tips/cli-tip-33/
# https://www.gnu.org/software/sed/manual/sed.html
# \b - a word boundary like a space
# \w - an entire word
# \u - take the next string and make it Initial Case
# & - The matched characters
.PHONY: studio
studio:
	gh repo view "$(GITHUB_ORG)/$(STUDIO_REPO)" &> /dev/null || \
		gh repo create -d \
			"$$(echo $(STUDIO_USER)\'s Studio | sed 's/\b\w/\u&/g')" \
			--add-readme --private "$(GITHUB_ORG)/$(STUDIO_REPO)" && \
	cd $(WS_DIR)/git/src/user && \
		git submodule | grep -q "$(STUDIO_REPO)" || \
		git submodule add git@github.com:$(GITHUB_ORG)/$(STUDIO_REPO).git

APP_PREFIX ?= app
APP_NAME ?= maria
APP_REPO ?= $(APP_PREFIX)-$(APP_NAME)
## app: APP_NAME=maria make will create app-maria and add as submodule
.PHONY: app
app:
	gh repo view "$(GITHUB_ORG)/$(APP_REPO)" &> /dev/null || \
		gh repo create -d \
			"$$(echo $(APP_NAME)\'s App | sed 's/\b\w/\u&/g')" \
			--add-readme --private "$(GITHUB_ORG)/$(APP_REPO)"
	cd $(WS_DIR)/git/src/apps && \
		git submodule | grep -q "$(APP_REPO)" || \
		git submodule add git@github.com:$(GITHUB_ORG)/$(APP_REPO).git

## studio-sync: Syncs from AWS S3 buckets for $(STUDIO_USER) to $(STUDIO_SUBMODULE_DIR) deprecated
.PHONY: studio-sync
studio-sync: auth
	aws s3 sync $(STUDIO_AWS_S3)/$(AUTH0_ID) $(STUDIO_SUBMODULE_DIR)/$(STUDIO_REPO)

## studio-ls: what is in s3 (depends on ./include.mk/auth) deprecated
.PHONY: studio-ls
studio-ls: auth
	aws s3 ls $(STUDIO_AWS_S3)/$(AUTH0_ID) --recursive --human-readable --summarize
