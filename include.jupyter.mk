# note tables not compatible with 3.9 as of June 2020
##
## Jupyter Notebook Commands
## ----
#PYTHON ?= 3.8
PACKAGES+=make vim gosu
# for Restart
#PIP+=pandas confuse ipysheet h5py ipywidgets ipympl ipyvuetify \
     #scipy altair xlrd bqplot ipyvolume restart==2.6.7 restart_datasets voila
#PIP_ONLY+=tables qgrid
NPM_PACKAGES+=mermaid-filter


# If you are running in a container otherwise it is just home
DATA ?= $(PWD)/data
#DATA ?= /var/data

NOTEBOOK ?= $(DATA)/$(notdir $(PWD)).ipynb
# https://stackoverflow.com/questions/12069457/how-to-change-the-extension-of-each-file-in-a-list-with-multiple-extensions-in-g
MARKDOWN ?= $(NOTEBOOK:ipynb=md)

# ENV is the environment used by include.python.mk

# notebook have vim mode take from ./src/docker/image/jupyterlab
# and https://neptune.ai/blog/jupyterlab-extensions-for-machine-learning
# https://medium.com/data-for-everyone/best-extensions-for-jupyterlab-185ab5f3e05c
# will eventually merge the two
PIP += 	\
		"jupyterlab>=3.3" \
		"jupyterlab_latex>=3.1.0" \
		"lckr-jupyterlab-variableInspector" \
	   	"jupyter_tensorboard>=0" \
	   	"jupyterlab-system-monitor>=0.8" \
	   	"jupyterlab-vim>=0.15" \
	   	"nbdime>=1.1.1" \
       	"jupyterlab-git>=0.37" \
       	"jupyterlab-github>=3.0" \
       	"jupyterlab-lsp>=3.10" \
       	"python-lsp-server[all]>=1.5.0" \
        "aquirdturtle_collapsible_headings>=3.1" \
        "jupyter-dash>=0.4.2" \
        "jupyter_bokeh>=3.0.4" \
        "jupyterlab_widgets>=1.1" \
		"ipyleaflet>=0.17" \
        'ipywidgets>=7.5'


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
