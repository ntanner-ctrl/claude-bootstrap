# Specification Revision History

## Revision 1 (initial)

- **Created:** 2026-05-01T14:45:00Z
- **Sections:** Summary, Classification, What Changes (Files/Deps/State), Preservation Contract, Success Criteria (18 ACs), Failure Modes, Rollback Plan, Dependencies, Open Questions (4 resolved), Senior Review, Decisions, Work Units (12 WUs)
- **Work Units:** 12
- **Confidence at completion:** 0.85

## Revision 1 → Revision 2

- **Trigger:** Stage 3 critique surfaced 5 compound failure modes; user reframed CF-1's threat model from "containment" to "scope guardrail"
- **Date:** 2026-05-01T15:10:00Z
- **Regression source:** challenge → specify
- **Adversarial findings addressed:** 30 catalogued in adversarial.md; ~12 substantive spec changes carried forward into rev2

### Sections added

- New section: "Threat Model" — explicit framing for why the per-agent allowlist exists (scope guardrail catching agent confusion, not security containment)
- New section: "Per-Runner Exit Code Handling" — table per runner (pytest, bun, cargo, go, npm, bash test.sh) with exit codes, meanings, classification consequences
- New section: "Migration from Existing Prism Installations" — explicit upgrade contract for wizard state schema
- New ACs: AC19-AC25 (orchestrator context bound, exit-code-correctness, binary-missing detection, output-streaming flags forced, skip telemetry, multi-classification tiebreak, zero-failures behavior)

### Sections modified

- **Summary:** "containment via per-agent Bash allowlist" → "scope guardrail via per-agent allowlist"; reflects scope/intent declaration framing
- **Classification (5 categories):** unchanged (preserved-resolution); language polished
- **Preservation Contract:**
  - REMOVED false claim "All 11 existing prism agents (6 lens + 5 domain reviewer) remain read-only"
  - REPLACED with accurate claim: "All 6 lens agents remain read-only (Read/Glob/Grep). All 6 reviewer agents declare Bash in tools but do not actively reference Bash usage in their prompts (effectively read-only via prompt discipline; this blueprint does not modify them)."
  - ADDED: clarification of dangerous-commands.sh's role as the universal safety layer for ALL Bash calls (existing, unchanged)
- **Success Criteria:**
  - AC15 rewritten — now verifies orchestrator-context token impact via measurable fixture, not just "findings appear in synthesis"
  - AC14 clarified — distinguishes "PreToolUse hooks fire for subagents" (general, verified 2026-05-01) from WU12's "new prism-bash-allowlist.sh hook fires for test-debt-classifier dispatch" (specific, to-be-verified)
- **Failure Modes:**
  - Pytest exit codes corrected (rc=1 for failures, not rc=2; rc=5 = no tests collected, not collection error)
  - Added row: runner-exits-0-but-tests-failed silent failure (parse output for FAIL/FAILED patterns when rc=0)
  - Added row: runner-detected-but-binary-missing (precheck `command -v <runner>`; classify as test-infrastructure-broken with explicit reason)
  - Added row: hostile-repo child-process invisibility (acknowledge limitation; SAIL_PRISM_RUN_TESTS=0 is the user-side mitigation; not a containment claim)
- **Decisions table:**
  - Reframed "Hook architecture" decision — from "containment via separate hook" to "scope guardrail via separate hook"
  - Removed bypass-resistance / metacharacter-parsing requirement
  - Added: "Liveness mechanism" decision — Bash tool's built-in `timeout` parameter (no heartbeat; fail-on-timeout classified as test-infrastructure-broken)
  - Added: "Detection priority" decision — language-primary heuristic (count files by extension) instead of speed-priority; binary-missing precheck
  - Added: "Token budget" decision — explicit 2K bound on subagent return-message; agent prompt enforces; AC verifies via fixture
- **Open Questions resolutions:**
  - Q1 (timeout policy) updated — Bash-tool-timeout instead of heartbeat
  - Q4 (token budget) tightened — explicit 2K bound; prompt cap; measurable AC
