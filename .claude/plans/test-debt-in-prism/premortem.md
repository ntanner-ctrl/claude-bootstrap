# Pre-Mortem: test-debt-in-prism (Stage 4.5)

Premise: This plan was implemented and deployed two weeks ago. It failed.

Focus: OPERATIONAL failures only — deployment, monitoring, rollback, observability. Design failures already covered in Stages 3 + 4.

Verdict: **2 NEW findings (PM2 critical, PM8 high)** trigger automatic regression suggestion per blueprint workflow. Plus 1 challenge to a load-bearing user decision (PM1 opt-out default). Disposition decisions pending user direction.

---

## Most likely single cause of failure (agent narrative)

A user installs claude-sail mid-session via `bash install.sh`, restarts Claude Code, and over the next 2 weeks runs `/prism` on 4-5 different projects. On 3 of those, Stage 5.5 silently misbehaves: on a Django repo, the test suite runs migrations against the user's local Postgres dev database during the 5-min run, partially corrupting fixtures the user spent an hour seeding earlier. On a different repo, the test runner script does a `git clean -fdx` deep inside its setup. On a third (a cargo project), `/prism` returns immediately with `no_runner_detected` and the user concludes Stage 5.5 just doesn't do anything useful. None of these produce loud failures — synthesis renders the skip reason or the findings dryly, the user's eye glances over them, and the cost shows up later as data loss / lost trust / silent under-coverage.

The single proximate trigger that bites first is the **side-effect-during-tests scenario** — highest-severity / lowest-visibility combo, install message warning was 2 weeks ago and forgotten.

## Findings

### PM1 — Opt-out default for side-effect tests is operationally wrong (covered, but inadequate)

- **Type:** user-surprise
- **Status:** COVERED via `SAIL_PRISM_RUN_TESTS=0` env var + Q5 (per-project override deferred to v2). **Operationally inadequate** — relies on user remembering global env var per project.
- **Severity:** critical
- **Confidence:** 0.85
- **Agent recommendation:** Flip default to opt-IN, OR ship per-project `.claude/sail.local.json` override in v1.
- **Disposition note:** This challenges a load-bearing user decision (user explicitly chose opt-OUT earlier this session, accepting the risk). The agent's challenge is valid; the user's call stands unless they want to revisit.

### PM2 — install.sh does NOT merge new hook into existing settings.json (NEW, critical)

- **Type:** deployment
- **Status:** NEW, **VERIFIED FACTUALLY**. install.sh lines 393-394 + 454-455 print "Add/merge this hooks block into your settings.json" and "merge the hooks block with your existing config" — install copies hook files but tells the user to manually update settings.json. Upgrading users who already have a settings.json without the new hook entry get the agent + hook files installed but NO PreToolUse wiring → Stage 5.5 dispatches the agent and the allowlist hook never fires. **Scope guardrail collapses silently for existing-settings.json users.**
- **Severity:** critical (REGRESSION FLAG)
- **Confidence:** 0.95 (verified empirically via grep on install.sh)
- **Agent recommendation:** Detect-and-warn at install time; or add a `sail-doctor` check that compares hook files vs settings.json wiring; or auto-merge via jq.
- **Recommended fix shape (Stage 5.5 self-detection):** Have prism.md probe at Stage 5.5 entry whether the allowlist hook is loaded for this session. If not, abort with `skip_reason: hook_not_active` and tell the user to add the hook entry to settings.json (provide the JSON snippet). Self-disabling beats silent containment failure.

### PM3 — Mid-session install creates window where agent dispatches without hook (covered but framed wrong)

- **Type:** deployment
- **Status:** COVERED via "Settings reload caveat" in Migration section + Senior Review note, but framed as user error rather than deployment hazard.
- **Severity:** high
- **Confidence:** 0.90
- **Agent recommendation:** Have prism.md self-detect hook activation at Stage 5.5 entry (overlaps with PM2 fix).

### PM4 — User Ctrl-C's mid-Stage-5.5; wizard state stays `status: running`; next /prism behavior undefined (covered partial)

- **Type:** state
- **Status:** COVERED-PARTIAL — adversarial.md M1 deferred "abandoned-mid-run wizards" to v2 as "minor edge case," but operationally common.
- **Severity:** high
- **Confidence:** 0.75
- **Agent recommendation:** Add stale-detection rule: if `test_debt.status == "running"` from a prior session with no matching active session, treat as `interrupted_prior_run`, reset to `pending`. ~5-line addition; should not be deferred.

