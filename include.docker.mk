##
## Docker command v2 uses docker-compose if docker_compose.yaml exists
## -------
# Remember makefile *must* use tabs instead of spaces so use this vim line
# requires include.mk
#
# The makefiles are self documenting, you use two leading for make help to produce output


## Change REPO and DOCKER_REGISTRY
# Github Repo - Preferred
DOCKER_REGISTRY ?= ghcr.io
REPO ?= richtong
REPO_USER ?= richtong
# docker.io - Docker Hub deprecated
#DOCKER_REGISTRY ?= docker.io
# Container registry user name
# REPO_USER ?= richt
# Google Repo - Not free
#DOCKER_REGISTRY ?= gcr.io
#REPO ?= not-set
# public.ecr.aws - Amazon public container registry
# DOCKER_REGISTRY ?= public.ecr.aws
# REPO ?= not-set


# https://stackoverflow.com/questions/10024279/how-to-use-shell-commands-in-makefile
# Cannot use ?= because we want the shell to evaluate at make time
ifndef NAME
# this is the short form of the longer form below
#NAME := $(shell basename $(PWD))
NAME != basename $(PWD)
endif

# the new multiarch builder
DOCKER_BUILD ?= buildx
# the old style builder
# DOCKER_BUILD ?= docker

IMAGE ?= $(DOCKER_REGISTRY)/$(REPO)/$(NAME)
# build 64-bit arm for M1 Mac and AMD64 for Intel machines
# syntax is for the buildx multiarch builder
# https://docs.docker.com/buildx/working-with-buildx/
# use ARG TARGETPLATFORM in Dockerfile to do differential builds
ARCH ?= linux/arm64,linux/amd64

# You should note need the architecture since docker works with both intel and
# m1 on Apple Silicon but by default we build both M1 and Intel
ARCH ?=$(shell uname -m)
#
# Use the git commit by default
VERSION ?= $(shell git rev-parse HEAD)

SHELL := /usr/bin/env bash
DOCKER_USER ?= docker
HOST_DIR ?= ./data
# https://stackoverflow.com/questions/18136918/how-to-get-current-relative-directory-of-your-makefile
CONTAINER_DIR ?= /var/data
# -v is deprecated
# VOLUMES ?= -v "$$(readlink -f "./data"):$(HOST_DIR)"
VOLUMES ?= --mount "type=bind,source=$(shell readlink -f "$(HOST_DIR)"),target=$(CONTAINER_DIR)"

# no flags by default
FLAGS ?=
DOCKERFILE ?= Dockerfile

# option combinations are
#
# Set the docker type
DOCKER_TYPE ?= docker
# docker, docker - docker cli using Docker.app (tested works)
ifeq ($(DOCKER_TYPE),docker)
DOCKER ?= docker
DOCKER_RUNTIME ?= $(DOCKER)
DOCKER_CONTEXT ?= default
endif
ifeq ($(DOCKER_TYPE),docker-colima)
#
# docker, colima - docker cli using colima with docker runtime (tested works)
# make sure the context is set to point to the right socket
DOCKER ?= docker
DOCKER_RUNTIME ?= colima
DOCKER_CONTENT ?= colima
ifneq ($(findstring amd64,$(ARCH)),)
# uncomment for cross platform amd64 images
COLIMA_ARCH_FLAG ?= --arch x86_64
endif
ifeq ($(findstring arm64,$(ARCH)),)
# uncomment for cross platform arm64 images
COLIMA_ARCH_FLAG ?= --arch aarch64
endif
endif
# colima nerdctl, colima - colima nerdctl using colima containerd
# (tested works,
# does not support build --pull)
#
ifeq ($(DOCKER_TYPE),colima-nerdctl)
DOCKER ?= colima nerdctl
DOCKER_RUNTIME ?= colima
DOCKER_CONTENT ?= colima
endif
#
# As of Jan 2022
# NordVPN not running at docker-start time but docker hub access not working)
# lima nerdctl, lima - lima nerdctl using lima containerd (test works if
#
ifeq ($(DOCKER_TYPE),lima-nerdctl)
DOCKER ?= lima nerdctl
DOCKER_RUNTIME ?= limactl
endif
#
# podman, podman - podman cli using podman (does not work no way to mount host volumes)
# As of Dec 2021 there is no support for host volume mounts with podman so
# only use it if you do not need local files
# https://github.com/containers/podman/issues/8016
ifeq ($(DOCKER_TYPE),podman)
DOCKER ?= podman
DOCKER_RUNTIME ?= $(DOCKER)
endif

