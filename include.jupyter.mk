##
## Jupyter Notebook Commands
## ----

DOCKER_REGISTRY := docker.io
REPO ?= richt
#PYTHON ?= 3.11
PACKAGES+=make vim gosu
# for Restart
#PIP+=pandas confuse ipysheet h5py ipywidgets ipympl ipyvuetify \
     #scipy altair xlrd bqplot ipyvolume restart==2.6.7 restart_datasets voila
#PIP_ONLY+=tables qgrid
NPM_PACKAGES+=mermaid-filter


NOTEBOOK ?= $(DATA)/$(notdir $(PWD)).ipynb
# https://stackoverflow.com/questions/12069457/how-to-change-the-extension-of-each-file-in-a-list-with-multiple-extensions-in-g
MARKDOWN ?= $(NOTEBOOK:ipynb=md)

# pipenv not stable does not lock and h5py will not install
ENV ?= uv
#ENV ?= poetry  # deprecated
#ENV ?= conda  # deprecated
# Note for docker this variable is actually in docker-compose.env
# If you are running in a container otherwise it is just home
DATA ?= $(PWD)/data
#DATA ?= /var/data

#DOCKER := docker
#
# docker, colima - docker cli using colima with docker runtime (tested works)
DOCKER ?= docker
DOCKER_RUNTIME ?= colima
ARCH :- linux/arm64
# uncomment for cross platform amd64 images
# COLIMA_ARCH_FLAG ?= --arch x86_64
# uncomment for cross platform arm64 images
# COLIMA_ARCH_FLAG ?= --arch aarch64
#
# colima nerdctl, colima - colima nerdctl using colima containerd (tested works,
# does not support build --pull)
# DOCKER ?= colima nerdctl
# DOCKER_RUNTIME ? colima
#
# lima nerdctl, lima - lima nerdctl using lima containerd (test works if
# NordVPN not running at docker-start time but docker hub access not working)
# DOCKER ?= lima nerdctl
# DOCKER_RUNTIME ?= limactl
#
# podman, podman - podman cli using podman (does not work no way to mount host volumes)
# DOCKER ?= podman
# DOCKER_RUNTIME ?= $(DOCKER)
# Testing lima support and this does work but fails docker access
#DOCKER ?= lima nerdctl
#DOCKER_RUNTIME ?= limactl
# Jupyterlab>=3 does not work on M1 Mac
#PIP := 'jupyterlab>=3'

# As of Jun 2021
# drawio was totally standalone, the new ipydrawio has full integration
#jupyterlab-drawio \
# so you can merge diagrams into a jupyter notebook.
# graphviz let's you do drawing
# code for mermade calling mermaid.io for general
#
# As of Dec 2021
# https://discourse.jupyter.org/t/ipydrawio-diagrams-in-jupyterlab-with-pages-layers-widgets-pdf-export/8749
# now use blockdiag magics (to do drawing inline with text like graphviz we
# have now)
# and ipydrawio for deeper drawings (not integrated into Jupyter Notebooks)
# blockdiagmagic - https://github.com/innovationOUtside/ipython_magic_blockdiag
# insert into Notebook
# %load_ext blockdiag_magic
# to use with SVG instead of the PNG default
# %setdiagsvg
# %setdiagpng
# %%blockdiag -o block.png
# A -> B -> C;
# B -> D;
#
# Render it with
# from IPython.display import PNG
# PNG('block.png')
# https://github.com/innovationOUtside/nb_js_diagrammers
# iPython magics for generatin from mermaid.js, flowchart.js, wavedrom,
# waversrfer.js
# %load_ext nb_js_diagrammers
# if you use the -o it generates a readable file name
# %%flowhchart_magic -h 100
# st=>start: Start
# e=>end: End
# s(right)->e
# %%mermaid_magic -h 500
# flowchart TB
# a[Start] --> B{Is it?};
# pyflowchart create a flow chart for the code
# ##pytflowchart_magic -h 800
# def main:
#   for i in 1..10:
#     print(i)
# https://github.com/nicolaskruchten/jupyter_pivottablejs/
# https://github.com/osscar-org/jupyterlab-hide-code
# hide_code[lab] \
# https://jupyterlab-code-formatter.readthedocs.io/en/latest/how-to-use.html#changing-default-formatter
# adds format notebook that runs yapf and isort change the formatter in
# Settings > Advanced Settings Editor > Jupyterlan Code Formmatter > User
# Preferences
# jupyterlab-lsp uses python-lsp-server for code completions
# hove, if underline then Ctrl brings up tooltip
# Ctrl-B to jump to definition, Ctrl-O to return
# . triggers autocompletion, turn on continuousHinting if you want in menu
# jupterlab-latex - Open latex files
# jupyterlab-geojson - displaying world points
# jupytext - Creating paired notebooks, so you have markdown file generating ipynb https://marc-wouts.medium.com/?p=a49dca9baa7b
# nbdev - generate python package and docs from Jupyter notebooks
# fastdoc - output an asciido which then becomes a epub or other book https://fastai.github.io/fastdoc/
# jupyterlite - single web page jupyter
#
# Note that pipenv and conda both have trouble with too many dependencies so
# make it the shortest list possible
PIP_EXTRA :- \
		jupyterhub \
		jupyter_bokeh \
		jupyter-dash \
		pivottablejs \
		isort \
		yapf \
		jupyterlab-latex \
		jupyterlab-geojson \
		ipydrawio-export \
		jupyterlab_hdf \
		ipydrawio-export \
		aquirdturtle_collapsible_headings \
		notebook