### PM5 — No aggregate observability across runs (NEW)

- **Type:** observability
- **Status:** NEW
- **Severity:** high
- **Confidence:** 0.80
- **Agent recommendation:** Append 1-line summary to `~/.claude/sail-prism-stage55.log` per run + `/sail-doctor` summary view. Surfaces silent-misbehavior patterns the user wouldn't catch from individual synthesis output.
- **Disposition note:** Scope expansion; the `/overcomplicated` review just trimmed surface. Likely accept as v1 limitation; revisit in v2 if user reports.

### PM6 — `test-debt-output.log` accumulates across months with no rotation (covered)

- **Type:** state
- **Status:** COVERED — adversarial.md noted v2 enhancement.
- **Severity:** medium
- **Confidence:** 0.85
- **Agent recommendation:** In-spec retention policy (e.g., keep newest 10 wizard dirs).

### PM7 — `SAIL_DISABLED_HOOKS` mid-session recovery may not work without restart (covered, partial)

- **Type:** rollback
- **Status:** COVERED but RECOVERY MAY NOT WORK MID-SESSION. Hook source reads env var on every invocation (verified in dangerous-commands.sh), so the env var IS re-read per call. BUT Claude Code's hook process inherits its environment from the parent Claude Code process — if the user changes their shell env, Claude Code's running session doesn't see it. Mid-session recovery requires session restart in practice.
- **Severity:** high
- **Confidence:** 0.70 (depends on Claude Code's harness env propagation; would need verification)
- **Agent recommendation:** Document that mid-session recovery requires session restart; consider an alternate emergency knob (e.g., touch a sentinel file the hook checks).

### PM8 — Classifier produces systematically wrong output; no calibration ground truth (NEW, regression flag)

- **Type:** observability
- **Status:** NEW (regression flag)
- **Severity:** high
- **Confidence:** 0.75
- **Agent recommendation:** Ship a "classifier sanity check" mode: dispatch agent against hand-labeled fixture (5 known-real-issue + 5 known-drift + 5 known-quarantine), compare classifications, fail loudly if accuracy <70%. Catches prompt-drift / model-version-shift before bad output reaches synthesis.
- **Disposition note:** Significant scope expansion. v2 candidate.

## Contributing factors

- Opt-out (not opt-in) default: stage runs by default whenever a runner is detected; burden on user to remember to disable
- No per-project override (Q5 deferred to v2) — global env var is the only knob, decoupled in time from action
- Install-time messaging is one-shot banner; users discover features by running commands
- Settings-cache reload requires session restart, but users have long-lived sessions
- install.sh updates `settings-example.json`, NOT user's actual `settings.json` (PM2)
- One more "stage skipped: …" line is easy to skim past in synthesis output
- No telemetry / aggregate signal across runs
- `test-debt-output.log` accumulates per-run with no rotation

## Early warning signs missed during planning

- Failure mode "test runner has side effects" recovery is "user opts out" — no design pressure asked "how does the user remember to opt out?"
- "Settings reload caveat" framed as user error rather than deployment-shape problem
- No AC verifies install.sh wires `prism-bash-allowlist.sh` into a USER's existing settings.json
- "Concurrent prism runs… inherits existing prism single-instance assumption" is asserted, not verified

## Top 3 retro recommendations

1. **Decide on opt-out vs opt-in** for side-effect-tests defaults (PM1 — challenges user decision; user's call)
2. **Ship deployment-integrity check** at Stage 5.5 entry — probe whether allowlist hook is loaded; abort cleanly if not (PM2 + PM3)
3. **Add stale-wizard-state detection** — 5-line addition to handle Ctrl-C recovery (PM4)

PM5 and PM8 (aggregate observability + classifier sanity check) are scope expansions; recommend deferring to v2 unless explicitly desired.

---

## Regression decision (workflow-prescribed)

Per blueprint workflow: pre-mortem identifying NEW critical failure mode → automatic regression suggestion. PM2 + PM8 qualify.

Options per workflow:
- **[1] Regress to specify** — fold fixes into rev4
- **[2] Note and continue** — append findings to adversarial.md, proceed to Stage 5
- **[3] Flag as blocking** — halt workflow until manually resolved

Disposition pending user direction.
