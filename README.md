# Rich's Fine Library

## Creating from template

If you are creating a new directory, then you can just:

1. Copy the Makefile.base to your brand new repo.
1. Adjust the .INCLUDE_DIR path to include the location of this .lib
1. The run `make install-repo` to get all the default files in place
1. The ones that you should think about are the envrc.base into your .envrc you
   do not usually want this except at the top level of your project. So if you have
   a ./ws/git/src, then you put it there, but don't put it below because lower
   .envrc mask the upper ones. You just want one place to put all your
   configuration. Particularly if you have keys that are read from 1Password

## Getting to the full documentation

This has moved to a Mkdocs formatted website at
[lib](https://lib/docs.tongfamily.com) which is actually hosted thanks to
[Netlify](https://netlify.com).

You can also browse the documents by looking through [docs](docs)

You can also get these documentation yourself by cloning this repo and running:

`````sh # start and the make mkdocs open http://locahost:800w # when you are
documentation make mkdocs-stop ``` ````
```
`````
