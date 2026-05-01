# Change Specification: test-debt-in-prism (Revision 3)

> **Revision history:** see `spec.diff.md`. Rev 1 → Rev 2: Stage 3 critique + threat-model reframe. Rev 2 → Rev 2-polish: re-Diverge inline fixes. Rev 2-polish → Rev 3: `/overcomplicated` trim — runner support narrowed from 6 to 2 (pytest + bash test.sh), AC consolidation, WU13 folded into WU1.

## Summary

Add a conditional Stage 5.5 to `/prism` — a `test-debt-classifier` subagent that runs the project's test suite (pytest or `bash test.sh` in v1; other runners deferred to v2), classifies each pre-existing failure into one of five categories (real-issue / test-infrastructure-broken / drift / abandoned / quarantine candidate), and feeds findings into Stage 6 Synthesis as another themable contributor — with a **scope guardrail** via a new per-agent Bash allowlist hook (`prism-bash-allowlist.sh`) that runs alongside `dangerous-commands.sh`.

## Threat Model (NEW — explicit framing)

The per-agent Bash allowlist hook is a **scope guardrail**, not a security boundary. It catches agent confusion and surfaces visible errors when the test-debt-classifier reaches outside its declared scope. It does **not** defend against:

- **Hostile test code** in downloaded/external repos. The user-side mitigation is `SAIL_PRISM_RUN_TESTS=0` env-var opt-out. Lower priority for first-party use; documented as accepted v1 limitation.
- **Bypass via shell metacharacters** (semicolons, command substitution, etc.) inside otherwise-allowed commands. Not modeled — there's no adversary at the threat-model layer that justifies the machinery.
- **Child-process invisibility** — `bash test.sh` running its own commands as child processes is fine; that's just the test suite running. PreToolUse hooks fire on Claude Code Bash tool calls, not on child processes spawned by allowed commands. This is not a defended-against threat.

**What the guardrail does defend against:** the test-debt-classifier agent improvising — reaching for `curl`, `kubectl`, `aws`, etc. instead of running the test runner. That's an *agent confusion* signal (the agent prompt drifted, or context-exhaustion produced off-script behavior). The hook surfaces a visible error, which helps debugging and prevents silent off-script execution.

**Existing universal safety:** `dangerous-commands.sh` continues to enforce the universal destructive-pattern blocking layer for ALL Bash calls (this agent and every other). Not modified by this blueprint.

## Classification (5 categories, severity ordering)

1. **real-issue** (critical) — code under test is broken; test correctly catches it
2. **test-infrastructure-broken** (high) — test suite cannot run cleanly: collection errors, import errors, missing fixtures, broken setup, missing runner binary, runner timeout. Distinct from real-issue because the *test* is unrunnable, not because the *code* is broken.
3. **drift** (medium) — test references API, symbol, schema, or contract that has moved/renamed/changed; test logic is sound but the world moved
4. **abandoned** (medium) — test was for a feature, endpoint, or capability that was never finished or has been removed; test is obsolete
5. **quarantine candidate** (low) — flaky/timing-dependent/non-deterministic; passes on retry. Should be marked as such or removed.

Per failing test the agent: reads test + symbol(s) under test, classifies into one of the above, surfaces to Synthesis with severity tag and a one-line "why this is failing." Single retry IS in scope as the quarantine-candidate signal.

**Multi-classification tiebreak:** When a failure plausibly fits multiple categories, the highest-severity category wins. Secondary observations are folded into the reasoning string ("classified as drift; also exhibits flake on retry"). Inter-run determinism preferred over multi-finding-per-failure noise.

**Zero-failures behavior:** Agent emits `findings: []` and exits silently with `status: complete`. No "all tests pass" finding contributes to synthesis.

## skip_reason Enumeration (closed set)

The `skip_reason` field on the `test_debt` step is a CLOSED enum. Every code path that sets stage status to `skipped` must use one of these exact values; synthesis output renders skip-reason-specific messaging:

