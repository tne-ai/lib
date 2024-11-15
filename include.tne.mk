##
## TNE.ai specific makes
## -----

STUDIO_SUBMODULE_DIR ?= $(WS_DIR)/git/src/user
STUDIO_AWS_S3 ?= s3://bp-authoring-files/d
STUDIO_PREFIX ?= studio
STUDIO_USER ?= demo
GITHUB_ORG ?= $(ORG)-ai
STUDIO_EMAIL_ORG ?= $(ORG).ai
STUDIO_EMAIL ?= $(STUDIO_USER)@$(STUDIO_EMAIL_ORG)
STUDIO_REPO ?= $(STUDIO_PREFIX)-$(STUDIO_USER)
STUDIO_REPO_URL ?= git@github.com:$(ORG)/$(STUDIO_REPO)
# note that the shell is evaluated before the target even starts so you need
# https://auth0.github.io/auth0-cli/
# auth0 login before you can run this line so run a command which authenticates
# we need this dependency because the AUTH0_ID shell script needs a login first
# and we do not want to see the junk from tenants list as there is no way to
# query auth0 to see if you are logged in from the cli
AUTH0_ID=$(shell auth0 users search -q email:$(STUDIO_EMAIL) --json | jq '.[0].identities[0].user_id')

## auth0-id: what is your auth0 id for your $(STUDIO_EMAIL)
.PHONY: auth0-id
auth0-id:
	@echo Looking Auth0 for: $(STUDIO_EMAIL)
	@echo Found Auth0 id: $(AUTH0_ID)

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


## studio-sync: Syncs from AWS S3 buckets for $(STUDIO_USER) to $(STUDIO_SUBMODULE_DIR) deprecated
.PHONY: studio-sync
studio-sync: auth
	aws s3 sync $(STUDIO_AWS_S3)/$(AUTH0_ID) $(STUDIO_SUBMODULE_DIR)/$(STUDIO_REPO)

## studio-ls: what is in s3 (depends on ./include.mk/auth) deprecated
.PHONY: studio-ls
studio-ls: auth
	aws s3 ls $(STUDIO_AWS_S3)/$(AUTH0_ID) --recursive --human-readable --summarize

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
