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


## docx: Convert from .ipynb to .docx
.phony: docx
docx:
	pandoc $(NOTEBOOK) -s -o "$$(basename -s ipynb "$(NOTEBOOK)")docx"

# If you are running in a container otherwise it is just home
DATA ?= $(PWD)
#DATA ?= /var/data

## jupyter: run jupyter
jupyter:
	jupyter lab build && \
	jupyter lab \
        --notebook-dir=$(DATA) \
        --ip='*' \
        --port=8888 \
        --no-browser
