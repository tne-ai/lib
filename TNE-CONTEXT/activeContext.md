## Current Focus

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1 | ai-provider-fixes | **Active** | PLAN/PAYG audit, MINIMAX_PLAN_KEY, lls-start fix, billing docs |

## Open Blockers

- GLM/Z.ai: LiteLLM must be restarted after key rotation to pick up current Z_AI_PLAN_KEY
- Qwen coding plan: Alibaba $50/mo bundle not yet available; Qwen only via OpenRouter

## Active Decisions

- Z_AI_PLAN_KEY and Z_AI_API_KEY are the same key — billing determined by endpoint, not key
- MINIMAX_PLAN_KEY loaded from "coding plan key" field in "MiniMax API Key Dev" 1Password item
- DeepSeek is PAYG-only (no plan exists); keep direct key for cheap flash inference
- Kimi routed via claude-code-proxy (:3457), not CCR — removed dead kimi CCR provider entry
- OpenRouter not gated by CODEX_CHATGPT — only OPENAI_API_KEY needs that gate
