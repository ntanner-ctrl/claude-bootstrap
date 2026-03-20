# Specification Revision History

## Revision 1 (initial)
- Created: 2026-03-19T11:10:00Z
- Sections: 12 (Overview through Future Work)
- Work Units: 10

## Revision 1 → Revision 2
- Trigger: F1 (critical) — PostToolUse hooks cannot capture prose output
- Date: 2026-03-19T11:32:00Z
- Sections added: None
- Sections modified:
  - **4.5 (Implementation)** — Added REQUIRED atomic write pattern (temp-file-then-rename).
    Code examples corrected from dangerous in-place writes to safe pattern. [F2]
  - **5.1 (SessionStart Hook)** — Added stale marker overwrite behavior [F4], timeout
    enforcement via `timeout 1.5s` with fast path for missing file [F6]
  - **5.2 (SessionEnd Hook)** — Ranked pairing rate mitigations by effectiveness.
    `/end` integration elevated to PRIMARY. Realistic 50-60% target stated. [F3]
  - **5.3 (Vector Capture)** — REPLACED PostToolUse hooks with slash commands
    (`/epistemic-preflight`, `/epistemic-postflight`). Added hook-to-command
    integration diagram. [F1 — critical fix]
  - **5.4 (Hook-to-Command Integration)** — NEW subsection showing the complete
    lifecycle: hooks handle events, commands handle data capture. [F1]
  - **6.1 (CLAUDE.md)** — Updated to reference slash commands instead of prose submission.
  - **7.1 (Migration)** — Marked schema as tentative. Added JSONL fallback path.
    Query `reflexes` for both phases (not reflexes + epistemic_snapshots). [F5]
  - **9 (File Inventory)** — Updated: 2 hooks + 2 commands replaces 4 hooks. Added
    `commands/end.md` to modified files.
  - **10 (Work Units)** — Restructured: units 5a/5b/5c replace unit 5. Total now 12.
- Sections removed: None
- Sections unchanged: 1 (Overview), 2 (Data Model), 3 (Vectors), 4.1-4.4 (Computation),
  8 (Deprecation), 11 (Success Criteria), 12 (Future Work)
- Adversarial findings addressed: 6/8 (F1-F6 fixed, F7-F8 accepted risk)
- Work units affected: 4, 5 (split to 5a/5b/5c), 6, 7, 9, 10

## Revision 2 → Revision 3
- Trigger: Edge cases (F9-F15) + pre-mortem (F16-F20)
- Date: 2026-03-19T12:10:00Z
- Sections modified:
  - **1.1 (Design Principles)** — "Fail-open everywhere" → "Fail-open, fail-loudly".
    Hooks exit 0 always but write warnings to stderr. [F12]
  - **4.5 (Implementation)** — Added REQUIRED null-safe computation pattern:
    `select(. != null) | tonumber` + empty array guard. [F9]
  - **5.1 (SessionStart Hook)** — Added `mkdir -p` guard [F14], pairing rate health
    check (warn after 10+ unpaired) [F17], fail-loudly on write failure [F12],
    fast path changed from `-f` to `-s` (catches 0-byte files) [F10]
  - **5.3 (/epistemic-preflight)** — Added double-submission overwrite semantics [F15]
  - **5.3 (/epistemic-postflight)** — Strict session_id pairing replaces "latest
    unpaired" heuristic [F11]. Added explicit guard for missing preflight [F13].
  - **8 (Deprecation)** — Replaced with ordered deployment procedure: update /end
    FIRST, then deprecate Empirica [F16]. Added rollback procedure [F19].
    Added smoke test dependency [F18, F20].
  - **9 (File Inventory)** — Added `scripts/epistemic-smoke-test.sh` [F18]
  - Work graph: added smoke-test unit (8a), deprecation now depends on smoke-test
- Sections unchanged: 2 (Data Model), 3 (Vectors), 4.1-4.4 (Computation logic),
  6 (CLAUDE.md), 7 (Migration), 10 (Work Units table), 11 (Success Criteria),
  12 (Future Work)
- Adversarial findings addressed: 20/20 (F1-F6 in rev 2, F7-F8 accepted risk,
  F9-F15 edge cases in rev 3, F16-F20 pre-mortem in rev 3)
- Work units affected: 4, 5b, 8 (renamed + new dependency), new unit 8a
