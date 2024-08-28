# Welcome to Rich's Fine Utility Library

For full documentation visit
[lib.docs.tongfamily.com](https://lib.docs.tongfamily.com) or you can browse
the GitHub repository where the main fork is
[github.com/richtong/lib](https://github.com/richtong/lib).

## Quick note on this README.md and the upstream

If you want to update the table of contents at the top, run `make toc` and it
will recreate it for you. Note that if you are viewing this with Github, you
will now see Mermaid diagrams, otherwise you need a Mermaid tool to see
diagrams like in Vim, the MarkdownPreview system.

## Bootstrapping the Library (and Binaries) for a new mono repo

The easiest way to use these library files is to create a mono repo where you
put the [bin](https://github.com/richtong/bin) and
[lib](https://github.com/richtong/lib) in a mono repo that lives in :

```sh
# copy the Makefile template assuming it is a sibling of this repo
cd ~
mkdir -p ws/git
git clone git@github.com:_yourorg_/src
cd src
git submodule add git@github.com:richtong/lib
git submodule add git@github.com:richtong/bin
# this is the bootstrap that gives you the Makefile from lib
cat "include lib/include.mk" > Makefile
# Now you can get the templates
make install-repo
```

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

## Customizing the Base installation

You should copy the files with the suffix TEMPLATE files to .github to get
issue templates and workflow

You should also pick the .gitignore file that you want. There is a base version
and there is a version for python and so forth. Copy this into .gitignore

If you are using Git LFS, which is highly recommended, you should copy
gitattributes.* to .gitattributes
