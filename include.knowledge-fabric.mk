##
## Knowledge Fabric Commands
## ---
## Targets for projects using the Knowledge Fabric graph viewer/editor
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

## app: open the Knowledge Fabric graph app (viewer + inline editor)
.PHONY: app
app: _kf-guard
	python $(CLI) viz

## ingest: ingest documents into the graph database
.PHONY: ingest
ingest: _kf-guard
	python $(CLI) ingest

## export: export static files for GitHub Pages / CDN (no server needed)
##         output: .viz/graph_data.json + .viz/index.html
export: _kf-guard
	python $(CLI) viz --export-only

## dev: ingest documents then open the app
.PHONY: dev
dev: ingest app
