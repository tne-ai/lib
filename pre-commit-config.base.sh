#!/usr/bin/env bash
# this runs the base pre-commit file if present

BASE="${BASE:-pre-commit-config.base.yaml}"
echo "Running $BASE"
if [[ -e $BASE ]]; then
	echo "Run against $* files"
	pre-commit run --config "./$BASE" --files "$@"
fi
