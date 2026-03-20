# Adversarial Findings — empirica-extraction

## Family Round 1

### Synthesis (Mother)

The spec's architecture is sound: single JSON file, behavioral instructions, rolling
averages, fail-open hooks. Seven items genuinely need work, of which one is critical
(PostToolUse capture mechanism undefined) and four need spec changes.

### Analysis (Father)

Father confirmed 5 items need spec changes, 2 are acceptable risk. Key judgment:
the postflight submission problem is a **usage discipline constraint**, not an
engineering problem to solve. The system rewards users who close sessions with `/end`.
Confidence: 70% before changes.

### Historical Review (Elder Council)

All 5 proposed changes historically supported by vault evidence (9 relevant findings).
No contradictions found. One additional risk identified from historical deadlock analogue.

| Vault Source | Lesson | Relevance |
|---|---|---|
| 2026-03-19: 7-DB split-brain | Data fragmentation was worst flaw; single file is correct but needs atomic writes | supports |
| 2026-03-19: dual-table preflight bug | `epistemic_snapshots` is empty; migration must use `reflexes` for both phases | warns |
| 2026-03-13: MCP stdin hang | Implicit triggers create invisible failures; slash command is deterministic | supports |
| 2026-03-10: session-create resolver deadlock | Stale marker files deadlock lifecycle events; must overwrite, not fail | warns |
| 2026-03-06: postflight metadata bug | Column mismatches cause silent failures; JSON is self-documenting | supports |
| 2026-02-19: calibration hidden value | Data IS accumulating; the problem was surfacing it | supports |
| 2026-02-19: synthesis architecture | Dual-layer (machine+human) validated; reads bypass machine layer | supports |

**Elder Verdict:** CONVERGED
**Confidence:** 0.85

---

## Consolidated Findings

### F1: PostToolUse capture mechanism undefined (CRITICAL)

**Finding:** PostToolUse hooks receive tool call payloads, not Claude's prose. The spec
says capture hooks detect vectors "by scanning Claude's output" — this is not how
PostToolUse works. No trigger surface is defined for vector capture.

**Severity:** critical
**Convergence:** both-agreed (Challenger raised, Defender silent, Mother/Father/Elder all confirmed)
**Addressed:** needs-spec-update

**Resolution direction:** Define a slash command (e.g., `/preflight-submit`, `/postflight-submit`)
that Claude invokes with structured vector arguments. PostToolUse hook fires on the
command invocation. This is the deterministic trigger surface.

**Historical support:** 2026-03-13 stdin hang finding proves implicit triggers fail silently.

---

### F2: Atomic writes not specified (HIGH)

**Finding:** Section 4.5 code examples show raw `jq ... file` without temp-file-then-rename.
A mid-write crash destroys all calibration history in the single JSON file.

**Severity:** high
**Convergence:** both-agreed
**Addressed:** needs-spec-update

**Resolution direction:** All jq write operations must use: `jq '...' file > file.tmp && mv file.tmp file`.
Specify this as a required pattern, not an implementation choice.

**Historical support:** Two independent vault findings (project_scout heartbeat-v2, 7-DB split-brain).

---

### F3: Pairing rate mitigations not ranked (HIGH)

**Finding:** Four mitigations listed as if equivalent. Only `/end` command creates an
explicit user action; the rest are behavioral nudges. CLAUDE.md instructions are
"suggestions only" per the spec's own enforcement tiers. No realistic target stated.

**Severity:** high
**Convergence:** both-agreed
**Addressed:** needs-spec-update

**Resolution direction:** Rank mitigations. `/end` is the primary mechanism. State
50-60% as realistic target. Frame terminal-close as a structural constraint (usage
discipline), not a solvable engineering problem.

---

### F4: Stale `.current-session` marker deadlock (MEDIUM)

**Finding:** If a previous session crashes without cleanup, `.current-session` contains
stale data. The spec doesn't specify what SessionStart does when it finds an existing
marker file. Direct analogue: 2026-03-10 Empirica resolver deadlock.

**Severity:** medium
**Convergence:** newly-identified (Elder Council)
**Addressed:** needs-spec-update

**Resolution direction:** SessionStart hook MUST unconditionally overwrite `.current-session`.
A stale marker from a crashed session is always safe to overwrite — the crashed session
will never submit postflight vectors.

---

### F5: Migration schema unverified (MEDIUM)

**Finding:** The migration script assumes `reflexes` table has preflights and
`epistemic_snapshots` has postflights. The 2026-03-19 dual-table bug finding proves
`epistemic_snapshots` is effectively empty. Migration may produce 0 records.

**Severity:** medium
**Convergence:** both-agreed
**Addressed:** needs-spec-update