| Value | Set when | Synthesis message |
|-------|----------|-------------------|
| `no_runner_detected` | Detection found no recognized runner; project may not have tests, or uses an unsupported runner | "Stage skipped: no recognized test runner detected." |
| `opt_out_env_var` | `SAIL_PRISM_RUN_TESTS=0` is set | "Stage skipped: test runs disabled via SAIL_PRISM_RUN_TESTS=0." |
| `runner_binary_missing` | Detection found a runner config (e.g., `pytest.ini`) but `command -v <runner>` failed | "Stage skipped: <runner> not on PATH; project declares it but binary unavailable." |
| `runner_timeout` | Bash-tool timeout fired during runner invocation | (Not a skip — produces `test-infrastructure-broken` finding instead. Not a `skip_reason` value.) |
| `polyglot_ambiguous_no_override` | Both pytest config AND `test.sh` are present; `SAIL_PRISM_TEST_RUNNER` not set to disambiguate | "Stage skipped: both pytest config and test.sh detected. Set SAIL_PRISM_TEST_RUNNER=pytest or SAIL_PRISM_TEST_RUNNER='bash test.sh' to choose." |
| `unsupported_override` | `SAIL_PRISM_TEST_RUNNER` set to a value outside v1's supported set (`pytest`, `bash test.sh`) — e.g., `bun`, `cargo`, `go`, `npm`, `jest`, etc. | "Stage skipped: SAIL_PRISM_TEST_RUNNER=<value> not in v1's supported set (pytest, bash test.sh). Other runners deferred to v2." |
| `hook_not_wired` | Stage 5.5 entry self-probe detected that `prism-bash-allowlist.sh` is not wired in the active settings.json (the user installed but didn't merge the hook into their PreToolUse Bash matcher; or settings.json was loaded BEFORE install) | "Stage skipped: prism-bash-allowlist hook is not wired in your settings.json. Either run `bash install.sh` and restart Claude Code, or add this entry to PreToolUse Bash hooks: `~/.claude/hooks/prism-bash-allowlist.sh`." |

Note: build-error-precludes-tests, false-pass-detected, and rc=2/3/4/5 cases are NOT `skip_reason` values — they emit `test-infrastructure-broken` findings while the stage status remains `complete`. The stage ran; it just produced findings rather than skipped.

## What Changes

### Files/Components Touched

| File | Nature of Change |
|------|------------------|
| `agents/test-debt-classifier.md` | **add** — new subagent (Bash + Read + Glob + Grep), 5-category classifier prompt with output cap and per-runner exit-code handling |
| `hooks/prism-bash-allowlist.sh` | **add** — new PreToolUse hook; substring-prefix match against allowlist; scope-violation feedback message; fail-open |
| `commands/prism.md` | **modify** — add Stage 5.5 wiring, runner detection (language-primary heuristic), opt-out gate, Synthesis update, wizard state schema, migration handling |
| `settings-example.json` | **modify** — add `prism-bash-allowlist.sh` to PreToolUse Bash matcher (alongside existing entries) |
| `install.sh` | **modify** — agent count `12 → 13`, hook count `18 → 19` (utility unchanged) |
| `README.md` | **modify** — agent count, hook count if surfaced |
| `agents/README.md` | **modify** — new entry for test-debt-classifier |
| `.claude/CLAUDE.md` (this repo) | **modify** — hook count (`19 shell files: 18 hooks + 1 utility` → `20 shell files: 19 hooks + 1 utility`) |
| `test.sh` | **modify** — Categories 3, 4, 5, 6, 7, 8 cover new files + behavioral evals |
| `evals/evals.json` | **modify** — add 6 fixtures for prism-bash-allowlist.sh (allowed cmd; non-allowlisted cmd; main session; different agent_type; binary-missing path; exit-0-with-failures path) |

### External Dependencies

- [x] **None** — pure shell + markdown changes. No new package deps.

### Database/State Changes

- [x] **None** at the persistence layer.
- [x] **State format addition (in-memory):** prism wizard state schema gains a `test_debt` step. Fields: `status`, `runner_detected`, `failure_count`, `findings` (array), `output_log_path`, `skip_reason`. **Additive** — existing wizards lacking the field treat it as `pending` (forward-compat default).

## Migration from Existing Prism Installations (NEW)

Existing prism installations have wizard state files lacking `test_debt`. Upgrade contract:

1. **State file forward-compat:** absent `test_debt` field treated as `{status: "pending", runner_detected: null, findings: [], skip_reason: null}` — no schema-validation errors.
2. **install.sh in-place upgrade:** running `bash install.sh` over an existing install copies new agent + hook + updated prism.md + settings; does NOT reset wizard state files.
3. **Stale agent file cleanup:** if a previous install attempt left a stale `~/.claude/agents/test-debt-classifier.md`, the install.sh `cp` overwrites it with the source-of-truth.
4. **Settings reload caveat:** users with active sessions when they install will not pick up the new hook until next session restart (settings.local.json hooks are session-cached — known constraint per anti-pattern-catalog debrief). Install messaging calls this out.

## Preservation Contract (What Must NOT Change)

- **Behavior that must survive:**
  - All existing prism stages 1-6 produce identical output when Stage 5.5 is skipped (no runner / opt-out / no failing tests / binary missing)
  - **All 6 lens agents (cohesion-lens, consistency-lens, coupling-lens, dry-lens, kiss-lens, yagni-lens) remain read-only** (Read/Glob/Grep tools only)
  - **All 6 reviewer agents (architecture-, cloudformation-, security-, performance-, quality-, spec-reviewer) declare Bash in tools but do not actively reference Bash usage in their prompts** (effectively read-only via prompt discipline). This blueprint does not modify them.
  - `dangerous-commands.sh` is byte-identical post-change; remains the universal destructive-pattern safety layer for ALL Bash calls
  - All other PreToolUse hooks (`secret-scanner.sh`, `protect-claude-md.sh`, etc.) continue to fire as today
  - Main-session Bash calls behave exactly as today (the new hook is a no-op when `agent_type` is absent or doesn't match `test-debt-classifier`)
  - Synthesis output backward compatibility: existing finding sources continue to be themed; test-debt findings ADD to the synthesis input, do NOT replace or alter existing finding shapes
  - `bash test.sh` continues to pass on this repo with the new files in place

- **Interfaces that must remain stable:**
  - PreToolUse hook contract (read JSON from stdin, exit 0/1/2 with stderr feedback)
  - Subagent prompt input/output shape
  - prism wizard state file format additivity (existing consumers ignore unknown fields; new consumers tolerate absent fields)
  - `SAIL_DISABLED_HOOKS` environment-variable disable mechanism — must work for the new hook (`SAIL_DISABLED_HOOKS=prism-bash-allowlist`)

- **Performance bounds that must hold:**
  - Hook execution time ≤ 100ms for the no-op fast path (when `agent_type` is null or non-matching)
  - Hook execution time ≤ 500ms for the allowlist-enforcement path
  - **Subagent return-message ≤ 2K tokens** regardless of test suite size (achieved via explicit prompt cap in WU1; verified by AC15 via fixture project)

## Per-Runner Exit Code Handling

The agent uses exit codes as the primary failure signal. v1 supports two runners:

| Runner | Exit codes | Classification consequence |
|--------|-----------|---------------------------|
| **pytest** | 0=passed, 1=failures, 2=interrupted, 3=internal error, 4=usage error, 5=no tests collected | rc=0 → emit empty findings (with false-pass check); rc=1 → classify each failure; rc=2 → `test-infrastructure-broken: interrupted`; rc=3 → `test-infrastructure-broken: pytest internal error`; rc=4 → `test-infrastructure-broken: invalid pytest invocation` (suggests allowlist drift); rc=5 → `test-infrastructure-broken: no tests collected` |
| **bash test.sh** | 0=pass, !=0=fail (project-specific convention) | rc=0 → empty findings (with false-pass check); non-zero → parse output for failure markers; if no markers parseable → `test-infrastructure-broken: bash test.sh exit X with no failure markers` |

**v2 deferred runners:** `bun test`, `cargo test`, `go test`, `npm test`. When a project lacks pytest config and lacks `test.sh`, Stage 5.5 sets `skip_reason: no_runner_detected`. When the user sets `SAIL_PRISM_TEST_RUNNER` to a v2 runner, Stage 5.5 sets `skip_reason: unsupported_override` with a message naming the v1-supported set.

**False-pass check (rc=0 but tests failed):** scan output for textual failure markers (forced output flags ensure textual output for both v1 runners). Patterns:
- `^FAIL\b`, `^FAILED\b`, `\b\d+ failed\b`, `\bFAILURES\b`

**Scan window:** last 200 lines of combined stdout+stderr (verbose runners produce 50+ lines per test failure trace; 50 too narrow).

If any pattern matches despite rc=0, emit `test-infrastructure-broken: exit code 0 but failure markers in output (likely wrapper-script swallowing exit code)` and abort per-test classification.

**Binary-missing precheck:** before invoking runner, run `command -v <runner>`. If absent → set `skip_reason: "runner_binary_missing"`, stage status `skipped`, emit synthesis finding `test-infrastructure-broken: <runner> not on PATH (project declares <runner> but binary unavailable)`. Caveat: `command -v` resolves PATH-shadowed wrappers; runners requiring venv activation or `direnv` may resolve to a system binary that errors at runtime. In that case, the runner's first invocation produces a setup-error exit code that flows into the runner's normal exit-code handling above (rc=4 for pytest, rc=2 for go, etc.). The precheck is a fail-fast for the common case, not a guarantee.

**Timeout:** test runner invocation uses Bash tool's built-in `timeout` parameter, set explicitly per call (default 300_000ms = 5 min, configurable via `SAIL_PRISM_TEST_TIMEOUT`; max 600_000ms / 10 min per Claude Code Bash tool limit). The agent prompt MUST specify the timeout parameter on every test-runner Bash call — without it, the harness default applies (typically 120_000ms / 2 min) which is too short for many real suites. On timeout, the Bash tool returns a non-zero status with truncated stdout up to the timeout point. The agent classifies as `test-infrastructure-broken: runner timeout (no exit code)` and does NOT attempt per-test classification on the partial output (truncation point is unreliable). Partial output IS preserved to the log file for user inspection.

**Forced output flags:** to surface useful failure detail, agent invokes runners with output-streaming/verbose flags:
- pytest: `pytest -v --tb=line --no-header`
- bash test.sh: as-is (project-defined; the project's own test.sh dictates its output format)

## Success Criteria

| # | Criterion | How to Verify |
|---|-----------|---------------|
| AC1 | **Install dry run produces expected file layout with valid syntax/JSON** — agent file exists with required frontmatter, hook file syntax-valid (no `set -e`, has `set +e`), counts updated (`install.sh` agent 12→13 + hook 18→19), `settings-example.json` valid JSON with new hook on PreToolUse Bash matcher | `test.sh` Categories 3+4+5+6+7 (consolidated; was 5 separate ACs in rev2) |
| AC2 | Hook blocks non-allowlisted commands when `agent_type=test-debt-classifier` | Behavioral eval: non-allowlisted command → exit 2; stderr contains "outside declared scope" |
| AC3 | Hook allows allowlisted commands when `agent_type=test-debt-classifier` | Behavioral eval: e.g., `pytest -v` → exit 0 |
| AC4 | Hook is no-op when `agent_type` is absent (main session) | Behavioral eval: stdin without agent_type → exit 0 regardless of command |
| AC5 | Hook is no-op when `agent_type` is set to a different agent | Behavioral eval: stdin with different agent_type → exit 0 |
| AC6 | Runner detection identifies pytest when `pytest.ini` or `pyproject.toml [tool.pytest]` is present AND pytest binary on PATH | Direct shell test |
| AC7 | Runner detection identifies `bash test.sh` when `test.sh` exists in repo root and is executable | Direct shell test |
| AC8 | Stage 5.5 displays `—` with `skip_reason: no_runner_detected` when no runner detected | Inspection of state transitions |
| AC9 | Stage 5.5 displays `—` with `skip_reason: opt_out_env_var` when `SAIL_PRISM_RUN_TESTS=0` regardless of detection | Inspection of state transitions |
| AC10 | (Empirical, ambient) PreToolUse hooks fire for subagents in general AND `agent_type` is populated | Already verified 2026-05-01 via `dangerous-commands.sh` instrumentation; documented in `prior-art.md`. **Distinct from WU12** (which verifies the NEW hook specifically). |
| AC11 | **Subagent return-message ≤ 2K tokens regardless of test suite size** | Behavioral: dispatch test-debt-classifier against `tests/fixtures/test-debt-100-failures/` (WU13 fixture); count tokens via word-count proxy. 2K tokens ≈ 1500 words → assert word-count ≤ 1500 |
| AC12 | All existing `bash test.sh` checks still pass with the new files in place | `bash test.sh` exit 0 |
| AC13 | `dangerous-commands.sh` is byte-identical to pre-change version | `diff` check in test.sh |
| AC14 | Stage 5.5 raw output is persisted to `.claude/wizards/prism-<id>/test-debt-output.log` when stage runs | Inspection of state transitions |
| AC15 | Pytest exit code handling: rc=1 → "failures present" path; rc=5 → `test-infrastructure-broken: no tests collected`; rc=2/3/4 → `test-infrastructure-broken` with specific reason | Direct shell test with synthetic pytest invocations producing each exit code |
| AC16 | Binary-missing detection: when detection identifies pytest but `pytest` not on PATH, stage skips with `skip_reason: runner_binary_missing` | Direct shell test on fixture project with pytest.ini but no pytest installed |
| AC17 | False-pass detection: runner exits 0 but output contains failure markers → `test-infrastructure-broken: exit code 0 but failure markers in output` | Behavioral eval with crafted output |
| AC18 | Skip-reason telemetry: synthesis output displays specific skip reason from closed enum (`no_runner_detected` / `opt_out_env_var` / `runner_binary_missing` / `polyglot_ambiguous_no_override` / `unsupported_override`); each value renders the message specified in skip_reason Enumeration table | Inspection of synthesis output transitions for each enum value |
| AC19 | Multi-classification tiebreak: a failure matching both drift and quarantine-candidate is classified as drift (higher severity); secondary observations folded into reasoning string | Behavioral eval with crafted failure case |
| AC20 | Zero-failures behavior: zero failing tests → `findings: []`, status `complete`, no synthesis contribution | Direct shell test on fixture project with all-passing tests |
| AC21 | Migration forward-compat: wizard state file lacking `test_debt` field is treated as `pending` without schema-validation error AND consumer-side default-construction occurs in prism.md state-loading path | Direct test on synthetic legacy state file; inspection of WU4/WU7 |
| AC22 | Unsupported override: `SAIL_PRISM_TEST_RUNNER=<value-outside-v1-set>` produces `skip_reason: unsupported_override` and synthesis message names supported runners (`pytest`, `bash test.sh`) | Direct shell test with override env var set to unsupported value (e.g., `jest`) |
| AC23 | **Hook-wiring self-probe (PM2 fix):** at Stage 5.5 entry, prism.md inspects `~/.claude/settings.json` for an entry referencing `prism-bash-allowlist.sh` under `hooks.PreToolUse[].hooks[].command`. If absent, stage skips with `skip_reason: hook_not_wired` and synthesis message tells the user how to fix. The probe runs BEFORE subagent dispatch — so the agent never executes Bash without its scope guardrail in place. | Direct shell test with synthetic settings.json (with and without the hook entry) |
| AC24 | **Stale wizard state recovery (PM4 fix):** if `test_debt.status == "running"` on Stage 5.5 entry AND the wizard's recorded session_id differs from the current session, treat as `interrupted_prior_run` and reset state to `{status: "pending", findings: [], skip_reason: null}` before proceeding. The output log from the prior run is preserved (log files are append-only and non-destructive). | Direct test on synthetic state file with stale `status: running` from a different session_id |

## Failure Modes

| What Could Fail | Detection Method | Recovery Action |
|-----------------|------------------|-----------------|
| Test runner takes >5 min | Bash tool built-in timeout | Classify as `test-infrastructure-broken: runner timeout`; preserve partial output to log file |
| Test runner output too large (>500 KB) | Byte count check on captured stdout/stderr | Truncate to last 500 KB with `--- truncated ---` marker; classification proceeds on truncated; log file holds full |
| Hook blocks legitimate runner subcommand (allowlist drift) | Hook fail-opens via `set +e`; `SAIL_DISABLED_HOOKS=prism-bash-allowlist` toggles off; clear error message tells user what was blocked | User adjusts allowlist (in agent file or hook source) and re-installs; or sets disable env-var BEFORE Claude Code session start (env is inherited from parent process; mid-session env-var changes do not propagate to the running Claude Code's hook process — recovery requires session restart) |
| Hook does not fire on subagent Bash (regression of confirmed behavior) | WU12 empirical gate verifies for the new hook specifically | Halt blueprint; investigate; load-bearing assumption |
| Settings cache prevents new hook from being picked up after install | First-time users in a new session pick it up; existing-session users wouldn't | User restarts Claude Code session after install — accepted constraint, called out in install messaging |
| **PM2:** install.sh does NOT auto-merge the new hook into user's existing `~/.claude/settings.json` — install message tells user to manually merge | Stage 5.5 entry self-probe (AC23) detects unwired hook BEFORE dispatching the subagent | Stage skipped with `skip_reason: hook_not_wired` and user-facing message naming the JSON entry to add. Self-disabling beats silent containment failure. |
| **PM4:** User Ctrl-C's mid-Stage-5.5; wizard state stays `status: running`; next /prism run could read stale findings or refuse to proceed | Stale-state detection on Stage 5.5 entry (AC24) — compares wizard's session_id to current session_id | If stale, reset state to `pending` (preserving output log file) and proceed normally |
| Project has both pytest config AND `test.sh` | Detection sees both v1-supported runners | Use `SAIL_PRISM_TEST_RUNNER` to disambiguate; if not set, skip with `polyglot_ambiguous_no_override` |
| Test runner has side effects (writes to real DB, sends emails, deploys) | Cannot detect generically | `SAIL_PRISM_RUN_TESTS=0` env var skips entirely; users must opt out for hostile/side-effect-heavy repos. Documentation calls this out prominently. |
| Test runner script invokes destructive shell as child processes (`bash test.sh` containing destructive commands) | NOT detectable by hooks (child processes invisible to PreToolUse) | Documented as accepted limitation; users running `/prism` on unaudited repos should set `SAIL_PRISM_RUN_TESTS=0`. NOT a containment claim — known threat-model boundary. |
| Runner exits 0 but tests actually failed (wrapper-script swallowing exit code) | False-pass detection: textual scan over last 200 lines | Emit `test-infrastructure-broken: exit code 0 but failure markers in output`; abort per-test classification |
| User sets `SAIL_PRISM_TEST_RUNNER=<v2-runner>` (bun/cargo/go/npm/jest/etc.) | Override validates against v1 supported set | Set `skip_reason: unsupported_override`; emit synthesis message naming v1 runners + noting v2 may add support |
| Runner binary missing despite filesystem markers | `command -v <runner>` precheck before invocation | Skip stage with `skip_reason: "runner_binary_missing"`; emit synthesis finding |
| Classification produces unhelpful output ("real-issue for everything") | User-perceptible — synthesis becomes noise | v1 acceptable risk — agent prompt is the lever; iterate on prompt in v2 if it surfaces |
| Subagent return-message exceeds 2K-token bound | AC11 measures via fixture | Agent prompt enforces top-50-by-severity truncation; if still overflows, truncate to top-25 + count-summary |
| Agent finds no failing tests but still produces noise in synthesis | AC20 enforces `findings: []` path | Verified via behavioral test |
| Single-retry quarantine signal produces false positives (transient resource contention) | User-perceptible classification noise | v1 accepted limitation; document in agent prompt; v2 may add multi-run statistics |
| Concurrent prism runs conflict on output log path | Same as existing prism stages — single concurrent run assumption | Inherits existing prism single-instance assumption; no new mitigation needed |

## Rollback Plan

1. `git revert <commit-sha>` to remove all blueprint commits — pure code change, no data migrations
2. `bash install.sh` to re-deploy previous-state hooks/agents to `~/.claude/`
3. New hook file `~/.claude/hooks/prism-bash-allowlist.sh` removed by install if not in source; manual `rm` is safe (settings.json no longer references it after revert)
4. New agent file `~/.claude/agents/test-debt-classifier.md` cleaned by install or manual removal
5. State cleanup: none — no persistent state created; output logs in `.claude/wizards/prism-*/` are per-run and self-cleaning
6. Existing wizard state files with `test_debt` field continue to load correctly under reverted code (forward-compat in both directions — old code ignores the field)
7. Notify: nobody — toolkit-internal change

## Dependencies (Preconditions)

- [x] Anti-pattern-catalog blueprint shipped (predecessor; commits 36bff79 + e53a7d2 — confirmed 2026-04-30)
- [x] Hook feasibility empirically verified for general subagent dispatch (verified 2026-05-01; documented in prior-art.md)
- [x] `bash` and `jq` available on installation target (existing prism requirements)
- [x] Existing test framework conventions: bash `test.sh` exit semantics, behavioral-smoke.sh fixture format

## Open Questions — Resolved

### Q1: Test runner timeout policy

**Resolution (rev2):** Use Bash tool's built-in `timeout` parameter (default 300_000ms = 5 min, configurable via `SAIL_PRISM_TEST_TIMEOUT`). On timeout, classify as `test-infrastructure-broken: runner timeout`. No heartbeat mechanism — built-in timeout is architecturally simpler and the subagent return path naturally surfaces the timeout. (Rev1 specified heartbeat; replaced as result of CF-4 critique.)

### Q2: Raw test output persistence

**Resolution:** Yes, persist to `.claude/wizards/prism-<run-id>/test-debt-output.log`. Note convention departure: wizard dirs traditionally hold only `state.json` (per `docs/WIZARD-STATE.md`). This blueprint adds artifact files to wizard dirs as a deliberate extension; documented in WIZARD-STATE.md update.

### Q3: Allowlist hook v1 implementation

**Resolution:** Hard-coded substring-prefix match for `test-debt-classifier`. No metacharacter parsing (not needed under scope-guardrail framing). Refactor pressure for v2 genericity is low — appears only when a second Bash-using prism agent is added.

### Q4: Token budget for orchestrator context

**Resolution (rev2, tightened):** Subagent return-message capped at **2K tokens** via explicit prompt-level constraint in WU1. Agent prompt: "Final message MUST be ≤2K tokens. Format: JSON array of `{test_id, category, severity, reason}`. Do NOT quote raw test runner output. If >50 failures, emit top-50 by severity + count-summary line." AC15 verifies via fixture-driven measurement. Settles the rev1 1K-vs-3K contradiction in favor of a single measurable bound. Subagent isolation contains the *intermediate* runner output (10K+ tokens never reach orchestrator); the prompt cap contains the *return value*.

### Q5: Per-project override for global SAIL_PRISM_RUN_TESTS=0 (NEW)

**Resolution:** Deferred to v2. v1 honors only the env var (binary global). Workaround for users wanting per-project enable: shell function or `direnv` setup at the project level (`SAIL_PRISM_RUN_TESTS=1 claude` in project-specific shell config). Future v2 enhancement: `.claude/sail.local.json` with `prism: { run_tests: true }` per-project override.

## Senior Review Simulation

### What they'd ask about

- **"What if the test runner script does destructive things as child processes?"** — Not detectable by PreToolUse hooks (child processes invisible). Documented as accepted v1 limitation; users running `/prism` on unaudited repos use `SAIL_PRISM_RUN_TESTS=0`. Threat model is "scope guardrail for first-party use," not "sandbox for adversarial code."
- **"Why don't you also retrofit allowlists to the existing reviewer agents that declare Bash?"** — Those agents don't actively use Bash in their prompt content (effectively read-only by prompt discipline); retrofitting is scope creep beyond this blueprint. Could be a separate cleanup blueprint that either removes Bash from those agents' frontmatter (honest) or adds allowlists for them (parallel pattern).
- **"What if classification quality is poor?"** — Acceptable v1 risk. Agent prompt is the lever; iterate in v2 if user reports noise. Single-retry quarantine signal will produce false positives for transient resource contention; documented limitation.
- **"What if the `test_debt` step's `findings` array bloats wizard state file size?"** — 50 findings × ~120 bytes JSON each ≈ 6 KB; well within reasonable state size. AC15's 2K-token cap on subagent return constrains upstream.

### Non-obvious risks

- **The threat-model reframe is load-bearing.** If a future maintainer reverts to "containment" framing without rebuilding the threat model, they may chase nonexistent threats and reintroduce architectural complexity (metacharacter parsing, sandboxing) that doesn't earn its keep. The Threat Model section + `feedback_threat_model_first_party_tooling` memory together preserve the reasoning.
- **The H1-style false-invariant pattern is recurring risk.** Saying "all 11 prism agents are read-only" is the kind of summary that sounds true and wasn't checked. Future preservation-contract claims should be verified against actual frontmatter, not paraphrased from the brief. This is a process lesson, not a spec change.
- **AC11's token-counting via word-count proxy is a measurable approximation, not a rigorous count.** If the bound becomes contested, swap in a token counter; for now, word-count is sufficient for the verification AC.

### Standard approach we might be missing

- **Tag-based test filtering (markers like `@pytest.mark.flaky`)** — v1 reads test source and incidentally surfaces markers in classification reasoning. v2 enhancement: structurally parse markers as classification hints.
- **Log file rotation in wizard dirs** — `test-debt-output.log` accumulates per-run; no automatic cleanup. v2 may want a `--prune-wizard-logs` flag.

### What bites first-timers

- **`agent_type` field is absent for main-session calls (not present-and-empty)** — hook code uses `jq -r '.agent_type // empty'`. Without `// empty`, jq returns `null` literal which trips string comparisons.
- **Settings re-read requires session restart** — testing the new hook in the same session you installed it may not fire. Test via direct invocation (pipe stdin to script) for in-session verification, OR use WU12 empirical gate which dispatches a real subagent.
- **Projects with both pytest config AND `test.sh` need explicit `SAIL_PRISM_TEST_RUNNER` override** — auto-detection skips with `polyglot_ambiguous_no_override` rather than guessing. Document the override in the install messaging.

## Decisions

Architectural choices made in this spec, for reference during implementation:

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Hook architecture | NEW separate hook (`prism-bash-allowlist.sh`), NOT modifying `dangerous-commands.sh` | Zero meaningful overlap; defense-in-depth pattern; smaller blast radius; secret-scanner.sh + dangerous-commands.sh coexistence precedent |
| Hook role | **Scope guardrail** (catches agent confusion via visible error), NOT security containment | Threat model reframe per `feedback_threat_model_first_party_tooling`; first-party tooling on user's own code has no adversary |
| Hook v1 implementation | Substring-prefix match against allowlist; case-statement on `agent_type`; no metacharacter parsing | Scope-guardrail framing makes airtight matching unnecessary; YAGNI for v2 genericity |
| Classification location | INSIDE the subagent | Subagent isolation prevents 10K+ tokens of intermediate runner output from reaching orchestrator; combined with 2K return-cap addresses prism-context-exhaustion |
| Token budget bound | **2K tokens on subagent return-message** (single bound, no contradiction) | AC15 verifies via fixture; agent prompt enforces |
| Liveness mechanism | **Bash tool built-in `timeout` parameter** (no heartbeat) | Architecturally simpler; subagent return naturally surfaces timeout; replaces wishful heartbeat from rev1 |
| Output streaming | Force verbose flags for v1 runners (pytest `-v --tb=line --no-header`; bash test.sh as-is) | Ensures detail when classifying |
| Detection (v1: 2 runners) | Look for pytest config (pytest.ini / pyproject.toml [tool.pytest] / setup.cfg [tool:pytest]) → pytest. Look for executable `test.sh` in repo root → bash test.sh. If both → use `SAIL_PRISM_TEST_RUNNER` or skip with `polyglot_ambiguous_no_override`. If neither → skip with `no_runner_detected` | Simple binary detection; no language-primary file-counting needed for 2 runners |
| Binary-missing handling | `command -v <runner>` precheck; skip with `runner_binary_missing` | Replaces undefined behavior from rev1 |
| Output persistence | `.claude/wizards/prism-<session_id>/test-debt-output.log` | Convention departure documented in WIZARD-STATE.md |
| Runner exit codes | Per-runner table (Per-Runner Exit Code Handling section); pytest rc=1 is failures (corrected from rev1) | Factual correctness; CF-3 fix |
| False-pass detection | Scan last 200 output lines for textual failure markers when rc=0 | Catches wrapper-script exit-code swallowing; textual-only since both v1 runners produce textual output by default |
| Multi-classification | Highest-severity wins; secondary observations in reasoning string | Inter-run determinism over multi-finding noise |
| Zero-failures | Empty findings array; status complete; no synthesis contribution | Specified behavior, not implicit |
| Migration | Forward-compat: absent `test_debt` field treated as pending | Existing wizard state files load without modification |
| Opt-out gate | `SAIL_PRISM_RUN_TESTS=0` (binary global, env-var-only in v1) | Per-project override deferred to v2 |
| Agent name | `test-debt-classifier` (renamed from `test-debt-reviewer` at user direction) | Honest naming — executor role differs from existing read-only `*-reviewer` agents |
| Override scope (v1) | `SAIL_PRISM_TEST_RUNNER` accepts `pytest` or `bash test.sh`. Other values (bun, cargo, go, npm, jest, etc.) produce `skip_reason: unsupported_override` with synthesis message naming v1 supported set | v1 ships exit-code handling + forced-output flags for 2 runners. Adding more is small marginal work in v2 once we have one running. The override env var primarily disambiguates polyglot projects. |
| Skip reason vocabulary | Closed enum (`no_runner_detected`, `opt_out_env_var`, `runner_binary_missing`, `polyglot_ambiguous_no_override`, `unsupported_override`); see skip_reason Enumeration section | Prevents implementation invention; synthesis renders specific message per value (AC18) |

## Work Units

| ID | Description | Files | Dependencies | Complexity | TDD |
|----|-------------|-------|--------------|------------|-----|
| WU1 | Create `agents/test-debt-classifier.md` — frontmatter (tools=Bash,Read,Glob,Grep), 5-category classifier prompt with: (a) declared allowlist enumeration (pytest, `bash test.sh`, `git log`); (b) inline per-runner exit-code handling table for pytest + bash test.sh (folded in from former WU13); (c) ≤2K-token output cap with format spec; (d) multi-classification tiebreak rule; (e) zero-failures behavior; (f) no-recursion notice; (g) single-retry quarantine signal; (h) explicit timeout-parameter requirement on every Bash test-runner invocation (e.g., `Bash(command="pytest -v --tb=line", timeout=300000)`); (i) partial-output handling on timeout (do NOT classify on truncated stdout; emit only meta-finding `test-infrastructure-broken: runner timeout`); (j) textual false-pass scan over last 200 lines | `agents/test-debt-classifier.md` | — | Medium | false |
| WU2 | Create `hooks/prism-bash-allowlist.sh` — fail-open shebang, `SAIL_DISABLED_HOOKS` toggle, `agent_type` extraction via `jq -r '.agent_type // empty'`, case-statement dispatch, **substring-prefix allowlist match** for `test-debt-classifier` (test runners + `git log`), exit 0/2 with scope-violation feedback message | `hooks/prism-bash-allowlist.sh` | — | Medium | true |
| WU3 | Implement test runner detection in prism.md — **2-runner check**: pytest config (pytest.ini / pyproject.toml [tool.pytest] / setup.cfg [tool:pytest]) → pytest; executable `test.sh` in repo root → bash test.sh; if both → consult `SAIL_PRISM_TEST_RUNNER` or skip `polyglot_ambiguous_no_override`. `command -v <runner>` precheck for binary-missing. Validate `SAIL_PRISM_TEST_RUNNER` against v1 set; non-supported → `unsupported_override` skip. | `commands/prism.md` | — | Low | true |
| WU4 | Wire Stage 5.5 in prism.md — runs after Stage 5 Quality, before Stage 6 Synthesis; conditional on (runner detected) AND (binary present) AND (`SAIL_PRISM_RUN_TESTS != 0`); **performs hook-wiring self-probe (AC23) — abort to `hook_not_wired` if `prism-bash-allowlist.sh` not in user's settings.json**; **performs stale-state detection (AC24) — reset `status: running` from prior session to `pending` before proceeding**; spawns `test-debt-classifier` subagent; receives summarized findings; persists raw output; default-construct test_debt field on absent state (consumer-side migration forward-compat) | `commands/prism.md` | WU3, WU12 | High | false |
| WU5 | Implement opt-out gate `SAIL_PRISM_RUN_TESTS=0` — checked at Stage 5.5 entry; sets stage status `skipped` with reason `opt_out_env_var` | `commands/prism.md` | WU4 | Low | true |
| WU6 | Update Synthesis stage in prism.md — consume test-debt findings as themable contributor; document expected behavior (real-issue findings become themes via single-source-critical bypass; categories 2-5 stay as standalone findings sorted by severity); skip-reason telemetry surfaces in synthesis output | `commands/prism.md` | WU4 | Medium | false |
| WU7 | Update prism wizard state schema — add `test_debt` step with: `status`, `runner_detected`, `failure_count`, `findings` (array of `{test_id, category, severity, reason}`), `output_log_path`, `skip_reason`. Forward-compat: absent field treated as `pending` | `commands/prism.md` (state schema section) | WU4 | Low | false |
| WU8 | Update `settings-example.json` — add `prism-bash-allowlist.sh` to PreToolUse Bash matcher hooks array (alongside existing `dangerous-commands.sh` and `secret-scanner.sh`) | `settings-example.json` | WU2 | Low | true |
| WU9 | Update `test.sh` — Categories 3 (file/hook counts), 4 (frontmatter on new agent), 5 (no `set -e` in new hook), 6 (settings JSON valid), 7 (install dry run), 8 (behavioral evals); cover AC1, AC15-AC22; including AC11 fixture-driven word-count check (uses WU13 fixture project) | `test.sh` | WU1, WU2, WU8, WU10, WU13 | Medium | true |
| WU10 | Add behavioral eval fixtures to `evals/evals.json` — 7 fixtures: (a) test-debt-classifier + allowlisted cmd → exit 0; (b) test-debt-classifier + non-allowlisted cmd → exit 2 with "outside declared scope"; (c) main session (no agent_type) + cmd → exit 0; (d) different agent_type + cmd → exit 0; (e) binary-missing detection produces `runner_binary_missing`; (f) exit-0-with-failure-markers produces `test-infrastructure-broken` (textual scan); (g) unsupported `SAIL_PRISM_TEST_RUNNER` value produces `unsupported_override` | `evals/evals.json` | WU2 | Low | true |
| WU11 | Refresh metadata — `install.sh` agent count `12 → 13` and hook count `18 → 19`; `README.md` agent/hook counts if surfaced; `agents/README.md` add row for test-debt-classifier; **also update `.claude/CLAUDE.md` (this repo's instructions)** for hook count drift `19 → 20` shell files | `install.sh`, `README.md`, `agents/README.md`, `.claude/CLAUDE.md` | WU1 | Low | false |
| WU12 | Pre-impl empirical gate — verify the NEW `prism-bash-allowlist.sh` hook fires for actual `test-debt-classifier` subagent dispatch (mirrors anti-pattern-catalog AC14 form-2). Distinct from AC14 (general claim). Run before WU4 wiring is committed | (verification artifact `wu12-verification.md`) | WU2, WU8 | Medium | false |
| WU13 | **Create test fixture for AC11** — `tests/fixtures/test-debt-100-failures/` with 100 synthetic failing tests + `generate.sh` generator script. Used to verify subagent return-message ≤ 2K-token bound (1500 word-count proxy). Fixture is checked into the repo. | `tests/fixtures/test-debt-100-failures/` | — | Low | true |
| WU14 | **User-facing threat-model documentation + install detection** — add "Security & Side Effects" subsection to `commands/prism.md` explaining: (a) Stage 5.5 runs the project's test suite in-place; (b) tests with side effects WILL execute those side effects; (c) `SAIL_PRISM_RUN_TESTS=0` opt-out for hostile/unaudited repos; (d) destructive actions inside test scripts are NOT blocked by hooks (known threat-model boundary); (e) `SAIL_DISABLED_HOOKS` recovery requires Claude Code session restart. **Update install.sh: detect existing user settings.json; if present and lacks `prism-bash-allowlist.sh`, print loud warning with the exact JSON snippet to add (PM2 fix complement to AC23 runtime probe).** Add per-stage warning naming the runner. | `commands/prism.md`, `install.sh` | WU4 | Low | false |

**WU count: 14** (rev3 trim: was 15 in rev2-polish; folded former WU13 per-runner-exit-code content into WU1; renumbered former WU14 → WU13, former WU15 → WU14)
**ACs: 24** (rev3-polish added AC23 hook-wiring self-probe + AC24 stale-state recovery from pre-mortem PM2/PM4 fixes)
**Critique tier: Full** (≥6 WUs + security-sensitive risk)
**Critical path:** WU2 → WU8 → WU12 → WU4 → WU14 (length 5)
**Max parallel width:** 4 (Batch 1: WU1, WU2, WU3, WU13 fixture)

---

Specification revision 3 complete. Ready for Stage 4.5 (Pre-Mortem) — Edge Cases re-critique would surface new findings post-trim, but the cluster of edge-case findings from rev2's Stage 4 either dissolves under rev3 simplifications (most polyglot/runner-multi issues) or remains documented as v2 work.
