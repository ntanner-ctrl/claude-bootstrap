# Specification Revision History

## Revision 1 (initial)
- Created: 2026-04-30
- Sections: Architecture, Schema, Sweep Logic, /end Integration, Stock Templates, Hookify Integration, Documentation, Three Starter Entries, Work Units, Acceptance Criteria, Test Strategy, Risks, Open Questions
- Work Units: 7 (WU3 high-complexity)
- Backup: `spec.md.revision-1.bak`

## Revision 1 → Revision 2

**Trigger:** Vanilla challenge stage (Stage 3) found 2 critical + 4 lower-severity findings.
Verdict: REWORK. Regression to Stage 2.

**Date:** 2026-04-30

**Changes by finding:**

| Finding | Severity | Section affected | Change |
|---------|----------|-----------------|--------|
| F1 | critical | Hookify Integration → **Shell Hook Integration** | Replaced section. WU6 pivoted from `hookify-rules/hookify.unsafe-atomic-write.local.md` (would never fire — `event: write` not supported, only `event: bash`) to `hooks/anti-pattern-write-check.sh` PreToolUse on Write/Edit. WU6 complexity bumped Low→Medium. |
| F2 | critical | Sweep algorithm step 3 | Added `EXCLUDE_PATHS` filter: `.claude/anti-patterns/`, `.claude/plans/`, `commands/templates/stock-anti-patterns/`, vault mirror. Catalog entries' `fixture_bad` blocks were self-matching. |
| F3 | high | Three Starter Entries | Dropped `bash-silent-error-suppression` (multi-line detection requires schema extension `detection_kind: regex|awk|external-script`, deferred to v2). Replaced with `bash-rm-rf-with-variable` (single-line regex, exercises `recent_hits=0` path). |
| F4 | medium | Sweep algorithm — new step 5a | Added 10000-line cap on `.events.jsonl`: when exceeded, archive oldest 5000 to `.events.archive.jsonl`, truncate active log. |
| F5 | medium | Sweep algorithm step 6 | Added helper-or-fallback path: source `epistemic_safe_swap` if available, else use inline non-empty + valid-frontmatter validation. |
| F6 | low | WU3 estimate | Bumped 90 min → 150 min (informational, no functional change). |
| F7 | low | WU5 description | Made "file-level copy-if-not-exists" explicit (was ambiguous between dir-level and file-level). |
| F8 | low | (not addressed) | `recent_window_days = 60` default deferred to v2 (project-level config). |

**Sections added:**
- Sweep step 5a: Events log cap

**Sections modified:**
- Sweep step 3: EXCLUDE_PATHS
- Sweep step 6: helper-or-fallback for safe-swap
- Hookify Integration → Shell Hook Integration (full section replacement)
- Three Starter Entries: entry 2 swapped
- Work Units table: WU3, WU5, WU6, WU7 amended

**Sections unchanged:**
- Architecture overview
- Catalog Entry Schema
- Performance budget, fail-open semantics
- /end integration block
- Documentation, Acceptance Criteria, Test Strategy, Risks (some entries refined inline)

**Adversarial findings addressed:** 6/8 (F6, F8 deferred as informational/v2 concerns).

**Work units affected:**
- WU3: estimate bump, EXCLUDE_PATHS added, events cap added, safe-swap fallback added
- WU5: file-level copy semantics specified
- WU6: pivoted from hookify rule to shell hook (file path changed; complexity bumped)
- WU7: hook-firing fixture added to test plan