DOCKER_MACHINE_NAME ?= podman-machine-default
# podman-compose does not support --env-file
#DOCKER_COMPOSE ?= podman-compose
# use docker compose with the right socket to podman
# https://gist.github.com/kaaquist/dab64aeb52a815b935b11c86202761a3
# https://stackoverflow.com/questions/63319824/how-to-add-contains-or-startswith-in-jq
#jq '.[] | select(.Name | startswith("$(DOCKER_MACHINE_NAME)")) | .URI')";
# use asterisk to indicate default
# jq -r to remove quotes
DOCKER_SOCKET ?= if [[ "$(DOCKER)" =~ podman && ! -r /tmp/podman.socket ]]; then \
		URI="$$($(DOCKER) system connection list --format=json  | \
			jq -r '.[] | select(.Name=="$(DOCKER_MACHINE_NAME)*") | .URI')"; \
		echo $$URI; \
		echo /tmp/podman.sock:/"$$(echo $$URI | cut -d/ -f 4-)";  \
		echo "$$(echo $$URI| cut -d/ -f 1-3)";  \
		ssh -fnNT -L /tmp/podman.sock:/"$$(echo $$URI | cut -d/ -f 4-)" \
			-i "$$HOME/.ssh/$(DOCKER_MACHINE_NAME)" \
			"$$(echo $$URI| cut -d/ -f 1-3)" \
			-o StreamLocalBindUnlink=yes; \
		export DOCKER_HOST="unix:///tmp/podman.sock"; \
	fi
DOCKER_COMPOSE ?= $(DOCKER_SOCKET) && $(DOCKER) compose
DOCKER_COMPOSE_YML ?= docker-compose.yml
# The real docker
#DOCKER ?= docker
#DOCKER_COMPOSE ?= docker compose

CONTAINER := $(NAME)
BUILD_PATH ?= .
MAIN ?= $(NAME).py
DOCKER_ENV ?= docker
CONDA_ENV ?= $(NAME)

# https://github.com/moby/moby/issues/7281

# pip packages that can also be installed by conda
PIP ?=
# pip packages that cannot be conda installed
PIP_ONLY ?=

# assuming one keep the input open like docker -it
STDIN_OPEN ?= true
TTY ?= true

# need the right UID for correct volume permissions
# currently breaks px4 with invalide user id
#LOCAL_USER_ID ?= $(shell echo $$UID)
HOST_UID ?= $(shell id -u)
HOST_GID ?= $(shell id -g)
# get the IP container address
CONTAINER_IP=$$($(DOCKER) container inspect -f '{{ $$net := index .NetworkSettings.Networks "$(NAME)_default" }}{{ $$net.IPAddress }}' $(NAME)_main_1)
HOST_IP=$(shell ipconfig getifaddr en0)
# more complex
#HOST_IP=$(shell ifconfig en0 | grep "inet " | cut -d ' ' -f 2)
EXPORTS ?= HOST_UID="$(HOST_UID)" HOST_GID="$(HOST_GID)" HOST_IP="$(HOST_IP)" IMAGE="$(IMAGE)"

## xhost: Run docker with xhost on
# https://github.com/moby/moby/issues/35886
# Cannot use single quotes in the -f filter because $(name) is itself a shell
# command so use backslashes instead
# In the IP setting not there should be no space between the two handlebars
# https://lmiller1990.github.io/electic/posts/20201119_cypress_and_x11_in_docker.html
# http://mamykin.com/posts/running-x-apps-on-mac-with-docker/
# https://stackoverflow.com/questions/38686932/how-to-forward-docker-for-mac-to-x11
# not sure which ones to add so add all of them
# Note that ifconfig and HOSTNAME point to the same DNS so you don't need both
# but do both in case that is incorrect
.PHONY: xhost
xhost:
	@echo "On MacOS install XQuartz and enable Preferences > Security > Allow connects from network clients"
	xhost "+$$HOSTNAME"
	xhost "+$(ifconfig getifaddre en0)"
	xhose "+localhost"

