<!-- delta merge @ 2026-04-24 18:17 UTC -->

- _(discovery | 2026-03-11)_ **Submodule lib shows uncommitted state in parent repository**
  Parent repository /Users/rich/ws/git/src needs update to reference new lib commit 00ecca8.
- _(discovery | 2026-03-11)_ **Repository cleanup in progress - disabled workflow files being removed**
  Git status reveals multiple disabled workflow files deleted and moved to workflow.disabled directory.
- _(discovery | 2026-03-11)_ **Template-to-file mapping system in include.mk**
  Makefile defines parallel TEMPLATE and FILE arrays that map source templates to destination filenames
- _(discovery | 2026-03-11)_ **Hugo Workflow Incorrectly Deployed to 30+ Non-Hugo Projects**
  Hugo GitHub Pages workflow found in app and demo projects that likely don't use Hugo static site generation
- _(discovery | 2026-03-11)_ **Repository-Wide Audit of Disabled Workflow Files**
  Found disabled and broken workflow files scattered across 35+ projects throughout the repository tree
- _(discovery | 2026-03-11)_ **Multiple submodules lack expected directory structure and Makefile targets**
  Seven submodules across app and demo directories fail template sync due to missing workflows directories or Makefile targets
- _(discovery | 2026-03-11)_ **Script processes demo directory and handles missing Makefile targets gracefully**
  git-submodule-install-lib.sh now processes demo submodules and continues with warnings when make targets are missing
- _(discovery | 2026-03-11)_ **DRY_RUN implementation patterns in utility library**
  Library provides both function-flag and global-variable dry run modes for git commands and file operations
- _(discovery | 2026-03-11)_ **Git submodule Makefile installation guard logic**
  Shell script checks for missing Makefile before copying base template in each submodule
- _(discovery | 2026-03-11)_ **Submodule Installation Creates Makefiles, Doesn't Update Them**
  Script copies Makefile.base to submodules missing a Makefile, then runs make install-repo and install-pre-commit targets
- _(discovery | 2026-03-10)_ **Current install-repo implementation uses custom timestamp checks**
  Makefile manually tests file timestamps with -nt before calling install command
- _(discovery | 2026-03-10)_ **Rsync provides multiple file comparison strategies**
  Rsync offers checksum-based, timestamp-based, and existence-based conditional copy options
- _(discovery | 2026-03-10)_ **Install utility provides built-in file comparison**
  The install command's -C flag already checks file sameness before copying to preserve timestamps
- _(discovery | 2026-03-10)_ **Current install-repo Makefile target implementation**
  The install-repo target copies templates when FORCE is set or destination doesn't exist, without checking timestamps
- _(discovery | 2026-03-10)_ **Pre-commit Hooks Validation After Configuration Updates**
  All updated pre-commit hooks pass successfully except markdownlint-cli2 which has pre-existing documentation lint findings.
- _(discovery | 2026-03-10)_ **Git Status Check Before Commit**
  Repository has staged changes to pre-commit configuration, build files, and workflows ready for commit.
- _(discovery | 2026-03-10)_ **Pre-commit Hook Status Audit Before Version Updates**
  Ran all pre-commit hooks to identify current failures before updating hook versions
- _(discovery | 2026-03-09)_ **Mise environment not activated in current shell session**
  Mise configuration specifies correct GOROOT but environment variables not exported to active shell
- _(discovery | 2026-03-09)_ **Go 1.26.1 already installed by mise but shell environment not updated**
  Mise reports correct Go 1.26.1 installation path but shell GOROOT variable not refreshed
- _(discovery | 2026-03-09)_ **Mise configuration update requires installation step to take effect**
  After updating mise.toml to go@1.26.1, GOROOT still points to 1.26.0 installation
- _(discovery | 2026-03-09)_ **Go version mismatch caused by GOROOT pointing to outdated mise installation**
  Go binary reports version 1.26.1 but GOROOT points to mise-managed 1.26.0 installation
- _(discovery | 2026-03-09)_ **Go version upgrade impacts pre-commit hooks with compilation errors**
  Upgrading Go from 1.26.0 to 1.26.1 caused pre-commit hooks to fail with version mismatch errors
- _(discovery | 2026-03-09)_ **Go version mismatch blocking pre-commit hooks**
  Pre-commit hooks fail due to Go toolchain version mismatch between compiled packages and current go tool.
- _(discovery | 2026-03-06)_ **Pre-commit failure caused by incompatible Node.js 22.12.0 in cached environment**
  Pre-commit environment cached Node 22.12.0 which fails eslint-visitor-keys dependency requiring Node 22.13.0 or higher.
- _(discovery | 2026-02-20)_ **Makefile.base defines the standard repository Makefile pattern with include.mk**
  Template Makefile shows how repositories should include the centralized include.mk and optional specialized includes
- _(discovery | 2026-02-20)_ **demo-flar Makefile is a minimal Astro development system with categorized help**
  demo-flar uses simple 13-line Makefile with enhanced help system showing categorized targets
- _(discovery | 2026-02-20)_ **demo-crank Makefile is a comprehensive Astro site with GitHub Pages deployment**
  demo-crank uses full-featured Makefile for CertisAI website with development, building, linting, and GitHub Pages deployment
- _(discovery | 2026-02-20)_ **demo-clover Makefile is an Astro-based web development system**
  demo-clover uses Makefile with Astro framework targets for development, building, and preview
- _(discovery | 2026-02-20)_ **demo-castle Makefile is a minimal web development system for Castle Shield website**
  demo-castle uses simple 13-line Makefile for npm-based web development server
- _(discovery | 2026-02-20)_ **Four demo repositories have Makefiles without include.mk**
  demo-castle, demo-clover, demo-crank, and demo-flar identified as missing include.mk inclusion
- _(discovery | 2026-02-20)_ **Demo directory submodules are not initialized**
  Git submodule status shows demo-atlas and ockam submodules exist but are uninitialized
- _(discovery | 2026-02-20)_ **Demo directory contains 38 demo-\* subdirectories plus additional repositories**
  Discovered 38 demo client repositories and 3 existing-\* repositories in demo directory structure
- _(discovery | 2026-02-20)_ **app-whiskey Makefile is a comprehensive Svelte/Supabase web app development system**
  app-whiskey uses detailed Makefile for full-stack development with pnpm, SvelteKit, Supabase, and LLM integration
- _(discovery | 2026-02-20)_ **app-oscar Makefile is a Docker-only deployment system**
  app-oscar uses minimal Makefile focused exclusively on Docker image building and ECR deployment
- _(discovery | 2026-02-20)_ **app-mike Makefile is an Azure AI Arena UI development system**
  app-mike uses minimal Makefile for Azure AI Arena UI with uv Python setup and npm dev server
- _(discovery | 2026-02-20)_ **app-kilo Makefile is a TrustBench Streamlit application build system**
  app-kilo uses specialized Makefile for Python Streamlit app with uv package manager and Docker deployment
- _(discovery | 2026-02-20)_ **app-blue Makefile is a custom web development build system**
  app-blue uses a specialized Makefile for SoveraMed Website with npm-based targets, incompatible with standard include.mk
- _(discovery | 2026-02-20)_ **Examined git-submodule-install-lib.sh default repository configuration**
  Script currently defaults DEST_REPO to array (demo app) with positional parameter override support
