##
## Python Commands (cloned from https://github.com/richtong/libi/include.python.mk)
## -------------------
## PYTHON_ENV=uv to use Astral uv (per project preferred)
## PYTHON_ENV=conda to use when binaries needed like tf (not per project)
## PYTHON_ENV=poetry to use poetry (can be used, but uv faster)
## PYTHON_ENV=pipenv to use pipenv (deprecated very slow needs include.pipenv.mk)
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
# https://frostming.com/2019/01-04/pipenv-poetry/
# Supports 	Pipenv (deprecated it is slow and dependency problems)
# 			Pip to the system environment (deprecated with project conflicts)
# 			Conda (deprecated this is a single shared environment)
# 			Poetry (in development, like pipenv but faster)
#
FLAGS ?=
SHELL := /usr/bin/env bash

# does not work the EXCLUDEd directories are still listed
# https://www.theunixschool.com/2012/07/find-command-15-examples-to-EXCLUDE.html
# EXCLUDE := -type d \( -name extern -o -name .git \) -prune -o
# https://stackoverflow.com/questions/4210042/how-to-EXCLUDE-a-directory-in-find-command
EXCLUDE := -not \( -path "./extern/*" -o -path "./.git/*" \)
ALL_PY := $$(find . -name "*.py" $(EXCLUDE) )
ALL_YAML := $$(find . -name "*.yaml" $(EXCLUDE))
# gitpod needs three digits so this will fail
PYTHON ?= 3.11
PYTHON_MINOR ?= $(PYTHON).8
DOC ?= doc
LIB ?= lib
NAME ?= $(notdir $(PWD))
# put a python file here or the module name it also looks in ./bin
# https://www.gnu.org/software/make/manual/html_node/Wildcard-Function.html
# https://www.gnu.org/software/make/manual/html_node/Conditional-Functions.html#Conditional-Functions
MAIN ?= $(or $(wildcard $(NAME).py)$(wildcard bin/$(NAME).py),$(realpath $(NAME).py bin/$(NAME).py))
MAIN_PATH ?= .

# should really be an environment variable
TEST_PYPI_USERNAME ?= $$TEST_PYPI_USERNAME

# this is not yet a module so no name
IS_MODULE ?= False
ifeq ($(IS_MODULE),True)
	MODULE ?= -m $(MAIN)
else
	MODULE ?= $(MAIN)
endif

STREAMLIT ?= $(MAIN)

# these packages are used during runtime of python proram
PIP +=

# These cannot be installed in the environment must use pip install
# build, twine and setuptools for PIP packaging only but install since
# most of what we do will end up packaged
# black > 22.12 for security
# mkdocs, mkdocs-material, pymdown-extensions, fontawesome for static documentation
# kfp - Kubeflow Pipeline CLI need --pre
#
# PIP_PRE are pre-development or non stable versions used by pipenv
#
PIP_PRE +=

# PIP_ONLY for packages that do not conda install as conda has a limited repo
PIP_ONLY +=

# "black>=22.12"  # python formatter. ruff deprecated \
# flake8   # python linter ruff deprecates\
# seed-isort-config   # deprecated by ruff \
# "isort>=5.10.1"  # deprecated to ruff \
# pydocstyle  # deprecated to ruff\
# bandit   # deprecated to ruff\
# beautysh  # deprecated by shfmt

# if you want everything
# PIP_PURPOSE ?= PIP_BASE PIP_DEV
# base tools needed for documentation for any repo
PIP_DEV_BASE += \
		neovim \
		fontawesome-markdown \
		mkdocs \
		mkdocs-material \
		"mkdocstrings[python]" \
		mkdocs-git-committers-plugin \
		mkdocs-charts-plugin \
		mkdocs-redirects \
		mkdocs-git-authors-plugin \
		mkdocs-minify-plugin \
		mkdocs-monorepo-plugin \
		mkdocs-awesome-pages-plugin \
		mkdocs-jupyter \
		mkdocs-git-revision-date-localized-plugin \
		markdown-exec \
		mkdocs-enumerate-headings-plugin


