
##
## Python pipenv Commands (cloned from https://github.com/richtong/libi/include.pipenv.mk)
## -------------------
## ENV=pipenv to use pipenv (deprecated very slow needs include.pipenv.mk)
# requires include.mk
#
# Remember makefile *must* use tabs instead of spaces so use this vim line
#
# The makefiles are self documenting, you use two leading
# for make help to produce output
#
# These should be overridden in the makefile that includes this, but this sets
# defaults use to add comments when running make help
#
# As of September 2020, run jupyter 0.2 and this generates a pipenv error
# so ignore it
PIPENV_CHECK_FLAGS ?= --ignore 38212

## pipenv-lock: Install from the lock file (for deployment and test)
.PHONY: pipenv-lock
pipenv-lock:
	$(PIPENV) install --ignore-pipfile

# Flake8 does not handle streamlit correctly so EXCLUDE it
# Nor does pydocstyle
# If the web can pass then you can use these lines
# pipenv run flake8 --EXCLUDE $(STREAMLIT)
#	pipenv run mypy $(NO_STREAMLIT)
#	pipenv run pydocstyle --convention=google --match='(?!$(STREAMLIT))'
#
## pipenv-lint: cleans code for you
.PHONY: pipenv-lint
pipenv-lint: lint
	$(PIPENV) check $(PIPENV_CHECK_FLAGS)

## pipenv-python: Install python version in
# also add to the python path
# This fail if we don't have brew
# Note when you delete the Pipfile, it will search recursively upward
# looking for one, so on clean recreate one
# we do not explicitly clean anymore so subdirectories of a pipenv can add
# their dependencies
# the unset-% is a dynamic target from include.mk that ensure PIPENV_ACTIVE is
# set and replaces the manual
# if [[ -n $$PIPENV_ACTIVE ]]; then echo "Cannot run inside pipenv shell exit first"; exit 1; fi
# note we do an install of python@$(PYTHON) in case it is not there
# upgrade does not work
.PHONY: pipenv-python
pipenv-python: pipenv-clean unset-PIPENV_ACTIVE
	@echo "currently using python $(PYTHON) override changing PYTHON make flag"
	brew install python@$(PYTHON) pipenv
	@echo "pipenv sometimes corrupts after python $(PYTHON) install so reinstall if needed"
	$(PIPENV) --version || brew reinstall pipenv
	PIPENV_IGNORE_VIRTUALENVS=1 $(PIPENV) install --python $(PYTHON)
	@echo "use .env to ensure we can see all packages"
	grep ^PYTHONPATH .env ||  echo "PYTHONPATH=." >> .env

## pipenv-clean: cleans the pipenv completely
# note pipenv --rm will fail if there is Pipfile there so ignore that
# do not do a pipenv clean until later otherwise it creates an environment
# Same with the remove if the files are not there
# Then add a dummy pipenv so that you do not move up recursively
# And create an environment in the current directory
# we normally do not remove the Pipfile just the environment
# https://github.com/pypa/pipenv/issues/3827
# Remove caches
.PHONY: pipenv-clean
pipenv-clean: pipenv-super-clean
	touch Pipfile
	rm -rf "$$HOME/Library/Caches/pipenv"

## pipenv-super-clean: Remove the entire Pipefile environment
.PHONY: pipenv-super-clean
pipenv-super-clean:
	pipenv --rm || true
	rm Pipfile* || true
