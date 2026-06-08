#!/usr/bin/env bash
# ai-warn-bridges.sh — start subscription bridges; warn to auth if they fail.
# Called by: make ai (via ai-warn-bridges target)
# Governed by: r-cto-dev136-default-path-warn (non-blocking warnings only)
set -o pipefail

KIMI_PORT="${KIMI_CLAUDE_PROXY_PORT:-3457}"
CLIPROXY_PORT="${CLIPROXYAPI_PORT:-8317}"
LOG_DIR="${TNE_LOG_DIR:-$HOME/ws/logs}"
mkdir -p "$LOG_DIR"

# ── Kimi bridge (claude-code-proxy) ──────────────────────────────────────────
if ! nc -z localhost "$KIMI_PORT" 2>/dev/null; then
    echo "  → kimi bridge (:$KIMI_PORT) not running — starting..."
    if ! command -v claude-code-proxy >/dev/null 2>&1; then
        echo "  ⚠️  claude-code-proxy not installed — run: install-ai.sh"
    else
        # Auth check: claude-code-proxy stores session in ~/.config/claude-code-proxy/
        if [[ ! -d "$HOME/.config/claude-code-proxy" ]] || \
           [[ -z "$(ls -A "$HOME/.config/claude-code-proxy" 2>/dev/null)" ]]; then
            echo "  ⚠️  kimi not authenticated — run: make ai-auth PROVIDER=kimi"
        else
            PORT="$KIMI_PORT" nohup claude-code-proxy serve </dev/null \
                >"$LOG_DIR/kimi-proxy.log" 2>&1 &
            sleep 2
            if nc -z localhost "$KIMI_PORT" 2>/dev/null; then
                echo "  ✓  kimi bridge started"
            else
                echo "  ⚠️  kimi bridge not up — last log lines:"
                tail -5 "$LOG_DIR/kimi-proxy.log" 2>/dev/null | sed 's/^/       /'
                echo "       Fix: make ai-auth PROVIDER=kimi"
            fi
        fi
    fi
fi

# ── Gemini/Codex bridge (cliproxyapi) ────────────────────────────────────────
if ! nc -z localhost "$CLIPROXY_PORT" 2>/dev/null; then
    echo "  → gemini/codex bridge (:$CLIPROXY_PORT) not running — starting..."
    if ! command -v cliproxyapi >/dev/null 2>&1; then
        echo "  ⚠️  cliproxyapi not installed — run: install-ai.sh"
    else
        # Auth check: cliproxyapi stores session in ~/.cli-proxy-api/
        if [[ ! -d "$HOME/.cli-proxy-api" ]] || \
           [[ -z "$(ls -A "$HOME/.cli-proxy-api" 2>/dev/null)" ]]; then
            echo "  ⚠️  gemini/codex not authenticated — run: make ai-auth PROVIDER=gemini"
        else
            nohup cliproxyapi -config "$HOME/.config/cliproxyapi/config.yaml" </dev/null \
                >"$LOG_DIR/sidecar-${CLIPROXY_PORT}.log" 2>&1 &
            sleep 2
            if nc -z localhost "$CLIPROXY_PORT" 2>/dev/null; then
                echo "  ✓  gemini/codex bridge started"
            else
                echo "  ⚠️  gemini/codex bridge not up — last log lines:"
                tail -5 "$LOG_DIR/sidecar-${CLIPROXY_PORT}.log" 2>/dev/null | sed 's/^/       /'
                echo "       Fix: make ai-auth PROVIDER=gemini|codex"
            fi
        fi
    fi
fi

# ── Summary ──────────────────────────────────────────────────────────────────
nc -z localhost "$KIMI_PORT" 2>/dev/null \
    && nc -z localhost "$CLIPROXY_PORT" 2>/dev/null \
    && echo "  ✓  Subscription bridges: kimi :$KIMI_PORT  gemini/codex :$CLIPROXY_PORT" || true
