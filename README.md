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

General library functions. The typical usage is to create a submodule in your
repo for this so you can carry it around and refer to it. There are a few ways to
do this:

1. In a centralized one big mono repo system where your repo will mainly be
   used as a submodule in the large source repo, link this repo into a central
   place that is high up in the tree such as ./src/lib and then all modules can
   use relative links. This works best if you are going to maintain the src
   directory and the working repo is always in the same relative place so that
   you can do references like `source ../../lib/include.mk` for Makefile
   includes as an example.
2. If you have a repo which is going to be forked independently alot, you can
   create a submodule that carries the library with `git submodule add` this
   is very clean, but has the overhead that in a big project, you can have lots
   of ./lib submodules which is messy so the relative link works well.
3. The last one which works if the repo is mainly used in a mono repo there are
   many references is to create a symbolic link and you have many references in
   many files so it is useful to just have a local relative link.

## Quick note on this README.md and the upstream

If you want to update the table of contents at the top, run `make toc` and it
will recreate it for you. Note that if you are viewing this with Github, you
will now see Mermaid diagrams, otherwise you need a Mermaid tool to see
diagrams like in Vim, the MarkdownPreview system.

Note that the main

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

You should copy the files with the suffix TEMPLATE files to .github to get
issue templates and workflow

You should also pick the gitignore file that you want. There is a base version
and there is a version for python and so forth. Copy this into .gitignore

If you are using Git LFS, which is highly recommended, you should copy
gitattributes.* to .gitattributes

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
