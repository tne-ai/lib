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