- **Open Questions added:** Q5 (per-project override for global SAIL_PRISM_RUN_TESTS=0; deferred to v2 with rationale)
- **Senior Review Simulation:** added "non-obvious risk" entries for the threat-model reframe and the H1-style false-invariant pattern
- **Work Units:**
  - WU1 prompt content updated: 5-category classifier, agent-output cap, no-recursion notice, single-retry behavior, zero-failures behavior, per-runner exit-code expectations, output-format spec (≤2K total return)
  - WU2 simplified: substring-prefix allowlist match (no metacharacter parsing); fail-open; agent_type dispatch; clear scope-violation error message
  - WU3 reworked: language-primary detection heuristic; binary-missing precheck
  - New WU13: per-runner exit-code-handling spec for all 6 runners (table-driven dispatch in agent prompt)
  - WU4 dependencies updated to reflect WU13
  - WU9 (test.sh) expanded: AC19-AC25 coverage
  - WU10 (evals) expanded: 4 → 6 fixtures (add binary-missing, runner-exit-0-with-failures cases)

### Sections removed

- "Hook v1 vs frontmatter-driven allowlist" sub-decision dropped — moot under scope-guardrail framing; case-statement is fine indefinitely without refactor pressure

### Sections unchanged

- Classification (5 categories) — preserved-resolution
- Stage 5.5 position — preserved-resolution
- Separate hook (not modifying dangerous-commands.sh) — preserved-resolution
- Opt-OUT default via SAIL_PRISM_RUN_TESTS=0 — preserved-resolution
- v1 scope discipline (failures-only) — preserved-resolution

### Work units affected

- Renamed: `test-debt-reviewer` → `test-debt-classifier` (everywhere)
- WU1, WU2, WU3, WU4, WU9, WU10 modified (per above)
- WU5, WU6, WU7, WU8, WU11, WU12 unchanged
- WU13 added
- Total: 13 WUs (was 12)
- Critical path: WU2 → WU8 → WU12 → WU4 → WU5 (length 5 unchanged)
- Max parallel width: 3 (unchanged)

### Adversarial findings disposition (rev1 → rev2)

| Finding | Severity (rev1) | Disposition | How addressed in rev2 |
|---------|----------------|-------------|----------------------|
| CF-1 (containment is theater) | critical | dissolved | Reframed as scope guardrail; threat model corrected; bypass-resistance / child-process-invisibility no longer load-bearing claims |
| CF-2 (token budget hand-waved) | high | mitigated | Explicit 2K bound; prompt cap in WU1; AC15 measurable; resolution in Token Budget decision |
| CF-3 (runner exit-code interpretation) | high | mitigated | Per-Runner Exit Code Handling section; corrected pytest codes; silent-failure detection; binary-missing precheck |
| CF-4 (liveness wishful) | high | mitigated | Bash-tool-timeout replaces heartbeat fiction; output-streaming flags forced |
| CF-5 (detection wrong) | high | mitigated | Language-primary heuristic; binary-missing handling |
| H1 (first Bash-using premise false) | critical | dissolved | Preservation Contract corrected; "first ACTIVELY Bash-using" framing; honest accounting of existing reviewers' Bash declarations |
| C1 (metacharacter bypass) | critical | downgraded to low | Threat model reframe; not modeling adversarial bypasses |
| C5 (pytest exit codes) | high | mitigated | Per-Runner Exit Code Handling section |
| H4, C3, C10 (subagent isolation) | high | mitigated | Token Budget decision; AC15 rewrite; WU1 prompt cap |
| H5 (AC14 vs WU12) | high | mitigated | AC14 clarification; explicit distinction |
| H8 (child process invisibility) | high | downgraded to ignore | Threat model reframe; not modeling shell-out adversaries |
| M1 (migration path) | high | mitigated | Migration from Existing Prism Installations section added |
| M3 (binary missing) | high | mitigated | Per-Runner Exit Code Handling + detection precheck |
| M4 (allowlist not enumerated) | high | downgraded to medium | Threat model reframe makes airtight enumeration unnecessary; allowlist documented in agent prompt |
| M10 (heartbeat mechanism) | high | mitigated | Replaced by Bash-tool-timeout (no heartbeat) |
| M2 (skip telemetry) | medium | mitigated | New AC22 for skip_reason enumeration; synthesis displays reason |
| M5 (multi-classification) | medium | mitigated | Tiebreak rule: highest-severity wins; reasoning string includes secondary tags |
| M7 (zero-failures behavior) | medium | mitigated | New AC for empty-findings path; WU1 prompt explicit |
| H6 (theme flattening) | medium | mitigated | Documented as desired behavior in Synthesis Integration |
| H9 (agent name) | low | applied | Renamed to test-debt-classifier per user direction |
| C9 (disable warning) | medium | dropped | Threat model reframe makes "removing containment" framing inapplicable |
| C6, C8 | medium | watch | Documented as accepted v1 risks |
| M6, M8, M9 | medium | watch | Deferred to v2; documented as known limitations |
| H2, H3, H7, H10 | low | applied | Minor edits in rev2 |

