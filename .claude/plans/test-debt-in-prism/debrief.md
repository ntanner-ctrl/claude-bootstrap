# Debrief: test-debt-in-prism

> Stage 8 of 8 — completion ceremony for the rev3-polish blueprint that adds
> conditional Stage 5.5 to `/prism` (test-debt classifier + scope-guardrail hook).
> Implementation completed 2026-05-06 across 14 work units in one session.

## Ship Reference

- **Branch:** main
- **Commit(s):** pending — implementation in working tree, not yet committed
- **Settings change:** `~/.claude/settings.json` wired `prism-bash-allowlist.sh` into the PreToolUse Bash matcher (manual merge, since install.sh deliberately does not auto-merge user settings)
- **Deployed:** `bash install.sh` ran during this session — toolkit live in `~/.claude/`. Settings cache in this session means the new hook is effective on next session start, not retroactively.

### Files NEW

| Path | Lines | Purpose |
|------|------:|---------|
| `agents/test-debt-classifier.md` | ~280 | 5-category classifier subagent (Bash/Read/Glob/Grep), 2K-token output bound, per-runner exit-code handling, multi-class tiebreak, no-recursion notice, single-retry quarantine signal, partial-output handling on timeout, textual false-pass scan |
| `hooks/prism-bash-allowlist.sh` | ~80 | PreToolUse Bash hook; substring-prefix allowlist match for `test-debt-classifier` agent_type only; scope-guardrail framing (not security boundary); fail-open + SAIL_DISABLED_HOOKS toggle |
| `tests/fixtures/test-debt-100-failures/README.md` | 49 | What the fixture is for (AC11 verification) |
| `tests/fixtures/test-debt-100-failures/generate.sh` | ~135 | Deterministic regenerator for the fixture |
| `tests/fixtures/test-debt-100-failures/pytest.ini` | 5 | Minimal pytest config — triggers runner detection |
| `tests/fixtures/test-debt-100-failures/test_synthetic.py` | 736 | 100 failing tests across 5 plausible categories (20 each) |
| `.claude/plans/test-debt-in-prism/manifest.json` | regen | Token-dense recovery format (was missing; `manifest_stale: true` in state.json) |
| `.claude/plans/test-debt-in-prism/wu12-verification.md` | new | Documents the verification-split for WU12 (stdin-piped done in-session; subagent-dispatched deferred to post-restart) |

### Files MODIFIED