# development tools if you are writing python
PIP_DEV_TOOLS += \
		mypy \
		pdoc3 \
		pre-commit \
		pymdown-extensions \
		ruff \
		yamllint

# if you are packaging for pypi
PIP_DEV_PACKAGER += \
		build \
		setuptools \
		twine \
		wheel


# decides what packages to install default is just the base
PIP_DEV ?= $(PIP_DEV_BASE)
# runtime packages needed for python for python development
# PIP ?= $(PIP_DEV_BASE) $(PIP_DEV_TOOLS)
# packages for python development of a pypi package
# PIP ?= $(PIP_DEV_BASE) $(PIP_DEV_TOOLS) $(PIP_DEV_PACKAGER)

# default conda channels
CONDA_CHANNEL ?= conda-forge
# conda only packages
CONDA_ONLY ?=

# https://stackoverflow.com/questions/589276/how-can-i-use-bash-syntax-in-makefile-targets
# The virtual environment [ poetry | pipenv | conda | uv | none ]
REQUIREMENTS_TXT ?= requirements.txt
PYTHON_ENV ?= uv
RUN ?=
INIT ?=
ACTIVATE ?=
UPDATE ?=
INSTALL ?=
INSTALL_DEV ?= $(INSTALL)
MACOS_VERSION ?= $(shell sw_vers -productVersion)
ARCH ?= $(shell uname -m)
# due to https://github.com/pypa/pipenv/issues/4564
# pipenv does not correctly deal with MacOS 11 and above so run in
# compatibility mode as of Sept 2021
# hopefully we can turn this off eventually
# https://github.com/numpy/numpy/issues/17784
# https://github.com/pypa/packaging/pull/319
# These may have been fixed
#
# only need the compat for the switch from 10.x to 11.x with Big Sur
#PIPENV := SYSTEM_VERSION_COMPAT=1 pipenv
# Use this Monterey as the version compat is fixed
# conditional dependency https://stackoverflow.com/questions/59867140/conditional-dependencies-in-gnu-make
# install h5py right after the clean
#
# uv from Astral is way faster than poetry  and also create venv
ifeq ($(PYTHON_ENV),uv)
	INIT := uv init
	RUN := uv run
	INSTALL := uv add
	INSTALL_PRE := $(INSTALL)
	INSTALL_DEV := $(INSTALL) --dev
	INSTALL_PIP_ONLY := $(INSTALL)
	INSTALL_REQ :=
	INSTALL_LOCK := uv lock
	INSTALL_UPGRADE := $(INSTALL_LOCK) --upgrade
	INSTALL_REQUIREMENTS := [[ -e $(REQUIREMENTS_TXT) ]] && uv pip install -r requirements.txt
	EXPORT_REQUIREMENTS := uv export --format $(REQUIREMENTS_TXT) > requirements.txt
	ENV_CREATE := uv venv --python $(PYTHON)
	ENV_REMOVE := uv remove
	ENV_CURRENT := uv list
	ENV_RUN := uv run
	ENV_ACTIVATE :=  source .venv/bin/activate
	ENV_DEACTIVATE := deactivate | true
