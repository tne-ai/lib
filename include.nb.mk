# note tables not compatible with 3.9
##
## Jupyter Notebook Commands
## ----
PYTHON ?= 3.8
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


## jupyter: run jupyter
jupyter:
	jupyter lab build && \
	jupyter lab \
        --notebook-dir=/var/data \
        --ip='*' \
        --port=8888 \
        --no-browser
