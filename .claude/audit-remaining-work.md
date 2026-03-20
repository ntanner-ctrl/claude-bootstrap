# Audit Session — Remaining Work

Generated: 2026-03-19. Items deferred from the Obsidian+Empirica 30-day audit to make room for the epistemic system rebuild.

## Vault Curate (Ready to Execute)

Full inventory + triage targets dumped to: `.claude/vault-curate-handoff.md`

Key actions:
- **16 findings need triage**: 3 stale + 13 unassessed
- **Project name normalization**: ~15 notes have inconsistent project naming (project_scout vs project-scout vs S4 Scout vs s4-scout)
- **Malformed frontmatter**: 3-4 notes with broken or missing YAML
- **Pattern extraction**: 115 findings, 0 patterns — synthesis is overdue
- **Decision capture gap**: Only 3 decisions recorded, should be 20-30

Run `/vault-curate --quick` in a new session, point it at the handoff file.

## Orphan Reconciliation Session

Nick's proposal: dedicated session to un-orphan all possible disk findings using Obsidian session logs for context.

- **678 orphaned insights** across 5 `insights.jsonl` files
- Obsidian session logs (75 sessions, Feb 18 – Mar 19) can provide timestamp-based context matching
- The session should fire a holistic preflight+postflight pair since individual session deltas are lost
- Priority: try to adopt into Empirica DB first (or its replacement), dump remainder to Obsidian

**This work should wait until the new epistemic system is built** — no point adopting orphans into a system we're replacing.

## Empirica Multi-DB Consolidation

Once the new system is built with a single DB, consider:
- Importing the 27 paired sessions (pre+post vectors) from existing `reflexes` tables
- Importing 91 Bayesian belief records for calibration continuity
- Importing 87 DB findings + ~58 per-project findings

Details in: `.claude/empirica-extraction-handoff.md`

## Obsidian Process Improvements (from audit findings)

These are clear wins independent of the Empirica rebuild:

1. **Add `/vault-curate` to periodic workflow** — monthly cadence based on decay rate
2. **Normalize project names** — pick canonical names, batch-fix frontmatter
3. **Start capturing decisions** — 3 recorded vs 20-30 actual decisions made
4. **Start extracting patterns** — 0 patterns from 115 findings is a gap
5. **Add `last_reviewed` dates** — even to skipped notes, so future curations know what's triaged vs untouched