| Path | Nature |
|------|--------|
| `commands/prism.md` | Added Stage 5.5: Test Debt Classification (subsections 5.5.0 detection through 5.5.7 security); updated Stage 6 Synthesis with test-debt findings as themable contributor; updated Stage 7 report Domain coverage |
| `settings-example.json` | Added `prism-bash-allowlist.sh` to PreToolUse Bash matcher hooks array |
| `install.sh` | Added prism-bash-allowlist to hook list output; added it to printed JSON snippet; new PM2-detection block at end (warns loudly if user's settings.json lacks the wiring) |
| `README.md` | Agent count `12→13` (added test-debt classifier note); hook count `20→21` shell files (`19→20` hooks) |
| `.claude/CLAUDE.md` (this repo) | Same count updates as README; required protect-claude-md hook approval token |
| `test.sh` | Cat 3 expected counts (12→13, 20→21); new Cat 10: Test Debt in Prism — Structural Checks (19 assertions covering AC1, AC11/15/17/18/19/20/23/24 via grep proxies + the WU13 fixture) |
| `scripts/behavioral-smoke.sh` | Added hook-execution mode (~75 lines) — entries with a `hook` field run the hook with provided stdin and assert against `expected_exit` + `expected_stderr_contains`, alongside the existing fixture-text-assertion mode |
| `evals/evals.json` | Added 7 new fixtures (id 6-12) for `prism-bash-allowlist.sh` covering AC2-AC5 + git-log + SAIL_DISABLED_HOOKS toggle |

### Test results

- `bash test.sh`: **132 passed, 0 failed, 3 warnings** (warnings unrelated to this blueprint)
- `bash scripts/behavioral-smoke.sh`: 12 passed, 0 failed (5 existing fixtures + 7 new hook fixtures)
- Inline hook smoke tests (8 stdin shapes piped to `bash hooks/prism-bash-allowlist.sh`): 8/8 correct (AC2-AC5 covered functionally)

## Spec Delta

This blueprint went through **one formal regression** (challenge → specify) plus
two inline polish passes:

| Transition | Trigger | Outcome |
|-----------|---------|---------|
| rev1 → rev2 | Stage 3 critique returned REWORK with 4 critical compound findings (CF-1 through CF-5) and load-bearing solo H1. Most severe: CF-1 (containment-is-theater). | Rev2 reframed threat model from "containment" to "scope guardrail" per `feedback_threat_model_first_party_tooling`; corrected pytest exit codes (rc=1 = failures, not rc=2); replaced wishful heartbeat with Bash tool built-in timeout; corrected the false "all 11 prism agents are read-only" claim. |
| rev2 → rev2-polish | Stage 3 re-Diverge surfaced 6 high-severity follow-ups (C5, C7, M2, M-NEW1/2, H10). | Inline polish: per-runner exit-code table, multi-format false-pass scan, AC15 measurable via fixture, WU1 prompt cap explicit, consumer-side default-construct (AC25→AC21). |
| rev2-polish → rev3 | `/overcomplicated` trim before pre-mortem. | Runner support narrowed from 6 to 2 (pytest + bash test.sh; bun/cargo/go/npm/jest deferred to v2). AC consolidation. WU13 (per-runner-exit-code content) folded into WU1. WU count 15→14. |

Final spec: rev3-polish, 14 WUs, 24 ACs, PASS verdict on Stage 3 re-critique.

## Deferred Items

| Item | Reason |
|------|--------|
| **WU12 behavioral subagent-dispatch verification** | Settings cache + agent registry cache make this impossible in the current session. The hook code is correct under direct stdin piping (8/8 smoke tests pass) and AC23 self-probe (live in WU4) provides defense-in-depth. User will exercise it the next time they run `/prism` Stage 5.5 in a restarted session. See `wu12-verification.md`. |
| **AC11 behavioral verification (subagent return-message ≤ 2K tokens)** | Same as WU12 — requires actual subagent dispatch. The fixture exists; the agent prompt enforces the bound; `test.sh` Cat 10 structurally verifies the bound is documented. Behavioral measurement is post-restart. |
| **agents/README.md row for test-debt-classifier** | The file does not exist in this repo. Spec WU11 referenced a nonexistent target — surfaced as spec drift in preflight, skipped during execution. If/when an agents README gets created, it should include this agent. |
| **v2 runners (bun, cargo, go, npm, jest)** | Per spec rev3 trim. Detection logic is structured to add them by extending the closed `unsupported_override` mapping. |
| **Per-project SAIL_PRISM_RUN_TESTS override** | Q5 deferred to v2. v1 is binary global env var only. Workaround: shell function or direnv. |
| **Subagent abandoned-mid-run state recovery beyond AC24** | M1 partial — AC24 handles the simple case (status=running from prior session_id). The "user kill -9'd Claude Code mid-stage" race is documented but not actively recovered beyond the on-entry reset. |
| **Log file rotation in wizard dirs** | `test-debt-output.log` accumulates per-run. v2 may want a `--prune-wizard-logs` flag. Documented in spec Senior Review Simulation. |
| **Tag-based test filtering** (`@pytest.mark.flaky`) | v1 reads markers incidentally for classification reasoning. v2 may parse them structurally as classification hints. |

## Discoveries

Things this implementation revealed that the spec didn't anticipate:

1. **`evals/evals.json` schema mismatch.** The current `evals.json` is a fixture-based text-assertion harness (each entry has `command`, `fixture`, `assertions[]`). The spec assumed it could test hooks via `hook`+`stdin`+`expected_exit` shape. Neither tests.md nor the spec's WU10 acknowledged this gap. **Resolution:** Option A from preflight — extended `behavioral-smoke.sh` with a hook-execution mode (~75 lines), branching on the entry's `hook` field to dispatch the hook with provided stdin and assert against exit+stderr. The existing fixture mode is unchanged. Both modes coexist in the same harness.

2. **`README.md` hook count was already 20 (ahead of `.claude/CLAUDE.md`'s claim of 19).** The spec WU11 said "hook count 18→19" assuming a baseline of 18+1 = 19 shell files. Reality at execution time: README said 20, `.claude/CLAUDE.md` said 19, actual on-disk was 20. So the WU11 update math had to handle the stale baseline + the new addition: README went 20→21, `.claude/CLAUDE.md` went 19→21 (catching up the stale baseline + adding new).

3. **`agents/README.md` does not exist.** Spec WU11 listed it as a target. There is `commands/README.md` but no `agents/README.md`. Surfaced in preflight, skipped during execution, recorded as deferred.

4. **`install.sh` has no hardcoded count claims.** Spec WU11 said update `install.sh` agent count `12→13` and hook count `18→19`. Actual `install.sh` uses dynamic counting (`ls *.md | wc -l`). No edit needed there. Surfaced in preflight, skipped.

5. **PM2 condition is reachable on a real install.** After running `bash install.sh` in this session, the user's `~/.claude/settings.json` did NOT reference the new hook. This validates the AC23 self-probe motivation in practice. The hook file deployed; the wiring did not. WU14's install.sh PM2 detection block (added in this session) now warns the user with the exact JSON snippet to merge.

6. **Spec inconsistency: per-runner exit-code notation.** The spec uses `rc=1` notation in prose and `| 1 |` markdown table format in WU1. My implementation matched the table format (since it's the agent prompt). My initial test.sh structural check grepped for `rc=1` literal — it false-failed once. Fixed by tightening the grep to match table-row format. Caught via the failing test, not via review — TDD-style proxy worked here.

7. **`commands/prism.md` line numbering shifted significantly.** Stage 5.5 added ~210 lines to `prism.md` (now ~750 total). Future blueprint specs that reference `prism.md` line numbers should re-verify before relying on them.

8. **`spec.md` cross-reference confusion: "former WU13" vs "current WU13".** Rev3 trim renumbered work units. The spec at WU1 says "(b) inline per-runner exit-code handling table for pytest + bash test.sh (folded in from former WU13)" while the *current* WU13 is the test fixture. Comprehensible if you read the rev3 trim notes; confusing on a first read. Lesson: when renumbering on regression, prefer renaming over reusing IDs.

## Reflection

### Wrong assumptions
- That the eval harness (`evals.json` + `behavioral-smoke.sh`) could test hook execution out of the box. It couldn't — fixture-based text assertions only. Required an extension.
- That `agents/README.md` exists. Spec WU11 referenced it as a target; it doesn't.
- That `install.sh` has hardcoded count claims to update. It doesn't (dynamic counting).
- The implicit assumption that `~/.claude/settings.json` would auto-merge after install. It deliberately doesn't (the spec calls this out as PM2; running install confirmed it.)

### Difficulty calibration
- **Harder than expected:**
  - The eval-format mismatch — required an unbudgeted ~75-line bash extension to `behavioral-smoke.sh`. Worth it (preserves the spec's intent and keeps test infra unified) but mid-execution surprise.
  - WU11 metadata math — three small spec-drift adjustments stacked to make a "trivial" task non-trivial.
- **Easier than expected:**
  - The hook code itself — fail-open + `jq -r '.agent_type // empty'` + case dispatch + substring-prefix match all worked first try across 8 smoke-test cases.
  - The 100-test fixture — `generate.sh` produced deterministic output; 5 categories of 20 each provided enough diversity to exercise the classifier.
  - Stage 5.5 prism.md insertion — the seven subsections (5.5.0–5.5.7) flow cleanly between Stage 5 and Stage 6 without disturbing existing content.

### Advice for the next planner
- **Verify substrate before asserting.** When a spec says "test.sh Cat 8 will use evals/evals.json + behavioral-smoke.sh to drive hook fixtures", grep `evals.json` and `behavioral-smoke.sh` first to confirm they support that operation shape. The spec assumed; reality differed by ~75 lines of bash. (Aligns with the "Spec-Writing Discipline" rule about substrate claims.)
- **Renumber explicitly on regression.** When a `/overcomplicated` trim folds WU13's content into WU1 and renumbers former WU14→WU13, reuse-the-ID-for-different-work creates a documentation hazard. Prefer "WU13a" or "WU15→WU13(was)" notation.
- **Stage 5.5 placement is a precedent.** Conditional stages between numbered stages should always have a header that calls out their conditional nature ("Runs after Stage 5, before Stage 6, only when X") so downstream readers know when it applies.
- **Empirical gates for hook-firing-on-subagent are session-restart bound.** WU12 in this spec is genuinely impossible to fully verify in the same session that just installed the hook. Plan for the verification-split shape from the start; don't pretend otherwise.

### Most-useful spec sections
- **Threat Model** — load-bearing for every downstream decision. The reframe from "containment" to "scope guardrail" cascaded through hook design, agent prompt, error messages, and even install.sh PM2 detection wording.
- **Closed `skip_reason` enum table** — kept the implementation honest. Every code path that skips Stage 5.5 had to choose from 6 documented values. Made AC18 measurable.
- **Per-Runner Exit Code Handling table** — the agent prompt and prism.md both reference it; the table is the single source of truth.

### Least-useful / friction-causing spec sections
- The "former WU13" / "current WU13" cross-references after rev3 trim (see Discovery #8).
- The spec's tests.md described eval fixtures in a shape `evals.json` can't actually consume (Discovery #1) — tests.md is "spec-blind" by design but its blindness here was load-bearing.

## Verification Status

| Criterion | Status | Mechanism |
|-----------|--------|-----------|
| AC1 (install layout) | text_conforms + behaviorally_verified | `bash test.sh` Cat 7 install dry run + Cat 10 file presence |
| AC2-AC5 (hook block/allow/no-op) | behaviorally_verified | `bash scripts/behavioral-smoke.sh` 7 hook fixtures pass + 8 inline stdin smoke tests |
| AC6-AC7 (runner detection) | text_conforms | prism.md Stage 5.5.0 documents detection logic; live verification post-WU4-execute |
| AC8-AC9 (skip behavior) | text_conforms | prism.md Stage 5.5.1 + 5.5.0 document; live verification post-execute |
| AC10 (ambient subagent hook firing) | behaviorally_verified (prior-art) | Verified 2026-05-01 via dangerous-commands.sh instrumentation |
| AC11 (subagent return ≤ 2K tokens) | text_conforms; behavioral deferred | Agent prompt enforces; fixture exists; word-count proxy requires subagent dispatch |
| AC12-AC13 (test.sh passes; dangerous-commands.sh byte-identical) | behaviorally_verified | `bash test.sh` 132/0; `dangerous-commands.sh` not edited (verifiable via `git diff`) |
| AC14 (output log persistence) | text_conforms | prism.md Stage 5.5.5 documents path |
| AC15 (pytest exit codes) | text_conforms + fact_checked | Agent prompt has full per-runner table; codes match pytest docs |
| AC16 (binary-missing) | text_conforms | prism.md Stage 5.5.0 binary-missing precheck documented |
| AC17 (false-pass) | text_conforms | Agent prompt textual scan over last 200 lines |
| AC18 (skip_reason synthesis messages) | text_conforms | All 6 enum values present in prism.md (Cat 10 verifies) |
| AC19 (multi-class tiebreak) | text_conforms | Agent prompt documents highest-severity-wins rule |
| AC20 (zero-failures) | text_conforms | Agent prompt + prism.md both document `findings: []` path |
| AC21 (migration forward-compat) | text_conforms | prism.md Stage 5.5.6 schema documented; default-construct rule stated |
| AC22 (unsupported override) | text_conforms | prism.md Stage 5.5.0 closed-set validation documented |
| AC23 (hook-wiring self-probe) | text_conforms | prism.md Stage 5.5.2 has the probe logic + skip path |
| AC24 (stale-state recovery) | text_conforms | prism.md Stage 5.5.3 has the reset logic |

**Behaviorally verified:** AC2-AC5, AC10 (prior-art), AC12-AC13. All others are `text_conforms` with behavioral verification deferred to live `/prism` exercise post-restart.

This is the same disposition vocabulary the spec/adversarial introduced: text-conformity ≠ behavioral verification. We are honest about which is which.

## Status

- `stages.execute.status: complete` (confidence 0.85)
- `stages.debrief.status: complete` (this document)
- `completed: true` (forthcoming after this debrief lands)
- 17/17 tasks closed in this session

Ready to commit. The next session can proceed with WU12 + AC11 behavioral verification by running `/prism` against any project with a test runner, or by directly invoking the new `test-debt-classifier` subagent.