**Resolution direction:** Mark migration as tentative until schema verified. Query
`reflexes` for BOTH preflight and postflight phases. Specify JSONL fallback path.

---

### F6: Timing budget not enforced (MEDIUM)

**Finding:** SessionStart hook "must complete in < 2 seconds" but no `timeout` wrapper
specified. On WSL2/NTFS (user's platform), may silently exceed budget.

**Severity:** medium
**Convergence:** both-agreed
**Addressed:** needs-spec-update

**Resolution direction:** Wrap computation in `timeout 1.5s`. On timeout, exit 0
with minimal message. Include fast path for empty/missing `epistemic.json`.

**Historical support:** 2026-03-12 finding on missing subprocess timeouts in Empirica.

---

### F7: Behavioral template coverage gap (MEDIUM — ACCEPTED RISK)

**Finding:** 5 of 26 vector×direction combinations have specific templates. The
catch-all handles 62% of cases generically.

**Severity:** medium
**Convergence:** both-agreed
**Addressed:** already-accepted — reframe as "priority templates for highest-variance
vectors." Templates grow with observation data, not pre-built for all combinations.

---

### F8: `.current-session` worktree collision (LOW — ACCEPTED RISK)

**Finding:** Parallel worktrees with simultaneous Claude sessions would overwrite each
other's session markers. Single-user risk is low.

**Severity:** low
**Convergence:** challenger-only (Father assessed as acceptable risk)
**Addressed:** already-accepted — note limitation, specify future namespacing path.

---

## Edge Cases (Stage 4) — Family Round 1

### Synthesis (Mother)

"Defender's defenses are correct for the *output surface* (behavioral instructions).
Challenger's bugs are real at the *storage surface* (what gets written to JSON). Two
distinct safety layers; spec only fully defends one."

### Analysis (Father)

4 spec changes needed + 3 refinements. All small — no architectural changes. Confidence: 82%.

### Historical Review (Elder Council)

All 4 changes + 3 refinements supported by 8 vault analogues. Confidence: 0.90.

| Vault Source | Lesson | Relevance |
|---|---|---|
| 2026-03-18: compound-failures-family-mode | Silent failure + misleading success = worst class of bug | fail-loudly refinement |
| 2026-03-10: session-create-resolver-deadlock | Stale pointers pair wrong data | cross-session pairing fix |
| 2026-02-25: reloadappsettings-bug | Single null in pipeline causes silent failure | null propagation fix |
| 2026-02-19: calibration-hidden-value | Even partial data has value — don't over-suppress | null guard nuance |

**Elder Verdict:** CONVERGED — Confidence 0.90

---

### F9: Null propagation in jq arithmetic (HIGH)

**Finding:** Missing/non-numeric vectors produce `null` that propagates through `add/length`
computation. `null + 0.8 = null` in jq — one bad value poisons the entire rolling mean.

**Severity:** high
**Convergence:** both-agreed (Challenger raised, Mother/Father/Elder confirmed)
**Addressed:** needs-spec-update

**Resolution direction:** Add `select(. != null) | tonumber` filter to jq computation path.
Guard against empty arrays: `if length == 0 then 0 else add/length end`. Filter field-level
nulls, not entire records (preserve partial data).

**Historical support:** 2026-02-25 null deviceId bug, 2026-03-19 dual-table invisibility.

---

### F10: 0-byte file bypasses fast path (HIGH)

**Finding:** Fast path checks `-f` (exists) not `-s` (non-empty). A 0-byte file from a
WSL2/NTFS crash passes `-f`, hits jq on empty input, produces parse error. Calibration
injection silently fails on the primary development platform.

**Severity:** high
**Convergence:** both-agreed
**Addressed:** needs-spec-update

**Resolution direction:** Change predicate from `-f` to `-s` (exists AND non-empty).
Treat 0-byte file same as missing: trigger fast path, reinitialize.

**Historical support:** 2026-03-18 compound-failures finding (systems that look healthy while broken).

---

### F11: Cross-session delta pairing (HIGH)

**Finding:** "Latest unpaired session" heuristic can pair Monday's preflight with Tuesday's
postflight. The delta is semantically meaningless — measures context drift, not session
calibration. Poisons rolling average with cross-session noise.

**Severity:** high
**Convergence:** both-agreed (Challenger raised, Defender silent, all parents confirmed)
**Addressed:** needs-spec-update

**Resolution direction:** Strict session_id matching. `/epistemic-postflight` MUST look up
preflight by current session_id from `.current-session`, not by recency. If no matching
preflight exists, store postflight as unpaired — do NOT compute deltas.

**Historical support:** 2026-03-10 resolver deadlock (stale pointers pair wrong data).

---

### F12: Fail-loudly to stderr on tracking failure (MEDIUM)

**Finding:** Fail-open (exit 0) is correct for session continuity. But fail-*silent* means
users discover broken tracking only when calibration never appears after 5 sessions. If
`~/.claude/` is not writable, every session is unpaired with zero indication.

**Severity:** medium
**Convergence:** newly-identified (Father refinement, Elder confirmed)
**Addressed:** needs-spec-update

**Resolution direction:** Hooks exit 0 always (fail-open on session). But write warnings
to stderr when tracking components fail: "WARNING: .current-session write failed, session
will not be tracked." Claude sees stderr output and can surface it to the user.

**Historical support:** 2026-03-18 compound-failures ("misleading success signals are more
dangerous than crashes"), 2026-03-13 stdin-hang (silent failures persist for weeks).

---

### F13: Postflight against missing preflight (MEDIUM)

**Finding:** If `/epistemic-postflight` runs but no preflight exists for the current
session_id, the command should NOT compute deltas or increment observation_count. Currently
unspecified — could produce null deltas that inflate calibration counts with garbage.

**Severity:** medium
**Convergence:** both-agreed
**Addressed:** needs-spec-update

**Resolution direction:** Add explicit guard to `/epistemic-postflight`: if no matching
preflight for session_id, store postflight as standalone (for history), skip delta
computation, log to stderr.

---

### F14: `mkdir -p ~/.claude/` guard (LOW — REFINEMENT)

**Finding:** Hooks assume `~/.claude/` is writable. On first-run or WSL2 permission
issues, write to `.current-session` fails silently.

**Severity:** low
**Convergence:** Father identified as acceptable risk with one-line note
**Addressed:** refinement — add `mkdir -p ~/.claude/` to SessionStart hook

---

### F15: Double preflight submission (LOW — ACCEPTED RISK)

**Finding:** Claude invokes `/epistemic-preflight` twice in one session. Second invocation
overwrites first. Benign if overwrite semantics, problematic if insert-duplicate semantics.

**Severity:** low
**Convergence:** Challenger raised, Father assessed as acceptable risk
**Addressed:** already-accepted — overwrite is the correct default behavior. Note in spec.

---

## Pre-Mortem (Stage 4.5) — Operational Failures

### F16: `/end` command transition ordering (CRITICAL) [pre-mortem]

**Finding:** `/end` currently calls Empirica MCP tools. After deprecation (work unit 8),
those tools no longer exist. If `/end` is updated to add `/epistemic-postflight` but the
old Empirica calls aren't removed first, `/end` errors on missing MCP tools before
reaching the new postflight code. The PRIMARY pairing mechanism never fires.

**Severity:** critical
**Addressed:** needs-spec-update

**Resolution direction:** Specify `/end` transition as an explicit ordered procedure:
(a) remove Empirica MCP calls from `/end`, (b) add `/epistemic-postflight` invocation,
(c) test that `/end` completes without error. Work units 5c and 8 have a critical
ordering dependency — they cannot be independent tasks.

---

### F17: Pairing rate health check missing (HIGH) [pre-mortem]

**Finding:** "Insufficient data" is displayed identically whether the system is warming
up (expected) or broken (unexpected). After 10+ unpaired sessions there should be an
escalation: "WARNING: 0 of N sessions paired. Check that /end is working correctly."

**Severity:** high
**Addressed:** needs-spec-update

**Resolution direction:** Add to SessionStart hook: if `sessions` array has 10+
entries and 0 have `paired: true`, output warning to stderr. Distinguishes "warming up"
from "broken."

---

### F18: No smoke test script (MEDIUM) [pre-mortem]

**Finding:** No procedure to verify the system works after installation. The spec
lists success criteria but no automated way to check them.

**Severity:** medium
**Addressed:** needs-spec-update

**Resolution direction:** Add `scripts/epistemic-smoke-test.sh` — creates a mock
session, writes preflight, writes postflight, verifies `epistemic.json` has a paired
record with computed deltas. Run after installation.

---

### F19: No rollback procedure (MEDIUM) [pre-mortem]

**Finding:** Deprecation section (8.1) is one-way. If the new system fails, there's
no documented path to re-enable Empirica.

**Severity:** medium
**Addressed:** needs-spec-update

**Resolution direction:** Document rollback: (a) re-add `empirica` to `mcp.json`,
(b) restore Empirica hook wiring in `settings.json`, (c) new hooks remain on disk
but don't fire (harmless).

---

### F20: Deployment checklist missing (MEDIUM) [pre-mortem]

**Finding:** The spec lists files to create/modify but not a deployment procedure.
The transition requires atomic multi-step changes where partial deployment breaks
both old and new systems.

**Severity:** medium
**Addressed:** needs-spec-update

**Resolution direction:** Add deployment checklist to spec: ordered steps from
"install new files" through "verify smoke test" to "remove Empirica."
