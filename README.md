<!-- markdownlint-capture -->
<!-- markdownlint-disable MD041 -->
<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Library](#library)
  - [Github files](#github-files)
  - [Makefile includes](#makefile-includes)
  - [Using repo installation](#using-repo-installation)
  - [Installation](#installation)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->
<!-- markdownlint-restore -->

# Library

## Github Actions and Pre-commit CD/CI chain

When adding to this repo, you should run a `make pre-commit-install` to install
pre-commits. The main option is use base pre-commit-config.base.yaml as this
now includes all the actions for python and jupyter into a single master.

If you have python and jupyter notebooks that do not conform, now is the time
to just fix them once and for all. It is a little work, but don't have this
bite you later.

These same pre-commit actions are used by workflow.base.yaml which is a GitHub
action that uses the same .pre-commit-config.yaml and runs it in GitHub.

You can also download act which runs GitHub Actions in a docker container on
your machine to test github actions without having to push it into the cloud.

## Github files

You should copy ./github to .github to get issue templates and workflow

## Makefile includes

These are the standard includes:

include.mk is required and has help and configuration used for all

The others are for specific purposes:

include.python.mk is for python development
include.airflow.mk for using Apache airflow
include.docker.mk for docker managemen

## Using repo installation

If you want to create a new repo then you need to:

- link to [setup.cfg](setup.cfg)
- create a Makefile that refers to at least [include.mk](include.mk)
- the run `make repo-init` which will also add helper repos like bin, lib and
    docker

## Installation

This library is used by the parallel richtong/bin repo and you should put them
next to each other. Normally you want to fork the repo

```shell
cd ~/ws/git
gh fork git@github.com:richtong/lib
gh fork git@github.com:richtong/bin
cd src
git submodule add git@github.com/_yourrepo_/lib
git submodule add git@gihtub.com/_yourrepo_/bin
git submodule update --init lib bin
cd lib
git remote add upstream git@github.com/richtong/lib
cd ../bin
git remote add upstream git@github.com/richtong/bin
```

Then when you make a change or and want to merge from upstream
then you just need to

```shell
cd ~/ws/git/_yourrepo_/bin
git pull --rebase upstream master
# deal with any conflict
git push
```
