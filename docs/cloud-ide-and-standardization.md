# Compass Cloud IDE & Local↔Cloud Environment Standardization

> Status: design + Phase-1 scaffold. Owner: platform. Audience: anyone running
> Compass locally (`make ai`) or operating the cloud (troopship/EKS).

## Goals

1. **One environment definition** that both a developer's laptop and the cloud
   consume — so "works on my machine" and "works in the cloud" stop diverging.
2. Make the cloud workspace a **first-class IDE**: persistent repos (with
   `.git`), terminals, dev servers, and the agent all on one durable filesystem.

These are two halves of the same thing: if the cloud IDE and the local dev
environment are built from the *same* definition, standardization is automatic.

## Where we are today

| Concern | Local | Cloud |
|---|---|---|
| Service stack | `make ai` (lib `include.ai.mk`) starts Postgres, Redis, LiteLLM, Temporal(+UI), MLflow, LLS as **native/brew sidecars** | the **same components** as k8s Deployments (orion-backend, litellm, svc-temporal, temporal-server, postgres/RDS, redis) via troopship/Flux |
| Provisioning | macOS + Homebrew + `make` | Kubernetes + Helm/Flux |
| Workspace | host filesystem | **S3-object-synced, `.git` stripped**, ephemeral per session |
| LLM routing | kimi-claude-proxy / cliproxyapi (subscriptions) + LiteLLM | LiteLLM → OpenRouter (no Anthropic key) |

**The drift is not the topology — it's the provisioning.** Local and cloud run
the same services on the same ports; they're just stood up two different ways,
with no shared definition. (`lib/Dockerfile.base` is *not* that definition — it's
a legacy PX4/drone image; the real AI env lives in `include.ai.mk`.)

## Target architecture

### A. The unifying artifact: an AI **devcontainer**
A single `.devcontainer/` (Dockerfile + `devcontainer.json` + a compose for the
sidecars) becomes the source of truth for the environment. It is consumed by:

- **Local dev** — VS Code / Cursor "Reopen in Container", or `docker compose up`.
- **CI** — same image.
- **The cloud IDE** — the per-user workspace pod runs the *same* image.

`devcontainer.json` is an open standard that **Coder** and **Devpod** consume
natively, so adopting one of those for the cloud IDE means local and cloud come
from one definition with minimal bespoke orchestration. (The team already has
Gitpod heritage — see `DEVELOPER.md` — so "one Dockerfile defines the workspace"
is a familiar model; this modernizes `.gitpod.Dockerfile` → `devcontainer.json`.)

### B. The cloud IDE: persistent workspace, not an S3 cache
- **Per-user EBS volume (RWO)** — a real filesystem; `.git`, `node_modules`, and
  build caches persist with correct semantics. (EFS rejected: small-file latency
  makes git/npm painful. S3-object-sync rejected: no locking/atomicity → `.git`
  corruption.)
- **Per-user workspace pod** mounting that volume, running the agent, terminal,
  and dev servers — the Codespaces model. RWO single-writer matches git's model
  and means agent + terminal + jobs **co-locate in one pod**.
- **Lifecycle**: lazy-provision; idle → scale pod to zero (volume persists);
  snapshot cold volumes to S3 and reclaim; rehydrate on return. Pre-warm a small
  pool to hide cold-start.
- **Previews**: dev servers run in the pod with dynamic `*.preview` ingress →
  the "Live tab" runs the real server, which fixes the isolated component-preview
  failures.

### C. Why this also kills the `.git`-loss problem
The cloud IDE's volume *persists `.git`*, so the "re-clone every session and lose
work" loop disappears at the source. The interim push-early discipline becomes
optional rather than required.

## Phasing

- **Phase 0 (interim):** push-early / resume-by-branch discipline (a prompt
  directive). Bridge only; closed once the IDE lands.
- **Phase 1 (this PR):** the AI **devcontainer** — the single env definition,
  Linux-native, running the `make ai` service topology as compose services.
  Developers get an identical-to-cloud environment today.
- **Phase 2:** stand up the cloud IDE on a devcontainer-native platform
  (Coder/Devpod) using the Phase-1 definition; per-user EBS volume + workspace
  pod. Stop stripping `.git` on the volume.
- **Phase 3:** move dev-server previews into the pod + dynamic preview ingress
  (Live tab real).
- **Phase 4:** run Temporal job activities against the volume; flip the volume to
  source-of-truth, S3 → snapshots; idle scale-to-zero + GC.

## Decisions / open questions

- **Build vs buy** the cloud-IDE orchestrator: strongly lean **buy/adopt**
  (Coder or Devpod) — they already solve volumes, ingress, idle-scaling, and
  devcontainer consumption.
- **RWO single-writer** ⇒ agent + terminal + jobs in one pod. Confirmed direction.
- **LiteLLM config parity**: the env definition must pull its LiteLLM config from
  the **same source** the cloud uses, or "standardized" envs still answer
  differently. (troopship already has `check_litellm_config_parity.yaml` — wire
  the devcontainer to the same config.)
- **Cost**: depends entirely on idle scale-to-zero + volume tiering.

## What ships in Phase 1 (this PR — see `.devcontainer/`)
A Linux-native devcontainer that brings up the core AI sidecars (Postgres,
Redis, LiteLLM, Temporal+UI) on the canonical `make ai` ports, plus the dev
toolchain (uv/Python 3.12, Node, gh, make, docker CLI). This is the first
concrete piece of "one definition, local + cloud." Exact service image tags and
the LiteLLM config are aligned to the cloud images (troopship build configs) as
a tracked follow-up.