DOCKER_ENV_FILE ?= docker-compose.env

# these are only for docker build (deprecated use docker compose and DOCKER_ENV_FILE instead)
BUILD_FLAGS ?= --build-arg "DOCKER_USER=$(DOCKER_USER)" \
				--build-arg "HOST_DIR=$(HOST_DIR)" \
				--build-arg "NB_USER=$(DOCKER_USER)" \
				--build-arg "ENV=$(DOCKER_ENV)" \
				--build-arg "PYTHON=$(PYTHON)" \
				--build-arg "PIP=$(PIP)" \
				--build-arg "PIP_ONLY=$(PIP_ONLY)" \
				--build-arg "STDIN_OPEN=$(STDIN_OPEN)" \
				--build-arg "TTY=$(TTY)"

# Guess the name of the main container is called main
DOCKER_COMPOSE_MAIN ?= main

## docker-login: login to the container registry works for docker hub only
.PHONY: docker-login
docker-login: docker-start
	echo $(DOCKER_TOKEN) | docker login "$(DOCKER_REGISTRY)" -u $(DOCKER_USER) --password-stdin

## docker-start: make sure docker is running (Mac only)
# now podman aware so only checks if you want docker
# and if podman then connect docker compose to it
# https://www.redhat.com/sysadmin/podman-docker-compose
# note that podman machine ls | grep -v does not work
.PHONY: docker-start
docker-start:
	docker context use "$(DOCKER_CONTEXT)" && \
	if [[ "$(DOCKER_RUNTIME)" =~ docker ]] && ! "$(DOCKER)" ps &>/dev/null; then \
		open -a "$(DOCKER)" && sleep 60; \
	elif [[ "$(DOCKER_RUNTIME)" =~ colima ]]; then \
		if [[ "$(DOCKER)" =~ nerdctl ]]; then \
			FLAG="--runtime containerd"; \
		fi; \
		if ! colima status &> /dev/null; then \
			colima start $$FLAG --cpu 2 --memory 8 --disk 100 $(COLIMA_ARCH_FLAG); \
		fi; \
	elif [[ "$(DOCKER_RUNTIME)" =~ limactl ]]; then \
		if [[ ! $$(limactl list -f "{{.Status}}" default) =~ Running ]]; then \
			limactl start; \
			lima sudo systemctl start containerd; \
			lima sudo nerdctl run --privileged --rm tonistiigi/binfmt --install all; \
		fi; \
		if [[ ! $$(lima nerdctl login) =~ "Login Succeeded" ]]; then \
			lima nerdctl login --username "$(REPO_USER)"; \
		fi; \
	elif [[ "$(DOCKER_RUNTIME)" =~ podman ]]; then \
		if ! $(DOCKER_RUNTIME) machine list --format={{.Name}} | \
					grep -q "$(DOCKER_MACHINE_NAME)"; then \
				$(DOCKER_RUNTIME) machine init --cpus=2 --disk-size=100 --memory=4096; \
			fi; \
		if $(DOCKER_RUNTIME) machine list --format "{{.Name}}" | \
					grep -q "$(DOCKER_MACHINE_NAME)" && \
				$(DOCKER_RUNTIME) machine list --format "{{.LastUp}}" | \
					grep -qv "Currently running"; then \
						echo $(DOCKER_RUNTIME) machine start; \
						$(DOCKER_RUNTIME) machine start; \
		fi; \
	fi