## Revision 2 → Revision 2-polish (inline; no formal regression)

- **Trigger:** Stage 3 re-Diverge (validation-shaped) surfaced 6 high-severity issues + a vocabulary correction
- **Date:** 2026-05-01T16:00:00Z
- **Mode:** Inline polish per user direction (path "a" — fix high-sev, proceed to Stage 4)
- **Confidence at completion:** ~0.72 (down from 0.78 because polish added 2 WUs and 1 AC inline without independent reader review)

### High-severity rev2 issues addressed in polish

| Issue | Polish action |
|-------|---------------|
| **C5 — Bash-tool timeout mechanism gap** | WU1 expanded with item (h) explicit timeout-parameter requirement on every Bash test-runner call (max 600_000ms; default 300_000ms; configurable via SAIL_PRISM_TEST_TIMEOUT) and item (i) partial-output-on-timeout: do NOT classify on truncated output, emit only meta-finding |
| **C7 — False-pass detection misses formats** | Per-Runner Exit Code Handling section: multi-format scan (textual + JSON + JUnit XML); 200-line window (was 50); explicit patterns per format |
| **M2 — `skip_reason` not enumerated** | New "skip_reason Enumeration" section with closed enum: `no_runner_detected`, `opt_out_env_var`, `runner_binary_missing`, `polyglot_ambiguous_no_override`, `unsupported_override`. Each value paired with synthesis message |
| **M-NEW1 — No WU for user-facing docs** | WU15 added: Security & Side Effects subsection in commands/prism.md, install.sh first-run message, per-stage runner-naming warning |
| **M-NEW2 — `SAIL_PRISM_TEST_RUNNER` override path broken for non-priority runners** | New skip_reason `unsupported_override`; new failure-mode row; new AC26; new Decisions row constraining override to priority-6 list |
| **H10 / M-NEW3 — AC15 fixture project undefined** | WU14 added: tests/fixtures/test-debt-100-failures/ with 100 synthetic failing tests + generate.sh for deterministic recreation |

### Medium-severity issues partially addressed

- **C3** — AC15 word-count math corrected (1500 not 2667)
- **C8** — AC25 expanded to verify consumer-side default-construction; Decisions clarifies the responsibility lives in WU4/WU7
- **H11** — work-graph.json WU1.depends_on=[WU13] (was [])
- **H12** — state.json challenge stage tracks rev1 + rev2 separately
- **H14** — Decisions row makes consumer-side default-construction responsibility explicit

### Vocabulary correction (post-session feedback from user)

User flagged that "DISPOSITION_VERIFIED" was overstated for re-Diverge findings (agents performed text-conformity checks, not behavioral verification). Disposition vocabulary corrected throughout:
- `text_conforms` (spec text matches claim)
- `fact_checked` (claim matches external authority like pytest docs)
- `behaviorally_verified` (verified by executed test — 0 items pre-execute)
- `partial`, `new_issue`, `accepted`, `polished`

Saved as feedback memory `feedback_verification_word_precision.md`. Decisions table now documents this vocabulary explicitly.

### Sections added

- New section: "skip_reason Enumeration (closed set)" — between "Zero-failures behavior" and "What Changes"
- New WUs: WU14 (fixture creation), WU15 (user-facing threat-model docs)
- New AC: AC26 (unsupported override path)
- New Failure-Mode row: SAIL_PRISM_TEST_RUNNER outside priority-6
- New Decisions rows: Override scope, Skip reason vocabulary, Disposition vocabulary

### Sections modified

- "Per-Runner Exit Code Handling" — false-pass scan expanded to multi-format + 200-line window; binary-missing precheck caveats; timeout mechanism explicit
- WU1 — items (h) and (i) added; depends_on=[WU13]
- WU9 — depends_on includes WU14
- WU10 — fixture count 6 → 7 (added unsupported_override)
- WU13 — description tightened (multi-format detection, 200-line window)
- AC15 — word-count math corrected; cites WU14 fixture
- AC22 — synthesis message references closed enum from new section
- AC25 — verifies consumer-side default-construct
- Decisions table — 3 new rows (Override scope, Skip reason vocabulary, Disposition vocabulary)

### Sections unchanged