# Note that poetry init is an interactive creation of pyproject.toml which you
# usually do not want but is included here. You need to manually add the python
# version requirement in the poetry section such as python = "^3.10"
else ifeq ($(PYTHON_ENV),poetry)
	# no longer expoert to $(REQUIREMENTS_TXT) it just causes lots of dependabot
	# problems, so only do export explicitly usually for mkdocs in netlify
	# INIT := poetry install && $(EXPORT)
	# UPDATE := poetry update && $(EXPORT)
	INIT := poetry install
	UPDATE := poetry update
	RUN := poetry run
	INSTALL := poetry add
	INSTALL_PRE := $(INSTALL)
	INSTALL_DEV := $(INSTALL)
	INSTALL_PIP_ONLY := $(INSTALL)
	INSTALL_REQ :=
	# no explicit lock needed
	INSTALL_LOCK := poetry lock
	INSTALL_UPGRADE := poetry upgrade
	# https://stackoverflow.com/questions/62764148/how-to-import-an-existing-$(REQUIREMENTS_TXT)-into-a-poetry-project
	# https://timonweb.com/python/how-to-import-requirementstxt-into-poetry/
	INSTALL_REQUIREMENTS := [[ -e $(REQUIREMENTS_TXT) ]] && $(INSTALL) $(cat requirements.txt)
	EXPORT_REQUIREMENTS := poetry export --format $(REQUIREMENTS_TXT) --without-hashes -o requirements.txt
	# environment creation is implicit and in the $(CWD)
	ENV_CREATE :=
	ENV_REMOVE := poetry env remove
	ENV_CURRENT := poetry env list
	ENV_RUN := poetry run
	ENV_ACTIVATE := poetry shell
	ENV_DEACTIVATE := exit
else ifeq ($(PYTHON_ENV),pipenv)
	PIPENV := pipenv
	RUN := $(PIPENV) run
	UPDATE := $(PIPENV) update
	INSTALL := $(PIPENV) install
	INSTALL_PRE := $(PIPENV) install --pre
	INSTALL_DEV := $(INSTALL) --dev --pre
	INSTALL_PIP_ONLY := $(INSTALL)
	ENV_CREATE :=
	INSTALL_REQ := pipenv-python $(if $(strip $(INSTALL_H5PY)),install-h5py)
	INSTALL_LOCK := pipenv lock
	INSTALL_UPGRADE := pipenv update
	# https://realpython.com/pipenv-guide/
	# pipenv autodetects $(REQUIREMENTS_TXT) and uses it
	INSTALL_REQUIREMENTS := [[ -e $(REQUIREMENTS_TXT) ]] && $(INSTALL)
	EXPORT_REQUIREMENTS := pipenv lock -r > $(REQUIREMENTS_TXT)
	ENV_REMOVE := pipenv --rm
	ENV_CURRENT := pipenv --venv
	ENV_RUN := pipenv run
	ENV_ACTIVATE := pipenv shell
	ENV_DEACTIVATE := exit
else ifeq ($(PYTHON_ENV),conda)
	RUN := conda run -n $(NAME)
	INIT := eval "$$(conda shell.bash hook)"
	ACTIVATE := $(INIT) && conda activate $(NAME)
	UPDATE := conda update --all -y
	INSTALL := conda install -y -n $(NAME)
	INSTALL_PRE := $(RUN) pip install --pre
	INSTALL_DEV := $(INSTALL)
	INSTALL_PIP_ONLY := $(RUN) pip install
	INSTALL_REQ = conda-clean
	# requires conda-lock installation so use the native instead
	# INSTALL_LOCK := conda-lock
	INSTALL_LOCK i:= $(ACTIVATE) && conda env export > environment.yml
	INSTALL_UPGRADE := conda update --all
	INSTALL_REQUIREMENTS := [[ -e $(REQUIREMENTS_TXT) ]] && $(INSTALL) --file requirements.txt
	# https://stackoverflow.com/questions/50777849/from-conda-create-$(REQUIREMENTS_TXT)-for-pip3
	EXPORT_REQUIREMENTS := $(ACTIVATE) && conda install pip && pip freeze > $(REQUIREMENTS_TXT)
	CONDA_NAME := $(CURDIR)
	ENV_CREATE := conda create -n $(CONDA_NAME) -y
	ENV_UNINSTALL := conda env remove --name $(CONDA_NAME)
	ENV_CURRENT := conda env list
	ENV_RUN := conda run -n $(CONDA_NAME)
	ENV_ACTIVATE := conda activate $(CONDA_NAME)
	ENV_DEACTIVATE := conda deactivate
