# Describe: vault-curate

## Summary

Create `/vault-curate` — a new slash command providing interactive, multi-stage knowledge triage for the Obsidian vault. Subsumes `/review-findings` (deprecated alias). Extends coverage from findings-only to entire vault (findings, blueprints, ideas, sessions, decisions). Integrates Empirica calibration data. Self-tuning frequency recommendations.

## Steps

1. Create `commands/vault-curate.md` — the new 6-stage command (Inventory → Health Check → Triage → Synthesis → Prune → Report)
2. Update `commands/review-findings.md` — deprecate, redirect to `/vault-curate --quick --section findings`
3. Update `commands/README.md` — add vault-curate, update review-findings entry
4. Update `README.md` — add vault-curate to Commands at a Glance, update command count (45→46)
5. Update `.claude/CLAUDE.md` — update command count (45→46)
6. Update `install.sh` — update command count in output message
7. Update references in other commands that mention `/review-findings`

## Risk Flags

- User-facing behavior change (deprecating /review-findings)

## Triage

- **Steps:** 7
- **Risk flags:** 1
- **Path:** Full
- **Execution preference:** Simplicity (sequential)

## Prior Art

- Brainstorm session: Approach C selected (tiered single command with --quick bypass)
- Idea note: `Ideas/2026-02-20-review-findings-interactive-knowledge-triage.md`
- Related findings:
  - `2026-02-19-cross-project-synthesis-gap.md`
  - `2026-02-19-empirica-obsidian-synthesis-architecture.md`
- Current vault structure: 62 notes across Engineering/{Findings,Blueprints,Decisions,Patterns}, Ideas, Sessions
