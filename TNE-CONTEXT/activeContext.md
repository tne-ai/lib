## Current Focus

| #   | Task                                                 | Status     | Notes                                                                                                                      |
| --- | ---------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------- |
| 12  | include.ai.mk refactor — 11 targets + archive tne.mk | **Active** | Worktree: refactor-ai-targets-11. Branch: refactor/ai-targets-11-and-archive-20260606. In progress — interrupted mid-edit. |
| 11  | Fix temporal in-memory startup                       | **Active** | PR #105 open (lib). Temporal plist fix already in include.ai.mk. Waiting for merge.                                        |
| 9   | Make all cloud AI models work via LiteLLM            | **Active** | PR #106 open (src envrc ALIBABA_PLAN_KEY fix).                                                                             |

## Open Blockers

- GLM/Z.ai: LiteLLM must be restarted after key rotation to pick up current Z_AI_PLAN_KEY
- Qwen coding plan: Alibaba $50/mo bundle not yet available; Qwen only via OpenRouter
- include.ai.mk refactor: interrupted mid-Python-edit; worktree at `.worktree/refactor-ai-targets-11` has partial changes — need to resume and verify all 6 modifications applied correctly before committing

## Active Decisions

- Z_AI_PLAN_KEY and Z_AI_API_KEY are the same key — billing determined by endpoint, not key
- MINIMAX_PLAN_KEY loaded from "coding plan key" field in "MiniMax API Key Dev" 1Password item
- DeepSeek is PAYG-only (no plan exists); keep direct key for cheap flash inference
- Kimi routed via claude-code-proxy (:3457), not CCR — removed dead kimi CCR provider entry
- OpenRouter not gated by CODEX_CHATGPT — only OPENAI_API_KEY needs that gate
- 11 public ai-\* targets confirmed: ai, ai-run, ai-stop, ai-install, ai-auth, ai-status, ai-test, ai-models, ai-logs, ai-open, ai-server
- PHASE=/SECTION=/ACTION= parameterization pattern for ai-test/ai-status/ai-models/ai-logs
- kimi-claude and kimi-claude-login deleted (superseded by ai-run MODEL=kimi-\*)
- include.tne.mk deleted; archived to include.old.ai.mk (all 40 targets deprecated)
- Law XIV (Discoverable Deprecation): tier-1 stubs use single # (hidden from help); archived recipes in include.old.ai.mk