else ifeq ($(PYTHON_ENV),none)
	RUN :=
	ACTIVATE :=
	# need a noop as this is not a modifier
	# https://stackoverflow.com/questions/12404661/what-is-the-use-case-of-noop-in-bash
	UPDATE := :
	INSTALL := pip install
	INSTALL_DEV := $(INSTALL)
	INSTALL_PRE := $(INSTALL) --pre
	INSTALL_PIP_ONLY := $(INSTALL)
	INSTALL_REQ := $(if $(strip $(INSTALL_H5PY)),install-h5py)
	INSTALL_LOCK := $(RUN) pip freeze > $(REQUIREMENTS_TXT)
	# creating $(REQUIREMENTS_TXT) is a size effect of a freeze
	INSTALL_REQUIREMENTS := [[ -e $(REQUIREMENTS_TXT) ]] && $(INSTALL) -r requirements.txt
	EXPORT_REQUIREMENTS := $(INSTALL_LOCK)
	ENV_UNINSTALL :=
	ENV_CURRENT :=
	ENV_RUN :=
	ENV_ACTIVATE :=
	ENV_DEACTIVATE :=
endif

## main: run the main program
.PHONY: main
main:
	@echo $(PYTHON_ENV)
	$(RUN) python $(MODULE) $(FLAGS)

## pdb: run locally with python to test components from main
.PHONY: pdb
pdb:
	$(RUN) python -m pdb $(MODULE) $(FLAGS)

## debug: run with debug model on for main
.PHONY: debug
debug:
	$(RUN) python -d $(MODULE) $(FLAGS)


# https://docs.github.com/en/actions/guides/building-and-testing-python
# https://pytest-cov.readthedocs.io/en/latest/config.html
# https://docs.pytest.org/en/stable/usage.html
## pytest: unit test for Python non-PIP packages
.PHONY: pytest
pytest:
	pytest --doctest-modules "--cov=$(MAIN_PATH)"

## test-pip: test pip installed packages
# assumes the directory layout of ./src/$(NAME) for package
# and ./tests for the pytest files
# -e or --editable means create the package in place
#  however the -e does work for pytest
# https://stackoverflow.com/questions/49028611/pytest-cannot-find-module
# you need a __init__.py so that pytest finds the modules
# or do this with python -m pytest which adds this
# https://stackoverflow.com/questions/42724305/pytest-cannot-find-package-when-i-put-tests-in-a-separate-directory
# this is because pytest looks up from the parent to the first directory
# that does nt have an __init__.py to find modules
.PHONY: test-pip
test-pip:
	@echo fix to PYTHONPATH for pytest
	PYTHONPATH="src" pytest ./tests

# https://stackoverflow.com/questions/66741778/how-to-install-h5py-needed-for-keras-on-macos-with-m1
## install-h5py: Special installation of h5py for M1 set INSTALL_H5PY to run as part of install
.PHONY: install-h5py
install-h5py:
	if [[ ! $$(uname -m) =~ arm64 ]] || [[ $(PYTHON_ENV) =~ conda ]]; then \
		$(INSTALL) h5py; \
	else \
		brew install hdf5 && \
		export HDF5_DIR="$$(brew --prefix hdf5)" && \
		if [[ $(PYTHON_ENV) =~ pipenv ]]; then \
			PIP_NO_BINARY=h5py pipenv install h5py; \
		else \
			$(INSTALL) --no-binary=h5py h5py; \
		fi; \
	fi

## install-dev: Install as a development package for testing
.PHONY: install-dev
install-dev: install
	@echo pip install -e for adhoc testing
ifeq ($(strip $(PYTHON_ENV)), pipenv)
	$(INSTALL) --dev -e .
else
	$(RUN) pip install -e .
endif

## test-ci: product junit for consumption by ci server
# --doctest-modules --cove measure for a particular path
# --junitxml is readable by Jenkins and CI servers
.PHONY: test-ci
test-ci:
	pytest "--cov=$(MAIN_PATH)" --doctest-modules --junitxml=junit/test-results.xml --cov-report=xml --cov-report=html


# https://www.gnu.org/software/make/manual/html_node/Splitting-Lines.html#Splitting-Lines
# https://stackoverflow.com/questions/54503964/type-hint-for-numpy-ndarray-dtype/54541916
#

