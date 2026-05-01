# Specification Revision History

## Revision 0 (initial)
- Created: 2026-03-28T01:52:00Z
- Sections: Summary, What Changes, Preservation Contract, Architecture, Work Units (11), Success Criteria, Failure Modes, Rollback, Dependencies, Open Questions, Senior Review
- Work Units: 11

## Revision 0 → Revision 1
- Trigger: REWORK verdict from critique pipeline (3 critical, 8 high, 5 medium, 2 low findings) + Codex ground truth inspection
- Date: 2026-03-28T03:30:00Z

### Sections added
- **Codex Ground Truth** — validated format/path/schema facts from installed v0.117.0
- **Security Degradation Summary** — explicit table of lost guarantees with severity (CF-12 resolution)
- **YAML Frontmatter Stripping Algorithm** — specified algorithm with edge case handling (CF-8/M6 resolution)
- **CLAUDE.md → AGENTS.md Conversion mapping** — section-by-section mapping (CF-10/C9 resolution)
- **Path rewriting rule** with `CODEX_INSTALL_ROOT` variable (CF-4/M7/M10 resolution)

### Sections modified
- **Summary** — 66 commands → 65; added Codex version pin; reframed output format
- **What Changes** — removed `.gitignore` row (D1 resolved); added plugin.json, skills/, openai.yaml
- **Architecture** — compiler pipeline redrawn for actual Codex formats; removed _codex-adapter.sh
- **Hook Portability Matrix** — added resume matchers per D4; worktree-cleanup startup-only (safety); updated Codex event mapping
- **Compensation Strategy** — removed stop-verifier (non-viable per CF-2); replaced with "no equivalent, accepted degradation"
- **SessionEnd → Stop Adaptation** — replaced "check recent turns" heuristic with marker-file protocol (CF-6/C4)
- **Behavioral Adapter Rules** — marked entire table as HYPOTHETICAL; removed false-confidence framing (CF-13/C10)
- **Work Units** — 11 → 9; redesigned WU2 (no TOML), WU3 (path rewrite only), merged WU4 (single AGENTS.md owner); removed WU8 (behavioral adapter WU); added plugin manifest WU
- **Success Criteria** — 75 → 84 checks; added content staleness detection via sha256 manifest (CF-11); added openai.yaml validation
- **Open Questions** — all 8 resolved (5 from rev 0 + 3 from ground truth)

### Sections removed
- None

### Sections unchanged
- Rollback Plan (trivially correct — all additive)
- External Dependencies

### Adversarial findings addressed: 18/18

| Finding | Resolution |
|---------|-----------|
| CF-1 (adapter contract) | Eliminated — hooks.json uses identical schema, no adapter needed |
| CF-2 (security compensation) | Restructured — single AGENTS.md owner (WU4), no stop-verifier, explicit degradation table |
| CF-3 (TOML agents) | Eliminated — ground truth confirms plain markdown + openai.yaml |
| CF-4 (install root) | Resolved — CODEX_INSTALL_ROOT = ~/.codex/ |
| CF-5 (lint gap) | Eliminated — _codex-adapter.sh removed entirely |
| CF-6 (session semantics) | Rewritten — marker-file protocol, impossible heuristic removed |
| CF-7 (WU8 optional) | Eliminated — behavioral adapter WU removed, pass-through by default |
| CF-8 (frontmatter algorithm) | Added — explicit stripping algorithm with edge case handling |
| CF-9 (matrix vs D4) | Fixed — matrix updated with correct matchers per D4 |
| CF-10 (CLAUDE.md ambiguity) | Specified — this repo's .claude/CLAUDE.md, section mapping table |
| CF-11 (success criteria) | Fixed — 84 checks, sha256 staleness detection |
| CF-12 (parity framing) | Reframed — "structural parity with documented security degradations" |
| CF-13 (behavioral table) | Marked — HYPOTHETICAL, confidence annotations added |
| CF-14 (.gitignore row) | Removed — row dropped from What Changes |
| CF-15 (hooks.json events) | Fixed — only mapped events listed in success criteria |
| CF-16 (WU5 TDD) | Restructured — compensation rules folded into WU4 (tdd:true) |
| CF-17 (concurrent runs) | Added — atomic output via temp dir + mv |
| CF-18 (command count) | Fixed — 65, not 66 |

### Work units affected
- WU1: unchanged
- WU2: redesigned (TOML → openai.yaml generation)
- WU3: simplified (adapter removed, path rewriting only)
- WU4: restructured (sole AGENTS.md owner, includes compensation rules)
- WU5: new (plugin manifest)
- WU6: renumbered (was WU7)
- WU7: renumbered (was WU9)
- WU8: renumbered (was WU10)
- WU9: renumbered (was WU11), atomic output added
- Old WU5 (stop-verifier): eliminated
- Old WU8 (behavioral adapter): eliminated
