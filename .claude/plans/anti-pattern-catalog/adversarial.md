# Adversarial Review: anti-pattern-catalog (Stage 3 — Challenge, vanilla mode)

Single-perspective adversarial pass on `spec.md`. Findings ordered by severity.

## Verdict: REWORK

Two critical findings require spec changes before Stage 7. Both are mechanism-level gaps (the spec describes a thing that won't actually work as written), not deep design problems. Targeted revision should resolve both.

## Findings Summary

| ID | Finding | Severity | Addressed |
|----|---------|----------|-----------|
| F1 | Hookify rule uses `event: write`, but only `event: bash` is supported by current hookify integration | **critical** | needs spec update |
| F2 | Sweep scans `.claude/anti-patterns/*.md` — would match the catalog's own `fixture_bad` blocks, self-poisoning counters | **critical** | needs spec update |
| F3 | `bash-silent-error-suppression` detection requires multi-line analysis, but spec implies grep regex — unimplementable as written | high | needs new section |
| F4 | `.events.jsonl` unbounded growth has no v1 guard; fast-moving projects could accumulate quickly | medium | needs spec update |
| F5 | Sweep sources `epistemic_safe_swap` from `scripts/epistemic-safe-write.sh`, but the script may not be installed yet on fresh systems | medium | needs spec update |
| F6 | WU3 time estimate of 90 minutes is optimistic; realistic is 2-3 hours given the integration surface | low | informational |
| F7 | Stock-anti-patterns bootstrap: copy-if-not-exists at directory level vs file level is ambiguous | low | needs spec update |
| F8 | `recent_window_days = 60` default may be wrong for both slow (underweight) and fast (overweight) projects | low | informational |

## Detailed Findings

### F1 — Hookify event mismatch (CRITICAL)

**Claim:** spec.md "Hookify Integration" section defines a rule with `event: write` to catch unsafe atomic writes during file Write/Edit operations.

**Evidence:** All existing hookify rules in `hookify-rules/*.md` use `event: bash` (verified by `grep -h '^event:' hookify-rules/*.md | sort -u`). No rule uses `write` or `edit`. The hookify plugin in this toolkit appears to intercept bash commands only.

**Why it matters:** WU6 ships a rule that won't fire. AC4 ("one hookify rule cites a catalog ID") would pass mechanically (the rule exists with the citation) but the catalog would have no actual *runtime* enforcement at all. The first-consumer wire-up — the proof that the catalog has a job — is silently broken.

**Fix direction (not implementation):** Either
- (a) the rule matches at bash-command time when Claude shells out to write a file (limited — most file writes go through the Edit/Write tools, not bash), or
- (b) replace "hookify rule" first-consumer with a **PreToolUse shell hook** (`hooks/anti-pattern-write-check.sh` triggered on Write/Edit) that scans the proposed content against catalog regexes, or
- (c) verify that the upstream hookify plugin actually supports `event: write` even if claude-sail hasn't used it — the format doc may be richer than the in-repo examples.

Direction (b) is the safest — it's deterministic, doesn't depend on plugin capabilities we haven't verified, and matches the existing `hooks/` discipline pattern. Trade-off: it's a shell hook, not a hookify rule, so the "first consumer is hookify" framing in describe.md changes to "first consumer is a shell hook."

**Regression target:** Stage 2 (Specify). Update WU6 to either confirm hookify capability or pivot to a shell hook.

---

### F2 — Sweep self-matches its own fixtures (CRITICAL)

**Claim:** Spec says the session sweep scans files modified this session via `git diff --name-only`. The full sweep scans `git ls-files`. Neither excludes `.claude/anti-patterns/`.

**Evidence:** Each catalog entry contains a `fixture_bad` field with the exact pattern the regex is meant to detect. When the sweep runs `grep -nE "$detection_regex" against $file`, and `$file` happens to be `.claude/anti-patterns/bash-unsafe-atomic-write.md`, the regex will match the fixture_bad code block on line N and append a detection event for THAT pattern AT THAT FILE.

Verified by hand-grep: `grep -nE '> *"?\$[A-Z_]+"? *&& *mv' .claude/plans/anti-pattern-catalog/spec.md` matches lines 48 (the fixture in spec.md), 212 (the hookify rule example), and 292 (an AC describing the regex). All would be miscounted as real detections.

**Why it matters:** Counters become self-inflated and self-perpetuating. A pattern's `recent_hits` would always include at least one match against itself. Worse: when the catalog grows, every new entry's `fixture_bad` adds another permanent self-match for whatever pattern it cites.

**Fix direction:** The sweep MUST exclude:
- `.claude/anti-patterns/**` (the catalog itself)
- `.claude/plans/**` (planning docs, which include fixtures and examples)
- Possibly: any file path matching `*/anti-patterns/*` more broadly to handle vault mirrors and stock templates

This is a one-line `grep -v` filter, but missing it makes the sweep useless.

**Regression target:** Stage 2 (Specify). Add an explicit `EXCLUDE_PATHS` list to the sweep algorithm spec, with `.claude/anti-patterns/`, `.claude/plans/`, `commands/templates/stock-anti-patterns/` at minimum.

---

### F3 — Silent-error-suppression detection is unimplementable as specified (HIGH)

**Claim:** Spec describes `bash-silent-error-suppression` as: "detect `set +e` followed within ~20 lines by a `jq`/`grep`/etc. invocation whose exit code is *not* checked (no immediate `$?` test, no `||`, no `&&`)."

**Evidence:** This is multi-line context-aware analysis, not a regex. `grep -E` is line-oriented. To detect "X followed within N lines by Y where Y is not followed by Z," you need awk, perl, or a real parser. The spec's `detection_regex` field implies single-line ERE.

**Why it matters:** WU2 (starter entries) cannot ship `bash-silent-error-suppression` with a working `detection_regex`. Either the entry's fixtures will be wrong, or the regex will under/over-match drastically.

**Fix direction:** Two options:
- (a) Coarsen the pattern: just match `set +e` and flag the file for human review. False-positive rate is high but the entry becomes implementable.
- (b) Extend the schema to allow `detection_kind: regex | awk | external-script` so multi-line patterns can be handled with awk. This is more work but generalizes.
- (c) Drop this pattern from v1; ship only `bash-unsafe-atomic-write` and `bash-missing-fail-fast`. Add it later when WU3 supports awk.

Direction (a) is cheapest. Direction (c) keeps v1 honest about what works.

**Regression target:** Stage 2 (Specify). Pick one of (a)/(b)/(c) and update the entry's spec.

---

### F4 — Unbounded `.events.jsonl` growth (MEDIUM)

**Claim:** Spec acknowledges `.events.jsonl` grows unbounded as a known limitation; v1 has no guard.

**Why it matters:** A repo with many active anti-patterns could accumulate 100+ events per sweep. With `/end` running once per session and ~10 sessions/day, that's 1000+ events/day. After a year: 365k events. Counter recomputation gets slower with each sweep (linear scan of the log). Eventually noticeable on `/end` latency budget (5s).

**Fix direction:** Add a v1 cap:
- Hard cap at, say, 10000 events; on overflow, archive oldest 50% to `.events.archive.jsonl` and continue.
- Or: time-window the log (drop events older than 1 year on each sweep).
- Or: keep the log but build a fast-access index (jq queries are O(N) on the file).

**Regression target:** Stage 2 (Specify). Add to sweep algorithm: "after counter regeneration, if `.events.jsonl` exceeds 10000 lines, archive the oldest half."

---

### F5 — `epistemic_safe_swap` dependency on fresh systems (MEDIUM)

**Claim:** Spec says the sweep uses `epistemic_safe_swap` from `scripts/epistemic-safe-write.sh` for atomic writes.

**Evidence:** That script was just added in this session. It's now in `install.sh`'s copy list, but a project that bootstraps the catalog before re-running install.sh won't have the helper. Same risk if the catalog is enabled on a project where the toolkit was installed before this session.

**Why it matters:** Sweep would fail at the swap step. Sweep already has fail-open semantics for missing tools, but the spec doesn't specify this particular fallback.

**Fix direction:** Sweep should check for `epistemic_safe_swap` availability (sourced or installed). If unavailable, fall back to an inline non-empty + valid-JSON check (same pattern as the inline fallback in `hooks/epistemic-preflight.sh`). Document the fallback in the sweep algorithm.

**Regression target:** Stage 2 (Specify). Add fallback path to sweep algorithm under "Fail-open semantics".

---

### F6 — WU3 estimate is optimistic (LOW, informational)

**Claim:** WU3 estimate is 90 minutes.

**Evidence:** WU3 includes: regex matching against file set (per pattern, per file), self-test loop, append-only event log, counter recomputation (windowed query), atomic writes via safe-swap, vault export with project name detection, fail-open at every layer (timeout, missing jq, missing git, vault unavailable), and exclude-paths handling.

**Why it matters:** Underestimation slips schedule and incentivizes shortcutting (e.g., skipping the self-test loop). 2-3 hours is more honest.

**Fix direction:** Bump estimate. No spec change needed.

---

### F7 — Bootstrap copy semantics ambiguity (LOW)

**Claim:** Spec says `/bootstrap-project` copies `stock-anti-patterns/` → `.claude/anti-patterns/` "copy-if-not-exists, matching stock-pipelines semantics."

**Evidence:** This is ambiguous at the file level. If the user already has `.claude/anti-patterns/bash-unsafe-atomic-write.md` (custom version), and we ship a NEW starter `bash-eval-injection.md`, does bootstrap:
- (a) Skip entirely because `.claude/anti-patterns/` exists? (User never gets the new starter.)
- (b) Copy missing files only? (User keeps their custom + gets new starter — usually right.)
- (c) Copy all, overwriting? (User loses custom — wrong.)

stock-pipelines uses copy-if-not-exists at the FILE level. We should match that.

**Fix direction:** Specify file-level copy-if-not-exists explicitly.

**Regression target:** Stage 2 (Specify). Update WU5 description.

---

### F8 — `recent_window_days = 60` default (LOW, informational)

**Claim:** All entries default `recent_window_days: 60`.

**Why it matters:** A solo developer working on a small toolkit might have a single anti-pattern fire every few months — 60 days is a reasonable "have I seen this lately?" window. A fast-moving production team might fire patterns weekly — 60 days makes "recent" meaningless.

**Fix direction:** Make the default project-overridable via `.claude/anti-patterns/.config.json` or similar. Per-pattern override stays in frontmatter.

**Regression target:** Defer — not blocking v1. Project-level override is a v2 concern.

---

## Recommendation

REWORK to Stage 2. Update spec.md to address F1, F2, F3, F4, F5, F7. F6 and F8 are informational.

Specifically:

1. **F1**: replace "Hookify Integration" with "Shell Hook Integration" — `hooks/anti-pattern-write-check.sh` PreToolUse on Write/Edit. Update WU6.
2. **F2**: add `EXCLUDE_PATHS` to sweep algorithm: `.claude/anti-patterns/`, `.claude/plans/`, `commands/templates/stock-anti-patterns/`, `Engineering/Anti-Patterns/` (in vault).
3. **F3**: pick one option (recommend: (c) drop from v1 ship only 2 entries, defer multi-line analysis to v2 with `detection_kind` schema extension).
4. **F4**: add "after counter regeneration, archive oldest half if `.events.jsonl` > 10000 lines" to sweep algorithm.
5. **F5**: add inline fallback path for safe-swap to sweep algorithm.
6. **F7**: explicitly state "file-level copy-if-not-exists" in WU5.

After spec revision, re-run vanilla challenge once more (cheap — single pass) to confirm the changes don't introduce new issues. Then proceed to Stage 4 (Edge Cases).

---

## Stage 3 (re-run on revision 2)

**Verdict:** READY (with one inline correction)

Verified all six fixes landed. Targeted second-pass on the rev2 changes surfaced one minor
mechanism issue:

- **Hook input contract**: rev2 spec said the hook reads input via `$CLAUDE_HOOK_INPUT`. Verified
  against existing hooks in `hooks/secret-scanner.sh:23` and `hooks/freeze-guard.sh` — the
  convention is **stdin-based JSON** (`input=$(cat)`, then `jq -r '.tool_input.<field>'`).
  Also: Write tool uses `.tool_input.content` while Edit uses `.tool_input.new_string`. Spec
  inline-corrected to use `// empty` fallback chain across both fields. Not a regression-worthy
  finding — caught and fixed in the same pass.

Other concerns considered but not flagged for regression:

- Compaction semantics: after rev2 step 5a archives oldest events, `total_hits` would only
  reflect the active window post-compaction. Mild semantic drift. Documented as v2 concern;
  rare event in practice (>10000 detections required).
- Detection-regex specifics for `bash-rm-rf-with-variable`: rough form may miss `-fr` (vs `-rf`).
  Spec already states "rough — final regex tuned during WU2." Implementation concern, not spec.
- Inline fallback for safe-swap: validating "valid markdown frontmatter" is non-trivial. WU3
  implementation will need to decide between "non-empty + has front-matter delimiters" (cheap)
  vs full YAML parse (requires yq). Implementation choice, not spec.

**Verdict: READY for Stage 4 (Edge Cases).**

---

## Stage 4 — Edge Cases (vanilla mode, rev2 spec)

Boundary scan across input, state, concurrency, time, and filesystem dimensions. Findings
are appended to this file with `E[N]` IDs. Edge cases that imply architectural changes
are flagged (potential regression triggers). This pass found none.

### Input Boundaries

| ID | Edge | Behavior in spec | Status |
|----|------|------------------|--------|
| E1 | Empty `.events.jsonl` (first sweep ever) | All counters start at 0; sweep writes events, recomputes — works. | covered |
| E2 | Catalog dir exists but is empty (just `mkdir`) | Sweep finds zero `.md` entries, exits silently with summary "0 patterns to scan." | covered (implicit in fail-open) |
| E3 | Pattern with malformed YAML frontmatter | Sweep skips with WARN per fail-open semantics. | covered |
| E4 | Pattern's `detection_regex` matches nothing in fixture_bad | Self-test loop fails; pattern skipped with WARN. | covered |
| E5 | Pattern's `detection_regex` matches `fixture_good` | Self-test loop fails; pattern skipped with WARN. | covered |
| E6 | Empty file set (`/end` on a session with no edits) | Sweep enumerates zero files, no events appended, counters unchanged. | covered |
| E7 | A file is renamed mid-sweep | Stale path written to event; counter regen uses path as-is. Locations_remedied may report a phantom. **Acceptable** for v1 — git renames are rare per session. | needs note in known limitations |

### State Boundaries

| ID | Edge | Behavior in spec | Status |
|----|------|------------------|--------|
| E8 | Vault path with spaces (`/mnt/c/Users/.../Work Stuff/Helvault`) | All vault writes must use double-quoted paths. WU3 implementation note. | covered (must quote) |
| E9 | Project name with hyphens, dots (e.g., `s4-notion-portal`) | `basename` handles fine; vault filename `<project>-<id>.md` is valid. | covered |
| E10 | Catalog dir present but `.events.jsonl` corrupted (truncated mid-line) | jq read fails on the malformed line. Counter regen produces partial counts. **Adversarial:** spec doesn't specify behavior here. | **needs spec update — minor** |
| E11 | `epistemic-safe-write.sh` present but `epistemic_safe_swap` function not exported | Sourcing succeeds; function call fails. Inline fallback condition (`command -v` check) catches it. | covered (already in F5 fix) |
| E12 | Stock-anti-patterns directory missing in installed toolkit (older install) | `/bootstrap-project` skips that step silently; user can opt in by running install.sh again. | covered (fail-open) |

### Concurrency Boundaries

| ID | Edge | Behavior in spec | Status |
|----|------|------------------|--------|
| E13 | Two simultaneous `/end` invocations (rare — implies two terminal sessions ending simultaneously) | Both append to `.events.jsonl` (append-only, OS append is atomic for small writes). Both recompute counters and write frontmatter via safe-swap. Last writer wins. **Minor:** the loser's recomputation is overwritten before being read; next sweep self-corrects. | covered (acceptable race) |
| E14 | Sweep running while a Write/Edit hook is also running | Hook reads catalog frontmatter that may be mid-rewrite. Worst case: hook sees old `detection_regex` for one cycle. Detection still works (the pattern is well-formed in the prior committed state). | covered (acceptable race) |

### Time Boundaries

| ID | Edge | Behavior in spec | Status |
|----|------|------------------|--------|
| E15 | Clock skew (system clock jumps backward) | Events with future timestamps relative to "now" would be flagged "recent" prematurely; events with past-pinned timestamps could fall out of recent window early. | needs note in known limitations |
| E16 | `recent_window_days: 60` with all events older than 60 days | `recent_hits = 0`, `total_hits` reflects all events. The system honestly reports "no recent activity." This is the desired behavior for the recency signal — not a bug. | covered |

### Filesystem Boundaries

| ID | Edge | Behavior in spec | Status |
|----|------|------------------|--------|
| E17 | Read-only filesystem (catalog dir not writable) | Frontmatter rewrite fails. Safe-swap helper rolls back. Sweep exits 0 with WARN per fail-open. | covered |
| E18 | Disk full mid-sweep | Tmp file write fails; safe-swap rolls back. Inline fallback may write a partial tmp; the validate step (non-empty + valid frontmatter) catches it. | covered |
| E19 | Symlinked file in catalog dir (e.g., user symlinked an entry from vault) | Frontmatter rewrite follows the symlink and overwrites the target. **If target is in vault and read-only, write fails and rolls back.** Otherwise: the catalog source-of-truth becomes the symlink target, breaking the architecture's "project-local source of truth" property. | **needs note — minor** |

### Findings (Edge-Case-Triggered Spec Updates)

| ID | Finding | Severity | Action |
|----|---------|----------|--------|
| E10 | Truncated `.events.jsonl` behavior unspecified | low | Add to spec: "If event log line is malformed (jq parse error), skip that line, log WARN, continue. Sweep is resilient to partial corruption." |
| E15 | Clock skew impact on recent_hits | low | Add to known limitations: "Counter accuracy depends on monotonic-ish system clock. Major backward skew can temporarily inflate recent_hits." |
| E19 | Symlinked catalog entries break architecture | low | Add to known limitations: "Catalog entries should be regular files. Symlinks to vault may cause writes to land outside the project, breaking project-local source-of-truth." |
| E7 | File rename mid-sweep produces phantom remediation | low | Add to known limitations: "Files renamed between sweeps may produce phantom locations_remedied entries. Self-corrects on next sweep." |

**Verdict: READY** — no critical findings; four low-severity findings to fold into spec's "Known Limitations" section without regression.

**No edge case implies architectural change.** The fail-open semantics from rev2 cover most edges; the four flagged findings are documentation tasks, not design changes.
