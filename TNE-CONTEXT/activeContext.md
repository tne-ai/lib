# Active Context

## Current Focus

Commit-push cycle complete for lib repo. All CI green on main.

## Recent Changes

- Added skill-integrity pre-commit hook (ciso10-integrity.py)
- Added markdownlint-cli2.yaml config
- Added workflow base templates (claude, stamp-marketplace, sync-skills, validate-plugins)

<!-- session @ 2026-04-15 shell-profile-fixes -->

- _(change | 2026-04-15)_ **lib-config.sh header completely rewritten**
  Corrected macOS myth (Terminal reads `.bash_profile`, not `.profile` directly); documented the login vs non-login shell gap; added flow diagrams for `_PROFILE_SOURCED` guard; clarified file roles table
- _(change | 2026-04-15)_ **Committed and pushed to lib main**
  Commit 7d63f72 — docs(lib-config): rewrite header comment with correct macOS chain, \_PROFILE_SOURCED guard explanation, and flow diagrams

<!-- delta merge @ 2026-04-24 18:17 UTC -->

- _(refactor | 2026-03-11)_ **Committed workflow template cleanup - moved disabled workflows to workflow.disabled directory**
  Successfully committed refactor that removes 542 lines and relocates disabled workflow templates to dedicated directory.
- _(refactor | 2026-03-11)_ **Detection logic now checks for include.mk instead of install-repo target**
  Build script now verifies Makefile includes standard library infrastructure rather than searching for target name
- _(refactor | 2026-03-11)_ **Simplified target detection using grep instead of make -q**
  Build script now uses grep to check for install-repo target instead of invoking make
- _(refactor | 2026-03-11)_ **Simplified DRY_RUN logic and switched to rsync in git-submodule-install-lib.sh**
  Refactored submodule installation script to use rsync and streamlined dry-run handling with unified flag
- _(refactor | 2026-03-11)_ **Replaced GNU install with rsync in install-repo target**
  Refactored include.mk install-repo to use rsync instead of GNU install, improving cross-platform compatibility
- _(refactor | 2026-03-10)_ **Replaced GNU install with rsync for conditional file copying**
  Simplified install-repo target by using rsync -u instead of custom bash timestamp checks
- _(refactor | 2026-03-10)_ **Simplified variable passing using exported environment variables**
  Replaced complex quoting with exported \_DEST and \_FORCE environment variables for cleaner bash -c script
- _(refactor | 2026-03-10)_ **Optimized directory file processing with find -exec batch mode**
  Changed from per-file execution to batch processing using find's {} + syntax for better performance
- _(refactor | 2026-03-10)_ **Refactored directory timestamp checking to use bash -nt operator**
  Directory file copying now uses bash -c with -nt operator instead of find's -newer predicate for consistency
- _(refactor | 2026-02-20)_ **Script renamed for clarity**
  git-submodule-add-git-files.sh renamed to git-submodule-install-lib.sh to better reflect its purpose of installing library templates