## test-make: Test environment (Makefile testing only)
.PHONY: test-make
test-make:
	@echo 'NAME="$(NAME)" MAIN="$(MAIN)"'
	@echo 'PYTHON_ENV="$(PYTHON_ENV)" RUN="$(RUN)"'
	@echo 'SRC="$(SRC)" NB="$(NB)" STREAMLIT="$(STREAMLIT)"'

## activate: activate virtual environment
.PHONY: activate
activate:
	@echo run $(ENV_ACTIVATE) or add to .envrc if you use direnv

## deactivate: deactivate virtual environment
.PHONY: deactivate
deactivate:
	$(ENV_DEACTIVATE)

## vi: run the editor in the right environment
.PHONY: vi
vi:
	cd $(ED_DIR) && $(RUN) "$$VISUAL" $(ED)

# https://www.technologyscout.net/2017/11/how-to-install-dependencies-from-a-$(REQUIREMENTS_TXT)-file-with-conda/
## install-env: install into python environment set by $(PYTHON_ENV)
# https://stackoverflow.com/questions/9008649/gnu-make-conditional-function-if-inside-a-user-defined-function-always-ev
.PHONY: install-env
install-env: $(INSTALL_REQ)
	@echo Installing in $(PYTHON_ENV)
ifeq ($(PYTHON_ENV),conda)
	@echo "conda preamble"
	conda env list | grep ^$(NAME) || conda create -y --name $(NAME)
	conda config --env --add channels conda-forge
	conda config --env --set channel_priority strict
	$(INSTALL) python=$(PYTHON) $(CONDA_ONLY)
else ifeq ($(PYTHON_ENV),poetry)
	poetry env use "$(PYTHON_MINOR)"
else ifeq ($(PYTHON_ENV),uv)
	@echo "$(PYTHON_ENV) if using asdf direnv make sure .envrc run and .tool-version exists"
	@echo "$(PYTHON_ENV) and UV_PROJECT_ENVIRONMENT exists"
endif
	$(ENV_DEACTIVATE) || true
	$(ENV_CREATE)

	# using conditional in function form if first is not null, then insert
	# second, else the third if it is there
	@echo installing pip packages
	$(if $(strip $(PIP)), $(INSTALL)  $(PIP))
	$(if $(strip $(PIP_PRE)), $(INSTALL_PRE)  $(PIP_PRE))
	$(if $(strip $(PIP_DEV)), $(INSTALL_DEV) $(PIP_DEV))
	$(if $(strip $(PIP_ONLY)), $(INSTALL_PIP_ONLY) $(PIP_ONLY) || true)
	$(INSTALL_REQUIREMENTS) || true


ifeq ($(PYTHON_ENV),poetry)
	@echo "poetry postamble install from pyproject.toml"
	$(INIT)
else ifeq ($(PYTHON_ENV),pipenv)
	@echo "pipenv postamble"
	$(PIPENV) lock -r > $(REQUIREMENTS_TXT) && $(PIPENV) update
else ifeq ($(PYTHON_ENV),conda)
	@echo "conda postamble"
	[[ -r environment.yml ]] && conda env update --name $(NAME) -f environment.yml || true
	# echo $$SHELL
	[[ -r $(REQUIREMENTS_TXT) ]] && \
		grep -v "^#" $(REQUIREMENTS_TXT) | \
			(while read requirement; do \
				echo "processing $$requirement"; \
				if ! conda install --name $(NAME) -y "$$requirement"; then \
					$(ACTIVATE) && \
					pip install "$$requirement"; \
					echo "installed $$requirement";\
				fi; \
			done) \
		|| true
	# https://docs.conda.io/projects/conda/en/latest/user-guide/tasks/manage-environments.html#setting-environment-variables
	conda env config vars set PYTHONNOUSERSITE=true --name $(NAME)
	@echo WARNING -- we do not parse the PYthon User site in ~/.
endif