## docker-stop: stop the docker/podman runtimes
# https://stackoverflow.com/questions/55100327/how-to-open-and-close-apps-using-bash-in-macos
.PHONY: docker-stop
docker-stop:
	if [[ "$(DOCKER)" =~ docker ]] && $(DOCKER) ps &>/dev/null; then \
		osascript -e 'quit app "Docker"'; \
	fi; \
	if [[ "$(DOCKER)" =~ podman && $$($(DOCKER) machine list --format={{.LastUp}}) =~ "Currently running" ]]; then \
		$(DOCKER) machine stop; \
	fi

## build: build arm64 and amd64 images (push separately) from single Dockerfile
# LOCAL_USER_ID=$(LOCAL_USER_ID)
# https://docs.podman.io/en/latest/markdown/podman-system-connection-list.1.html
# https://sdeoras.medium.com/special-case-of-building-multi-arch-container-images-distroless-go-and-podman-ad3e2ba0ccea
# note that nerdctl compose build does not support --pull which docker compose
# does
		#$(DOCKER) manifest create "$(IMAGE):$(VERSION)"; \
.PHONY: build
# https://github.com/abiosoft/colima/issues/44 to use buildx with colima
# note in docker buildx we cannot have to push here because --load does not work with multi-arch manifests
# it does not know how to export the manifest
build: docker-start
	export $(EXPORTS) && \
	if [[ -r  "$(DOCKER_COMPOSE_YML)" ]]; then \
		$(DOCKER_COMPOSE) --env-file "${DOCKER_ENV_FILE}" -f "$(DOCKER_COMPOSE_YML)" build; \
	elif [[ $(DOCKER_BUILD) =~ buildx ]]; then \
		if [[ $(DOCKER) =~ colima ]]; then \
			if ! docker buildx | grep -q "$(DOCKER)"; then \
				docker buildx create --name "$(DOCKER)"; \
			fi; \
			docker buildx use "$(DOCKER)"; \
		fi; \
		docker buildx build --push --progress auto \
			--platform $(ARCH) -t "$(IMAGE):$(VERSION)" $(BUILD_FLAGS) \
			-f "$(DOCKERFILE)" $(BUILD_PATH); \
	else \
		for arch in $(ARCH); do \
			$(DOCKER) build --platform $$arch --pull \
						$(FLAGS) \
						 -f "$(DOCKERFILE)" \
						 -t "$(IMAGE):$(VERSION).$$arch" \
						 $(BUILD_PATH); \
		    $(DOCKER) manifest add "$(IMAGE):$(VERSION)" "$(IMAGE):$(VERSION).$$arch"; \
		done; \
	fi

## build-debug: run buildx in full debug mode with large log in plain progress
.PHONY: build-debug
build-debug: context-debug build context-default

## context-debug: create a build context with large 100MBlog
.PHONY: context-debug
build-log:
	if ! docker buildx ls | grep -q "^$(NAME)-debug"; then \
		docker buildx create --name "$(NAME)-debug" --driver-opt \
			env.BUILDKIT_STEP_LOG_MAX_SIZE=100000000; \
	fi && \
	docker buildx use "$(NAME)-debug"

## context-default: switch to default build context
.PHONY: context-default
context-default:
	docker buildx use default

## docker-lint: run the linter against the docker file (for podman requires socket connect)
# LOCAL_USER_ID=$(LOCAL_USER_ID)
.PHONY: docker-lint
docker-lint: $(DOCKERFILE) docker-start
	export $(EXPORTS) && \
	if [[ -r  "$(DOCKER_COMPOSE_YML)" ]]; then \
		$(DOCKER_COMPOSE) --env-file "$(DOCKER_ENV_FILE)" -f "$(DOCKER_COMPOSE_YML)" config; \
	else \
		dockerfilelint $(DOCKERFILE); \
	fi

## docker-test: run tests for pip file
.PHONY: dockertest
docker-test: docker-start
	@echo PIP=$(PIP)
	@echo PIP_ONLY=$(PIP_ONLY)
	@echo PYTHON=$(PYTHON)