- Threat Model section
- Classification (5 categories)
- Preservation Contract
- Migration section (M1's abandoned-mid-run case still deferred)
- Other failure modes
- Q1-Q5 resolutions

### Work units affected

- New: WU14, WU15
- Modified: WU1 (items h, i; depends_on), WU9 (depends_on), WU10 (fixture count), WU13 (description)
- Unchanged: WU2, WU3, WU4, WU5, WU6, WU7, WU8, WU11, WU12
- Total: **15 WUs** (was 13 in rev2)
- Critical path: WU2 → WU8 → WU12 → WU4 → WU15 → WU9 (length 6; was 5)
- Max parallel width: **4** (was 3)

### What's deferred

10 medium-or-low items deferred with rationale (see adversarial.md "Outstanding" section). Not addressed in polish because:
- Some are cosmetic (H6 section naming, H9 upstream rename)
- Some are accepted v1 trade-offs (M1 abandoned-mid-run, M4 allowlist parity, M-NEW4 forced-flags-vs-config)
- Some are eliminated by structural choice (M-NEW5 drift via single-source)

These will be revisited at debrief or addressed in v2 if execution surfaces them as friction points.

## Revision 2-polish → Revision 3 (`/overcomplicated` trim)

- **Trigger:** `/overcomplicated` review surfaced runner-multiplication as the largest single source of accreted complexity. User agreed to path (a): drop runner support 6→2 (pytest + bash test.sh), consolidate AC existence checks, fold WU13, trim Decisions table.
- **Date:** 2026-05-01T16:45:00Z
- **Mode:** Spec trim (not regression-driven; deliberate scope reduction)
- **Net change:** spec.md 313 → 299 lines (~5% reduction); WUs 15 → 14; ACs 26 → 22

### Sections modified

- **Summary:** "using a detected runner" → "(pytest or `bash test.sh` in v1; other runners deferred to v2)"
- **Per-Runner Exit Code Handling:** Dropped 4 runner rows (bun test, cargo test, go test, npm test). Dropped JSON + JUnit-XML false-pass scan formats (now textual-only since v1 runners produce textual output). Forced output flags: 6 entries → 2 (pytest + bash test.sh)
- **skip_reason Enumeration:** Updated `polyglot_ambiguous_no_override` and `unsupported_override` rows to reflect 2-runner v1 set. Synthesis messages name v1 runners explicitly.
- **Failure Modes:** Dropped runner-priority polyglot row; simplified to "both pytest config AND test.sh"; dropped JSON/XML format from false-pass row; updated unsupported_override row
- **Decisions table:**
  - REMOVED "Disposition vocabulary" row (process-meta, lives in adversarial.md)
  - REPLACED "Detection priority (language-primary)" with "Detection (v1: 2 runners) — simple binary check"
  - SIMPLIFIED "Override scope" row (priority-6 → v1 set of 2)
  - SIMPLIFIED "Output streaming" row to v1 runners only
- **Success Criteria:**
  - CONSOLIDATED AC1-AC5 (5 existence/structure checks) → AC1 (single consolidated check)
  - RENUMBERED to AC1-AC22 (was AC1-AC26 with gaps)
  - Updated AC22 (former AC26) wording for v1 supported set
- **Work Units:**
  - FOLDED former WU13 (per-runner exit-code content) into WU1's prompt content — same file, same authoring pass; no separate WU
  - RENUMBERED former WU14 (fixture) → WU13; former WU15 (user-facing docs) → WU14
  - Updated WU3 from "language-primary heuristic" to "2-runner check"
  - Updated WU4 dependencies: was [WU3, WU12, WU13], now [WU3, WU12]
  - Updated WU9 dependencies and AC range references
  - Updated WU10 fixture descriptions (textual false-pass only, not multi-format)
- **Senior Review:** Updated AC15→AC11 reference; updated polyglot-projects bite-first-timers entry to 2-runner phrasing

### What's deferred to v2

- Cargo, Go, Bun, npm test runner support (4 runners)
- JSON + JUnit-XML false-pass detection formats
- Stage 4 inline-fix candidates that became moot under runner trim (most polyglot/runner-multi issues dissolved):
  - EM3 (network/integration tests on VPN-locked machines) — still relevant; addressed by user-facing docs (WU14)
  - EC7 (`SAIL_PRISM_RUN_TESTS` parsing for non-"0" falsy values) — deferred to v2 unless user-reported
  - EC6 (rc=0 + empty bash test.sh output silent pass) — deferred; minimum-PASS-marker check is v2
  - EH7 (polyglot silent partial coverage) — moot under 2-runner scope; the v1 design either runs the chosen runner or skips with reason
  - EM5 (ANSI escape codes breaking regex) — deferred; unlikely with current forced flags
  - EM4 (crashed-prior-run wizard state) — deferred; rare edge case
  - EM6 (legitimately-slow single test) — deferred; user can extend SAIL_PRISM_TEST_TIMEOUT
- AC25 consumer-side default-construct (now AC21) verification still covered, but the broader "every code path that reads test_debt must default-construct" cross-cutting check is implicit

### Trade-offs

- **Less day-1 runner coverage:** users with cargo/go/bun/npm projects get `no_runner_detected` until v2. They have nothing today, so v1 is still strictly better.
- **Simpler implementation surface:** WU3 dropped from "Medium" complexity to "Low" (binary check vs. file-counting heuristic + priority order). Failure modes table shrank. AC count dropped without losing coverage of v1 surface.
- **Easier v2 path:** adding cargo/go/etc. is a small marginal change once the v1 infrastructure is operational. Each additional runner is a row in the agent prompt's exit-code table, an entry in the allowlist, and a fixture in evals.json.

## Revision 3 → Revision 3-polish (pre-mortem inline fixes)

- **Trigger:** Stage 4.5 pre-mortem identified PM2 (NEW critical: install.sh doesn't merge settings.json — verified via grep on install.sh) + PM4 (covered-partial: user Ctrl-C leaves stale `status: running`) + PM7 (documentation gap: SAIL_DISABLED_HOOKS recovery)
- **Date:** 2026-05-01T17:15:00Z
- **Mode:** Inline polish per user direction (option [2] note + inline-fix); no formal regression
- **Net change:** spec.md +~15 lines; ACs 22 → 24; skip_reason enum gains `hook_not_wired`; WU4 gains self-probe + stale-state-detection responsibilities; WU14 gains install.sh detection-warning task

### Sections modified

- **skip_reason Enumeration:** Added `hook_not_wired` value with synthesis message naming the JSON entry to add
- **Success Criteria:** Added AC23 (hook-wiring self-probe) and AC24 (stale wizard state recovery from interrupted prior runs)
- **Failure Modes table:** Updated `SAIL_DISABLED_HOOKS` recovery row to clarify env-var inheritance from parent process — mid-session changes do not propagate; recovery requires session restart (PM7 fix). Added two new rows for PM2 and PM4 mitigations.
- **Work Units:**
  - WU4 expanded: Stage 5.5 entry probes hook-wiring (AC23) + detects stale state (AC24) before subagent dispatch
  - WU14 expanded: install.sh detects existing settings.json and prints the JSON snippet warning (PM2 complement to runtime probe in WU4)

### What was deferred

- **PM1 (opt-out default for side-effect tests)** — challenges a load-bearing user decision. User stood by the opt-out posture; documented in premortem.md as agent's recommendation that was considered.
- **PM5 (aggregate observability across runs)** — scope expansion; v2 candidate
- **PM6 (output log rotation)** — already deferred to v2 in adversarial.md
- **PM8 (classifier sanity check / ground-truth fixture)** — significant scope addition; v2 candidate

### Trade-offs

- The hook-wiring self-probe (PM2 fix at runtime) doubles up with the install-time detection (PM2 fix at install). Belt-and-suspenders by design — install messaging may be missed; the runtime probe ensures users discover the gap when they actually try to use Stage 5.5.
- Stale-state detection (PM4 fix) is ~5 lines of logic but adds an AC and a state transition. Worth it because Ctrl-C-during-test-run is a common user behavior, not a corner case.
- Failure Modes table grew by 2 rows (PM2 + PM4 mitigation visibility) — small churn, but the rows reference ACs that didn't exist before, making the table self-documenting.

### Disposition vs pre-mortem

| Pre-mortem finding | Action |
|--------------------|--------|
| PM1 (opt-out default) | DEFERRED — user decision stands |
| PM2 (install.sh merge gap) | **POLISHED** — AC23 runtime probe + WU14 install detection |
| PM3 (mid-session install window) | POLISHED — same AC23 covers it |
| PM4 (Ctrl-C wizard state) | **POLISHED** — AC24 stale-state recovery |
| PM5 (aggregate observability) | DEFERRED to v2 |
| PM6 (log rotation) | DEFERRED to v2 (already noted) |
| PM7 (SAIL_DISABLED_HOOKS recovery) | DOCUMENTED — Failure Modes row updated |
| PM8 (classifier ground truth) | DEFERRED to v2 |