## lock: Freeze configuration to $(REQUIREMENTS_TXT) or conda export to environment.yml
# https://pipenv.kennethreitz.org/en/latest/basics/ lock -r will add SHA hashes
.PHONY: lock
lock:
	$(INSTALL_LOCK)

## export: export from venv to requirements.txt
export:
	$(EXPORT_REQUIREMENTS)

## upgrade: Upgrade all the packages
.PHONY: upgrade
upgrade:
	$(INSTALL_UPGRADE)

# https://medium.com/@Tankado95/how-to-generate-a-documentation-for-python-code-using-pdoc-60f681d14d6e
# https://medium.com/@peterkong/comparison-of-python-documentation-generators-660203ca3804
## pdoc-doc: make the documentation for the Python projec (deprecated for include.mk docs)
.PHONY: pdoc-doc
pdoc-doc:
	for file in $(ALL_PY); \
		do $(RUN) pdoc --force --html --output $(DOC) $$file; \
	done

## pdoc-debug: run web server to look at docs (deprecated to include.mk docs
.PHONY: pdoc-debug
pdoc-doc-debug:
	@echo browse to http://localhost:8080 and CTRL-C when done
	for file in $(ALL_PY); \
		do $(PIPENV) run pdoc --http : $(DOC) $$file; \
	done

## format: reformat python code to standards (deprecated use pre-commit to do this)
.PHONY: format
format:
	# the default is 88 but pyflakes wants 79
	$(RUN) isort --profile=black -w 79 .
	$(RUN) black -l 79 *.py

## shell: Run interactive commands in Pipenv environment
.PHONY: shell
shell:
ifeq ($(strip $(PYTHON_ENV)), poetry)
	poetry shell
else ifeq ($(strip $(PYTHON_ENV)),pipenv)
	$(PIPENV) shell
else ifeq ($(strip $(PYTHON_ENV)),conda)
	@echo "run conda activate $(NAME) in your shell make cannot run"
else
	@echo "bare pip so no need to shell"
endif

# https://stackoverflow.com/questions/53382383/makefile-cant-use-conda-activate
# https://github.com/conda/conda/issues/7980
## conda-clean: Remove conda and start all over
.PHONY: conda-clean
conda-clean:
	$(INIT) && conda activate base
	$(UPDATE)
	conda env remove -n $(NAME) || true
	conda clean -afy

# Note we are using setup.cfg for all the mypy and flake EXCLUDEs and config
## lint : code check (deprecated use pre-commit)
.PHONY: lint
lint:
	$(RUN) flake8 || true
ifdef ALL_PY
	$(RUN) seed-isort-config ||true
	$(RUN) mypy || true
	$(RUN) bandit $(ALL_PY) || true
	$(RUN) pydocstyle --convention=google $(ALL_PY) || true
endif
ifdef ALL_YAML
	echo $$PWD
	$(RUN) yamllint $(ALL_YAML) || true
endif

## python-asdf: Install local python vrsion with asdf
# note asdf needs fully qualified including minor release
.PHONY: python-asdf
python-asdf:
	asdf local python "$(PYTHON_MINOR)"


## test-pypi: build and upload PyPi PIP package distribution to test
# https://twine.readthedocs.io/en/latest/
.PHONY: test-pypi
test-pypi: dist
	$(RUN) twine upload -u __token__ \
		-p "pypi-$$TEST_PYPI_API_TOKEN" \
		--repository testpypi dist/*

	#$(RUN) python -m pip install --upgrade --index-url https://test.pypi.org/simple --no-deps $(NAME)

## dist: build PyPi PIP packages
.PHONY: dist
dist: setup.py
	@echo "Put token into TEST_PYPI_API_TOKEN"
	@echo "from https://test.pypi.org/manage/account/#api-token"
	$(RUN) python -m build

## pypi: build package and push to the python package index
.PHONY: pypi
pypi: dist
	$(RUN) twine upload \
		-u __token__ \
		-p "pypi-$$PYPI_API_TOKEN" \
		dist/*
