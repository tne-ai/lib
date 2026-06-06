# `.devcontainer/` — the single AI environment definition

One definition, consumed two ways:

- **Locally:** open the repo in VS Code / Cursor → "Reopen in Container", or
  `docker compose -f .devcontainer/compose.yaml up`.
- **Cloud IDE (Phase 2):** the per-user workspace pod runs this same image
  (Coder/Devpod consume `devcontainer.json` natively).

Sidecars run on the canonical `make ai` ports (Postgres 5432, Redis 6379,
LiteLLM 4000, Temporal 7233 / UI 8233, MLflow 5001, KTAP 8630), so anything
that targets `localhost:<port>` behaves the same here and in the cloud.

**Status:** Phase 1 scaffold. `workspace` + `postgres` + `redis` are runnable
today; `litellm` and `temporal` are scaffolded but commented until their image
tags and LiteLLM routing config are aligned to the cloud (troopship build
configs + the shared LiteLLM config — see `check_litellm_config_parity`). This
is *not* built on `lib/Dockerfile.base` (a legacy PX4 image); it's the AI
toolchain `make ai` expects.

See `docs/cloud-ide-and-standardization.md` for the full design and phasing.
