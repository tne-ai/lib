## [2026-06-10] — include.ai.mk: 11-target public API + parameterize-over-proliferate

**Decision**: Reduce include.ai.mk from ~33 ai-\* targets to 11 public targets. Use PHASE=/SECTION=/ACTION= variables for multi-mode targets (ai-test, ai-status, ai-models, ai-logs). Retired targets become single-# stubs (hidden from help). Include.tne.mk deleted; archived to include.old.ai.mk.

**Context**: Too many overlapping ai-\* targets making discoverability poor and maintenance expensive.

**Rationale**: OOD (Law XII) — one target per verb. Parameterize-over-proliferate (Law XIII) — PHASE/SECTION/ACTION with default=all. Archived recipes stay in include.old.ai.mk with date+reason banners (Law XIV).

**Alternatives rejected**: Keep all targets; delete without archive; merge ai-run and ai-p.

**Implications**: Callers using ai-test-infra, ai-keys, ai-check-keys, ai-log, ai-open-force, ai-p, ai-local continue to work via tier-1 stubs.

---

## [2026-06-10] — Temporal persistent-DB fix via custom brew plist

**Decision**: Generate custom plist at TNE_DB_DIR/temporal/homebrew.mxcl.temporal-tne.plist with --db-filename and --ui-port baked in. Use brew services start --file=<plist>. Add brew services stop temporal to ai-stop.

**Context**: Homebrew launchctl auto-respawns temporal without flags, holding port 7233 before make temporal invocation. start_server sees port ready and silently skips the correctly-flagged call.

**Rationale**: Custom plist is the only reliable way to bake flags into brew services lifecycle.

**Implications**: Workflows persist across make ai-stop && make ai cycles. Regression check in ai-test-infra.
