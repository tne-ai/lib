# Rich's Fine GitHub Actions default Workflows

The activated ones should end in .yaml to disable an action,
just add any other suffix, we use `.yaml.disabled` as a convention

This gets copied into your repo with `make install-repo` and you can modify

## Workflow inventory

| Workflow | Default state | Scope |
|----------|---------------|-------|
| `lint.workflow.yaml` | active | all repos — pre-commit + bats unit suite (on push/PR/tag) |
| `claude-review.yml` / `claude-security.yml` | active | all repos — Claude PR review + security |
| `claude.yml` / `claude-triage.yml` | active | all repos |
| `dependabot.automerge.workflow.yaml` | active | all repos |
| `stamp-marketplace.workflow.yaml` / `validate-plugins.workflow.yaml` / `sync-skills.yml` | active | plugin repos |
| `homebrew-formula-bump.workflow.yaml` / `trigger-formula-bump.workflow.yaml` | active | formula repos |
| `youtube-sync.yaml.disabled` | **disabled** | mktg only — enable with `mv youtube-sync.yaml.disabled youtube-sync.yml` |

Repo-specific workflows ship here as `*.yaml.disabled` so they distribute to every
repo (versioned, discoverable) but stay dormant until a repo renames them to enable.
This keeps `workflow.base/` a superset without spreading active repo-specific jobs
(r-cto-dev110 Law 3).
