# General Description

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

## Getting to the full documentation

This has moved to a Mkdocs formatted website at
[lib](https://lib/docs.tongfamily.com) which is actually hosted thanks to
[Netlify](https://netlify.com).

You can also browse the documents by looking through
[docs](docs)

You can also get these documentation yourself by cloning this repo and running:

```sh
# start and the
make mkdocs
open http://locahost:800w
# when you are documentation
make mkdocs-stop
```