## push: after a build will push the image up
# note that with dockerx buildx push there is not --all-tags so only the $(VERSION) tag is pushed
# and that you needs latest explicitly set
# https://stackoverflow.com/questions/21928780/create-multiple-tag-docker-image
# and you need the image name in your docker compose
.PHONY: push
push: build
	# need to push and pull to make sure the entire cluster has the right images
	export $(EXPORTS) && \
	if [[ -r  "$(DOCKER_COMPOSE_YML)" ]]; then \
		$(DOCKER_COMPOSE) --env-file "$(DOCKER_ENV_FILE)" -f "$(DOCKER_COMPOSE_YML)" push; \
	else \
		$(DOCKER) tag "$(IMAGE):$(VERSION)" "$(IMAGE):latest" && \
		$(DOCKER) push --all-tags $(IMAGE) \
	fi

# for those times when we make a change in but the Dockerfile does not notice
# In the no cache case do not pull as this will give you stale layers
## no-cache: build docker image with no cache
.PHONY: no-cache
no-cache: $(DOCKERFILE) docker-start
	export $(EXPORTS) && \
	if [[ -r  "$(DOCKER_COMPOSE_YML)" ]]; then \
		# LOCAL_USER_ID=$(LOCAL_USER_ID) \
		$(DOCKER_COMPOSE) --env-file "$(DOCKER_ENV_FILE)" -f "$(DOCKER_COMPOSE_YML)" build \
			--build-arg NB_USER=$(DOCKER_USER); \
	else \
		$(DOCKER) build --pull --no-cache \
			$(BUILD_FLAGS) \
			--build-arg NB_USER=$(DOCKER_USER) -f $(Dockerfile) -t $(IMAGE) $(BUILD_PATH); \
		$(DOCKER) push $(IMAGE); \
	fi

# bash -c means the first argument is run and then the next are set as the $1,
# to it and not that you use awk with the \$ in double quotes
FOR_CONTAINERS := bash -c 'for container in $$($(DOCKER) ps -a --format {{.Names}} --filter name="$(NAME)"); \
						  do \
						  	$(DOCKER) $$0 "$$container" $$*; \
						  done'

# we use https://stackoverflow.com/questions/12426659/how-to-extract-last-part-of-string-in-bash
# Because of quoting issues with awk
# this command needs the container name as the first argument
DOCKER_RUN := bash -c '\
	export $(EXPORTS) && \
	last=$$($(DOCKER) ps --format "{{.Names}}" --filter name=$(NAME) | rev | tr - _ | cut -d "_" -f 1 | sort -r | head -n1) && \
	$(DOCKER) run \
		--name $(CONTAINER)_$$((last+1)) \
		$(VOLUMES) $(FLAGS) \
		$$0 $$* \
		"$(IMAGE)"'

## stop: halts all running containers (deprecated)
.PHONY: stop
stop: docker-start
	export $(EXPORTS) && \
	if [[ -r  "$(DOCKER_COMPOSE_YML)" ]]; then \
		$(DOCKER_COMPOSE) --env-file "${DOCKER_ENV_FILE}" -f "$(DOCKER_COMPOSE_YML)" down \
	; else \
		$(FOR_CONTAINERS) stop > /dev/null && \
		$(FOR_CONTAINERS) "rm -v" > /dev/null \
	; fi

## pull: pulls the latest image
.PHONY: pull
pull: docker-start
	export $(EXPORTS) && \
	if [[ -r  "$(DOCKER_COMPOSE_YML)" ]]; then \
		$(DOCKER_COMPOSE) --env-file "$(DOCKER_ENV_FILE)" -f "$(DOCKER_COMPOSE_YML)" pull; \
	else \
		$(DOCKER) pull $(IMAGE); \
	fi

