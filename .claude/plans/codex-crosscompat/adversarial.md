# Adversarial Findings: codex-crosscompat

## Challenge Stage (Critique Mode, Full Tier)

### Round 1 (Revision 0 → REWORK verdict)

30 raw findings → 18 consolidated. 3 critical, 8 high, 5 medium, 2 low.
Zero rebuttals in Clash phase. All findings addressed in revision 1.

**Key discoveries:**
- CF-1: Adapter contract was unnecessary — hooks.json uses identical schema (validated by ground truth)
- CF-2: Security compensation was architecturally non-viable (Stop-hooks can't replicate pre-gate approval)
- CF-3: TOML agent format was completely wrong (agents use plain markdown + openai.yaml)

All 18 findings addressed in revision 1. See `spec.diff.md` for full resolution mapping.

### Round 2 — Revalidation (Revision 1 → READY verdict)

12 raw findings across 3 lenses → 9 consolidated. 1 critical, 4 high, 2 medium, 2 low.
All addressed inline in revision 2.

| ID | Finding | Severity | Source | Resolution |
|----|---------|----------|--------|------------|
| RV-1 | plugin.json missing `hooks` field | critical | M1 | Added to WU5 description |
| RV-2 | PostToolUse Edit\|Write hooks ARE portable (Figma confirms) | high | M2 | Reclassified 4 hooks as ✓ direct; security degradation 7→3 |
| RV-3 | hooks.json needs relative paths for plugin mode | high | M3 | Path rewriting rules updated to use `./hooks/` |
| RV-4 | WU9 missing from dependency graph | high | H2, H3 | Added WU5→WU9, WU9→WU6, WU9→WU7 edges; critical path recalculated |
| RV-5 | codex/skills/ is ghost directory | high | C1, H1 | Deferred to v2; removed from What Changes |
| RV-6 | stderr vs stdout feedback channel unresolved | high (false-known) | C3 | Flagged as explicit WU3 validation step with fallback |
| RV-7 | openai.yaml cardinality ambiguous | medium | C4, M4 | Resolved: single file per plugin (Figma convention) |
| RV-8 | Stale WU5 reference in AGENTS.md section | low | C2 | Fixed to WU4 |
| RV-9 | protect-claude-md double-counted in degradation table | low | H4 | Annotated: 3 PreToolUse hooks (excluding protect-claude-md, separately listed) |

### Post-Challenge: Complexity Check

The spec was simplified through revision, not complicated:
- 11 WUs → 9 WUs (eliminated unnecessary adapter and behavioral WUs)
- Critical path: 6 → 4 (shorter)
- 7 blocked hooks → 3 blocked hooks (4 reclassified as portable via ground truth)
- _codex-adapter.sh eliminated entirely
- All open questions resolved

No overcomplexity concern.

## Edge Cases Stage (Critique Mode, Full Tier)

22 raw findings → 12 consolidated. 3 critical, 3 high, 5 medium, 1 low.
All addressed inline in spec revision 2→3.

| ID | Finding | Severity | Resolution |
|----|---------|----------|------------|
| EC-1 | Path rewrite scope too narrow — hooks contain `~/.claude/epistemic.json`, `.current-session`, etc. | critical | Broadened: `~/.claude/` → `~/.codex/` globally in hook scripts |
| EC-2 | hooks.json success criterion contradicts relative path rule | critical | Fixed: criterion now checks for `./hooks/` relative form |
| EC-3 | plugin.json nested in `.codex-plugin/` breaks relative `./hooks.json` reference | critical | Flattened: `codex/plugin.json` alongside `codex/hooks.json` |
| EC-4 | Blank lines after frontmatter strip cause duplicate H1 headers | high | Added: strip leading blank lines + widen scan to 5 lines |
| EC-5 | "7 blocked hooks" count inconsistent — actually 3 blocked, 3 adapted, 2 lost | high | Reconciled with named hooks everywhere |
| EC-8 | No working-directory contract — silent empty output from wrong CWD | high | Added: `$(dirname "$0")/..` anchor + preflight file count check |
| EC-6 | Agent `tools:` field silently dropped — 6 lens agents lose sandbox | medium | Added to Security Degradation Summary |
| EC-7 | `commands/README.md` needs exclusion filter | medium | Added: skip README.md, use non-recursive glob |
| EC-9 | `SAIL_DISABLED_HOOKS` bleeds between Claude/Codex | medium | Documented as known limitation |
| EC-10 | `commands/templates/` must use non-recursive glob | medium | Specified: `commands/*.md` non-recursive |
| EC-11 | `statusLine` key must be excluded from hooks.json extraction | medium | Added to WU3: extract only `hooks` key |
| EC-12 | WU3/WU4 path rewriting scope overlap risk | medium | Specified: WU3 owns hook scripts, WU4 owns AGENTS.md |

## Pre-Mortem Findings [pre-mortem]

5 NEW operational findings (3 COVERED already in adversarial):

| ID | Finding | Severity | Operational Domain |
|----|---------|----------|--------------------|
| PM-1 [pre-mortem] | Staleness check only in test.sh, not on install/failover path | high | Maintenance |
| PM-2 [pre-mortem] | install-codex.sh overwrites user-customized hooks without backup | high | Deployment |
| PM-4 [pre-mortem] | Codex CLI version drift — hooks.json may break on auto-update | high | Updates |
| PM-6 [pre-mortem] | Enforcement language expectations not reset in AGENTS.md | medium | Documentation |
| PM-8 [pre-mortem] | Divergence tracking empty on day one — useless when first needed | medium | Observability |

Cross-cutting pattern: opt-in checks fail under the time pressure that defines the primary use case (rate-limit failover).
