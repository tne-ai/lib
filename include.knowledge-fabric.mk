##
## Knowledge Fabric Commands
## ---
## Targets for projects using the Knowledge Fabric graph app
## (demo-do178c pattern). Requires cli.py in the project root.
##
## Include this file from your project Makefile:
##   -include $(INCLUDE_DIRS)/include.knowledge-fabric.mk
##
## Override CLI if your entry point differs:
##   CLI ?= my_cli.py
##

CLI ?= cli.py

# Guard: fail with a clear message if cli.py is not present.
# Called as a prerequisite so the error fires before the recipe runs.
.PHONY: _kf-guard
_kf-guard:
	@test -f $(CLI) || \
		{ echo "Error: $(CLI) not found."; \
		  echo "Run make from the project root that contains $(CLI)."; \
		  exit 1; }

## kfab: open the Knowledge Fabric app (3D graph viewer + inline editor)
.PHONY: kfab
kfab: _kf-guard
	python $(CLI) viz

## kfab-ingest: ingest documents into the Knowledge Fabric graph database
.PHONY: kfab-ingest
kfab-ingest: _kf-guard
	python $(CLI) ingest

## kfab-export: export static Knowledge Fabric files for GitHub Pages / CDN
##              output: .viz/graph_data.json + .viz/index.html (no server needed)
.PHONY: kfab-export
kfab-export: _kf-guard
	python $(CLI) viz --export-only

## kfab-dev: ingest documents then open the Knowledge Fabric app
.PHONY: kfab-dev
kfab-dev: kfab-ingest kfab