# run [args]: stops all the containers and then runs in the background
#             if there are flags than to a make -- run --flags [args]
# https://stackoverflow.com/questions/2214575/passing-arguments-to-make-run
# Hack to allow parameters after run only works with GNU make
# Note no indents allowed for ifeq
# This commented out does not work if MAKECMDGOALS
# include real targets like 'run'
#ifeq (exec,$(firstword $(MAKECMDGOALS)))
## use the rest of the goals as arguments
#RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)), $(MAKECMDGOALS))
## and create phantom targets for all those args
#$(eval $(RUN_ARGS):;@:)
#endif
# https://stackoverflow.com/questions/30137135/confused-about-docker-t-option-to-allocate-a-pseudo-tty
# docker run flags
# -i interactive connects the docker stdin to the terminal stdin
#    to exit the container send a CTRL-D to the stdin. This is used to run
#    and then exit like a shell command
# -t terminal means that the input is a terminal (and is useless without -i)
# -it this is almost always used together. commands like ls treat things
#     differently if they are not readl terminals so this works like a shell
# -dt runs but connects the stdin and stdout so logging works
#
# https://www.tecmint.com/run-docker-container-in-background-detached-mode/
# -d run in detached mode so it runs in the background and output goes
#    to the terminal if -t is set or it goes to the log otherwise
#  docker attach will reconnect it to the foreground.
# -rm remove the container when it exits


## run: Run the docker container in the background (for web apps like Jupyter)
# we show the log after 5 second so you can see things like the security token
# needs. the Host IP has to be passed in as it changes dynamically
# and the .env file is static
# Note we need the logs for things like jupyterlab where the access token is in
# the log but need to wait for it to start up to get the it
.PHONY: run
run: stop docker-start
	export $(EXPORTS) && \
	if [[ -r  "$(DOCKER_COMPOSE_YML)" ]]; then \
		$(DOCKER_COMPOSE) --env-file "$(DOCKER_ENV_FILE)" -f "$(DOCKER_COMPOSE_YML)" up -d  && \
		sleep 5 && \
		$(DOCKER_COMPOSE) --env-file "$(DOCKER_ENV_FILE)" logs \
	; else \
		$(DOCKER_RUN) -dt && \
		sleep 10 && \
		$(FOR_CONTAINERS) logs \
	; fi


# https://gist.github.com/mitchwongho/11266726
# Need entrypoint to make sure we get something interactive
# LOCAL_USER_ID=$(LOCAL_USER_ID) \
# The need for the host IP is to allow X-Windows support
# which allows openGL acceleration to the outer system
# For security there is a cookie stored in .Xauthority and the hostname has to
# resolve to the HOST IP. The cookie is opaque, but you can see the hostname
# on a Mac this is usually the HOSTNAME
	#export HOST_IP=$(HOST_IP) HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) && \
## shell: start and new container and run the interactive shell
.PHONY: shell
shell: docker-start
	export $(EXPORTS) && \
	if [[ -r  "$(DOCKER_COMPOSE_YML)" ]]; then \
		$(DOCKER_COMPOSE) --env-file "$(DOCKER_ENV_FILE)" -f "$(DOCKER_COMPOSE_YML)" run "$(DOCKER_COMPOSE_MAIN)" /bin/bash \
	; else \
		$(DOCKER) pull $(IMAGE) && $(DOCKER_RUN) -it --rm --entrypoint /bin/bash \
	; fi

## exec: Run docker in foreground and then exit (treat like any Unix command)
##       if you need to pass arguments down then use the form
# note no --re needed we automaticaly do this and need for logs
#
.PHONY: exec
# exec: stop docker-start
exec:
	export $(EXPORTS) && \
	if [[ -r  "$(DOCKER_COMPOSE_YML)" ]]; then \
		export LOCAL_USER_ID=$(LOCAL_USER_ID) && \
		$(DOCKER_COMPOSE) --env-file "$(DOCKER_ENV_FILE)" -f "$(DOCKER_COMPOSE_YML)" up \
	; else \
		$(DOCKER_RUN) -t \
	; fi

## resume: keep running an existing container
.PHONY: resume
resume: docker-start
	export $(EXPORTS) && \
	if [[ -r  "$(DOCKER_COMPOSE_YML)" ]]; then \
		$(DOCKER_COMPOSE) --env-file "$(DOCKER_ENV_FILE)" start; \
	else \
		$(DOCKER) start -ai $(container) \
	; fi

# Note we say only the type file because otherwise it tries to delete $(docker_data) itself
## prune: Save some space on docker
.PHONY: prune
prune: docker-start
	$(DOCKER) system prune --volumes
