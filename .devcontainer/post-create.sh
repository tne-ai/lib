#!/usr/bin/env bash
# Runs once after the devcontainer is created. Keep it idempotent and fast —
# heavy/optional setup belongs behind explicit `make` targets.
set -euo pipefail

echo "==> TNE AI devcontainer post-create"
echo "    uv:   $(uv --version 2>/dev/null || echo 'missing')"
echo "    node: $(node --version 2>/dev/null || echo 'missing')"
echo "    gh:   $(gh --version 2>/dev/null | head -1 || echo 'missing')"

# Sidecars are reachable by service name; surface the canonical endpoints so
# they match what `make ai` exposes on the host.
cat <<'EOF'

Environment ready. Sidecars (same ports as `make ai`):
  postgres  postgres:5432   (DATABASE_URL is set)
  redis     redis:6379      (REDIS_URL is set)
  litellm   :4000           (enable in compose.yaml once tag/config aligned)
  temporal  :7233 / UI 8233 (enable in compose.yaml once version aligned)

Next: see docs/cloud-ide-and-standardization.md
EOF
