##
## -----
## TNE.ai specific makes

DATA ?= $(WS_DIR)/data
AWS_FILES ?= s3://bp-authoring-files/d
USER_NAME ?= rich
ORG_DOMAIN ?= tne.ai
EMAIL ?= $(USER_NAME)@$(ORG_DOMAIN)
REPO ?= studio-$(USER_NAME)
REPO_URL ?= git@github.com:$(ORG)/$(REPO)
HOST_REPO ?= $(WS_DIR)/user
AUTH0_ID="$(shell auth0 users search -q email:$(EMAIL) --json | jq '.[0].identities[0].user_id')"

## auth0: what is your auth0 id
.PHONY: auth0
auth0:
	@echo $(EMAIL)
	@echo $(AUTH0_ID)

## studio-sync: Syncs from AWS S3 buckets to $(DATA)
## studio-cp
.PHONY: studio-sync
studio-sync:
	aws s3 sync $(AWS_FILES) $(DATA)

## studio-init: initializes a new repo with a specific email
# note we just pick the first entry if there are multiple
.PHONY: studio-init
studio-init:
	gh repo create --private $(REPO_URL) && \
	pushd $(HOST_REPO) && \
	git submodule add $(REPO) && \
	cp -r $(DATA)/$(AUTH0_ID) . && \
	git add -all && \
	git commit -a
