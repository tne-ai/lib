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

### Dealing with Submodules

The one issue with Netlify is how it handles submodules. If you have private
submodules, then you need to create a [GitHub machine user](https://docs.github.com/en/developers/overview/managing-deploy-keys)
which has read access to all the submodule repositories. With personal
accounts, you need to add the machine user (or bot account) to every
repository. With organizations you do that or you need to add them to the team
(and this does create another seat you need to pay for).

For "free" individual users, to GitHub page and then to the repo you want in
`Settings > General > Collaborators > Add People`. It is probably easiest to
create a new account with a `-bot` or `-netlify` suffix and the same user name
and make sure it has two factor on as it has lots of read permissions.
Unfortunately there is no command line way to do this but you can call the
GitHub API to do this addition
[curl](https://stackoverflow.com/questions/13004061/how-does-one-add-a-collaborator-in-github-using-the-command-line)
or [gh
cli](https://docs.github.com/en/rest/collaborators/collaborators?apiVersion=2022-11-28#add-collaborator)

```sh
curl -i -u "my_user_name:my_password" -X PUT \
    -d '' 'https://api.github.com/repos/my_gh_userid/my_repo/collaborators/my_collaborator_id'
# the brew install gh version is a little easier to
a# GitHub CLI api
# https://cli.github.com/manual/gh_api
gh api \
  -H "Accept: application/vnd.github+json" \
  /repos/OWNER/REPO/collaborators
```

## Creating a Read The Docs Project

This works if you want the documentation free since they allow free hosting.
This only works for open sourced documents