# this does not install on am M1 mac as of Dec 2021
# hdf5plugin on M1 mac will not build
PIP_AMD64_ONLY := \
		jupyterlab_theme_solarized_dark \
		hdf5plugin


# notebook have vim mode take from ./src/docker/image/jupyterlab
# and https://neptune.ai/blog/jupyterlab-extensions-for-machine-learning
# https://medium.com/data-for-everyone/best-extensions-for-jupyterlab-185ab5f3e05c
# will eventually merge the two
# some of these are out of date and generate errors
  	# "jupyter_tensorboard>=0"
PIP += 	\
		"aquirdturtle_collapsible_headings>=3.1" \
		"ipyleaflet>=0.17" \
		"jupyter-dash>=0.4.2" \
		"jupyter_bokeh>=3.0.4" \
		"jupyterlab-git>=0.37" \
		"jupyterlab-github>=3.0" \
		"jupyterlab-lsp>=3.10" \
		"jupyterlab-vim>=0.15" \
		"jupyterlab>=3.3" \
		"jupyterlab_latex>=3.1.0" \
		"jupyterlab_widgets>=1.1" \
		"lckr-jupyterlab-variableInspector" \
		"nbdime>=1.1.1" \
		"python-lsp-server[all]>=1.5.0" \
		'black[jupyter]' \
		'ipydrawio[all]' \
		'ipywidgets>=7.5' \
'python-lsp-server[all]' \
		graphviz \
		ipywidgets \
		jupyterlab \
		jupyterlab-spellchecker \
		jupyterlab_code_formatter \
		jupytext \
nbdime \
		nodejs \
		pillow \
   	"jupyterlab-system-monitor>=0.8" \

# H5py needs special handling on an M1 Macbook because it does not bundle the
# correct very of the hdf5 utility, so set this to true to install it
INSTALL_H5PY := true

# need to install h5py instead and others for pip or pipenv
CONDA_ONLY ?= \
		tensorflow-deps

# As of v2.13 no long need  the mac version
		# tensorflow-macos
# no version works
		# tensorflow-metal

PIP_ONLY ?= \
		blockdiagmagic \
		nb-js-diagrammers \
		pyflowchart \
		jupyterlab-hide-code \
		jupyterlab-github \
		nbdev \
		"tensorflow>=2.13" \
		transformers

# currently jupyterlite will not build with pipenv 2021.11 has dependency \
# conflicts
#
PIP_PRE := \
        jupyterlite

# If using conda and tensorflow
CONDA_CHANNEL := \
		 conda-forge \
		 apple \
		 huggingface

# https://towardsdatascience.com/10-jupyter-lab-extensions-to-boost-your-productivity-4b3800b7ca2a
# https://github.com/jupyterlab/jupyterlab/tree/6d106df4276e39b7726083b9d1bd3166b8a5c74b/packages
# cell tags set attributes and search
		#nb-js-diagrammers
LAB := 	@jupyterlab/celltags \
		jupyterlab-spreadsheet

# ENV is the environment used by include.python.mk


# LAB are the jupyterlab extensions LAB ?=

## jupytext: sync notebook and markdown with latest edits
.PHONY: jupytext
jupytext:
	if [[ -e $(NOTEBOOK) ]]; then \
		jupytext --sync "$(NOTEBOOK)" \
	; else \
		jupytext --sync "$(NOTEBOOK:ipynb=md)" \
	; fi

## jupyterlite: initialize jupyter lite and build from current pip installed lab extensions
##              copies files in ./files to ./_output/files, File/download changes when done
.PHONY: jupyterlite
jupyterlite:
	jupyter lite init
	jupyter lite build
	jupyter lite serve

## jupyterlite-clean: Remove the _output directory removes all in-browser edits
.PHONY: jupyterlite-clean
jupyterlite-clean:
	rm -rf _output

## docx: Convert from .ipynb to .docx
.phony: docx
docx:
	pandoc -F mermaid-filter -s -o "$(NOTEBOOK:ipynb=docx)" $(NOTEBOOK)

## pdf: Convert from markdown to pdf with mermaid
.phony: pdf
pdf:
	pandoc -F mermaid-filter -s -o "$(MARKDOWN:md=pdf)" $(MARKDOWN)


## install-jupyter: installs jupyterlab extensions after python packages
.PHONY: install-jupyter
install-jupyter: install-env
	if [[ -n "$(LAB)" ]]; then $(RUN) jupyter labextension install $(LAB); fi
	$(RUN) jupyter lab build
## jupyter: run jupyter
# if include.python.mk is added will run in the environment defined assuming
# that RUN is set
# https://nbdime.readthedocs.io/en/latest/installing.html
# do not have to enable the pip install does this
# $(RUN) nbdime extensions --enable
# do not start a browser
# --no-browser
# --port=8888
.PHONY: jupyter
jupyter:
	$(RUN) jupyter lab \
        --notebook-dir=$(DATA) \
        --ip='*'
