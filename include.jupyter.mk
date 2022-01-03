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

NOTEBOOK ?= notebook.ipynb
# ENV is the environment used by include.python.mkkk
PIP ?= nbdime
ENV ?= pipenv


## docx: Convert from .ipynb to .docx
.phony: docx
docx:
	pandoc $(NOTEBOOK) -s -o "$$(basename -s ipynb "$(NOTEBOOK)")docx"

# If you are running in a container otherwise it is just home
DATA ?= $(PWD)
#DATA ?= /var/data

LAB ?=

## jupyter-install: installs jupyterlab extensions after python packages
.PHONY: jupyter-install
jupyter-install: install
	$(RUN) jupyter labextension install $(LAB)
## jupyter: run jupyter
# if include.python.mk is added will run in the environment defined assuming
# that RUN is set
# https://nbdime.readthedocs.io/en/latest/installing.html
# do not have to enable the pip install does this
# $(RUN) nbdime extensions --enable
.PHONY: jupyter
jupyter:
	$(RUN) jupyter lab build
	$(RUN) jupyter lab \
        --notebook-dir=$(DATA) \
        --ip='*' \
        --port=8888 \
        --no-browser
