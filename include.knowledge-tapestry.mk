##
## Knowledge Tapestry Commands
## ---
## Targets for projects using the Knowledge Tapestry graph app
## (demo-do178c pattern). Requires ktap.py in the project root.
##
## Include this file from your project Makefile:
##   -include $(INCLUDE_DIRS)/include.knowledge-tapestry.mk
##
## Override CLI if your entry point differs:
##   CLI ?= my_ktap.py
##

CLI ?= ktap.py

# Guard: fail with a clear message if CLI is not present.
# Called as a prerequisite so the error fires before the recipe runs.
.PHONY: _kt-guard
_kt-guard:
	@test -f $(CLI) || \
		{ echo "Error: $(CLI) not found."; \
		  echo "Run make from the project root that contains $(CLI)."; \
		  exit 1; }

## ktap: open the Knowledge Tapestry app (3D graph viewer + inline editor)
.PHONY: ktap
ktap: _kt-guard
	python $(CLI) viz

## ktap-ingest: ingest documents into the Knowledge Tapestry graph database
.PHONY: ktap-ingest
ktap-ingest: _kt-guard
	python $(CLI) ingest

## ktap-export: export static Knowledge Tapestry files for GitHub Pages / CDN
##              output: .viz/graph_data.json + .viz/index.html (no server needed)
.PHONY: ktap-export
ktap-export: _kt-guard
	python $(CLI) viz --export-only

## ktap-dev: ingest documents then open the Knowledge Tapestry app
.PHONY: ktap-dev
ktap-dev: ktap-ingest ktap
