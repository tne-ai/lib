# Creation and Publishing of documentation

The main documentation lives in
[README.md](https://github.com/richtong/README.md) and you can browse in
the GitHub repo.

The [Docs](https://github.com/richtong/lib/docs) has the core documents in
mkdocs format.

## Creating and editing the documentation

Run `make mkdocs` to run a local server and check the content with a browser on
your machine.

## Creating a pushing a Netlify static sites

With a paid account you can easily create a private documentation from a
private github repo. The main trick is to make sure to edit the netlify.toml
file from the main template with your name. Also you need a requirements.txt
that pipenv or poetry can generate. And you need a runtime.txt with the version
number of the Python that you need.

To make this work you need a Netlify account and then you authenticate with
GitHub using their local applications. The only real issue is that private
submodules are pain, they need a
[deployment](https://answers.netlify.com/t/support-guide-how-do-i-access-private-repositories-in-the-build-environment/723)
key per submodule as of February 2023. And you should probably do this with a
DevOps account on GitHub so it is not tied to an individual developer.

## Creating a Read The Docs Project

This works if you want the documentation free since they allow free hosting.
This only works for open sourced documents
