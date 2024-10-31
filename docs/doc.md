# Documentation

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

### Detailed instructions

In here is the process:

1. You will need the standard tooling from ./lib
1. So put your repo as a submodules inside the ./src repo and cd into your repo
1. Then copy the Makefile pieces with cp ./src/lib/Makefile.base >> Makefile
   Adjust the Makefile includes so it points to ./src/lib/include.mk and
   ./src/lib/include.python.mk (you can delete this last if the project doesn’t
   just python.
1. Check that it works by running make and you should see a list of things to do.
1. Now install the basic tooling files with make install-repo. This will only add
   files and blow anything away. Now you should edit the mkdocs.yaml so that the
   entries for the file and where it lives are correct, by convention it will be
   [_repo_.docs.tongfamily.ai](https://docs.tongfamily.com) or whatever your org
   is.
1. Edits your documentation starting at ./docs/index.md and add files as
   needed. To set the navigation edit mkdocs.yaml
1. Test this works by running make mkdocs which will create a local server
   which you can access at [http://localhost:8000](http://localhost:8000) and
   debug your site.
1. Now if you are a command line jockey install the netlify cli with `npm
install -g netlify`
1. Or just go to [Netlify](https://netlify.com) and login as [admin](mailto:admin@tne.ai)
   and the password is 1Password
1. In the middle of the screen, you will see a button called add new site and
   select choose an existing project, then connect ot GitHub with that button
   and you should see pick a repository so lect the netdrones organization and
   search for your repo.
1. If this is working, it should fille things in for you but specifically the
   branch to deploy is main and the build command is mkdocs build. BY THE WAY
   there is no magic here, there are two files netlify.toml and runtime.txt
   that were added that tell netlify this is a mkdocs site and what version of
   Python to run on the client.
1. Hit deploy site
1. YOu should see the Netlify runner starting and it should say Production
   main@HEAD and building. And when it stops at Published, click on the arrow
   and click on Open Production deploy and make sure that this is the right
   site. It has a random url by the way that is on the netlify site. And this
   should look the same as the local build.
1. Now click on the top where you see the site name and you should be back at
   Site Overview, there should be a huge number 2 that says Set up Custom
   domain
1. Now enter the domain that you want. NOTE: DO NOT BE LIKE ME and just type
   netdrones.ai, this will wipe out our company website instead put what you
   want the name to be like _repo_.docs.netdrones.ai so
   process.docs.netdrones.ai for the ./src/process repo amd hit add
1. What you press verify it should say good news and you should be done. make
   sure to hit force HTTPS below and then wait for the domain to work. It is
   going to say Awaiting External DNS, but don’t worry about that just click on
   the name and make sure it works!

### Dealing with Submodules (Requires more work)

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
