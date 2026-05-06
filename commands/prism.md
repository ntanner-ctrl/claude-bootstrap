---
description: Use for holistic code health assessment of an entire project or directory. Runs parallel paradigm lens swarm (6 agents) followed by serial domain reviews with accumulated context, producing a themed remediation plan. This is judgment-based assessment, not metric-based — complements static analysis tools.
arguments:
  - name: target
    description: Directory path or file list to scope the analysis (default - entire project)
    required: false
---

## Cognitive Traps

Before skipping or simplifying this command, check yourself:

| Rationalization | Why It's Wrong |
|----------------|---------------|
| "The project is too small for a full prism" | Small projects have the highest concentration of patterns — prism catches them early before they scale. |
| "I already know what's wrong" | You know what's VISIBLE. Prism's value is cross-cutting themes that emerge from 11 independent perspectives. |
| "This will take too long" | Prism runs agents in parallel. The time cost is less than the cost of missing a systemic pattern. |

# Prism — Holistic Code Health Assessment

Assesses code health through a parallel paradigm lens swarm (6 observation agents) followed by serial domain reviews (5 existing reviewers), where each domain reviewer reads accumulated findings from all prior stages. Produces a themed remediation plan with discrete and nebulous fix categories.

## When to Use

- Whole-project health assessment (not change-scoped — use `/quality-sweep` for recent diffs)
- Before a major refactoring effort — understand the landscape
- Periodic code health check (quarterly, post-milestone)
- When onboarding to an unfamiliar codebase

**Decision guide:** `/quality-sweep` reviews recent changes with parallel independent agents. `/prism` assesses the whole project with serial linked reviewers. Use sweep for "did I break anything?" and prism for "what's the overall health?"

## Process

### State Initialization

Before beginning any analysis, initialize wizard state:

```
1. Ensure .claude/wizards/ exists (mkdir -p)
2. Check for active session: ls .claude/wizards/prism-*/state.json
   - If multiple matches: select most recent by created_at, archive others
3. If active session found (status == "active"):
   - Validate version field — if mismatch, treat as corrupt and start fresh
   - Display session age and stage progression header (✓/→/○ per step status)
   - Prompt:
       Previous prism session from [age]. Resume or start fresh?
         [1] Resume from [current_step]
         [2] Abandon and start fresh
   - On Resume: reconstruct context from output_summaries + context object,
     then skip to current_step. Any substep with status "active" is re-run as "pending".
   - On Abandon: set status "abandoned", create new session.
4. If error session found (status == "error"):
   - Display:
       Previous session errored at [step name].
         [1] Resume from last complete step
         [2] Abandon and start fresh
5. If no active/error session:
   - Create .claude/wizards/prism-YYYYMMDD-HHMMSS/state.json
   - Initialize with wizard "prism", version 1, status "active",
     current_step "context", all steps pending
   - context object: { target_path, scope_files: null, paradigm_summary: null, cf_detected: false }
6. Run cleanup: for sessions older than 7 days with status complete/abandoned/error,
   move to .claude/wizards/_archive/. Log warning for old "active" sessions but do NOT archive.
7. Display initial stage progression header.
```

**Session ID format:** `prism-YYYYMMDD-HHMMSS` (second precision). Steps: `context`, `scope`, `wave1`, `architecture`, `cloudformation`, `security`, `performance`, `quality`, `synthesis`, `report`. See `docs/WIZARD-STATE.md` for schema details.

**Stage Progression Header format:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PRISM │ Stage: [current stage name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ Context Brief        ← complete
  → Scope Detection      ← active (current)
  ○ Wave 1: Paradigm Lenses
  ○ Architecture Review
  ○ CloudFormation Review
  ○ Security Review
  ○ Performance Review
  ○ Quality Review
  ○ Synthesis
  ○ Report & Export
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Skipped conditional steps use `—` (dash). For Wave 1, show `[N/6 agents complete]` on the active line.

---

### Stage 0: Project Context Brief

Build a ~500 token context brief for all downstream agents.

1. **Read CLAUDE.md** (if exists) — extract stack, conventions, architecture notes
2. **Sample conventions** — check for linter configs, formatter configs, test patterns
3. **Detect stack** — language(s), framework(s), build tool(s)
4. **Check vault for prior prism reports:**
   ```bash
   source ~/.claude/hooks/vault-config.sh 2>/dev/null
   ```
   If vault available, search `$VAULT_PATH/Engineering/Findings/` for files matching `*prism*` or `*-prism-*`. If found, list prior reports with dates and note recurring themes. This is advisory context, not a gate. If vault unavailable, skip silently.

5. **Token budget estimation:** Estimate the total context load across all stages. Display to user:
   ```
   Estimated context: ~[N] tokens across [M] agent dispatches
   ```
   This is a rough estimate for awareness, not a hard gate.

6. **Conflict marker check (non-blocking):** Scan discovered files for git merge conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`). If found:
   ```
   Warning: [N] files contain merge conflict markers.
   Prism results for these files may be unreliable.
   Consider resolving conflicts first.
   ```
   Continue analysis — do not abort.

**Output:** Project Context Brief (~500 tokens max). If it exceeds budget, truncate to key sections: stack, conventions, known constraints.

**State update:** Mark step `context` complete. Write `output_summary`: project name, stack, file counts (commands/agents/hooks). Update `context.target_path`. Set `current_step` to `scope`. Display updated stage progression header.

### Stage 1: Scope Detection

**Default (no target specified):** Scan the entire project.

File discovery:
1. If git repo: `git ls-files` (respects .gitignore)
2. If not git repo: Glob for common source patterns, excluding `node_modules/`, `vendor/`, `.git/`, `dist/`, `build/`, `__pycache__/`, `_OLD/`
3. Filter to source files only (by extension: `.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.go`, `.rs`, `.java`, `.rb`, `.sh`, `.md` for commands/agents, etc.)

**With target specified:** Scope to that directory or file list.

**Large scope warning (>100 files):**
```
Prism scope covers [N] files — this will take 15-30+ minutes
and consume significant context across multiple agents.

Consider scoping to a specific directory: /prism src/auth/
Proceed anyway? (Y/n)
```

**Small scope warning (<10 files):**
```
Prism scope covers only [N] files. The full 11-agent pipeline
may be disproportionate. Consider /quality-sweep for small scopes.
Proceed anyway? (Y/n)
```

**State update:** Mark step `scope` complete. Write `output_summary`: file count in scope, filters applied, scope warnings if any. Update `context.scope_files`. Set `current_step` to `wave1`. Display updated stage progression header.

### Wave 1: Paradigm Lens Swarm (Parallel)

Dispatch all 6 paradigm lens agents in parallel. Each receives the Project Context Brief and the file list.

**Progress narration:**
```
━━━ Wave 1: Paradigm Lens Swarm ━━━━━━━━━━━━━━━━━━━━━
  Dispatching 6 observation agents in parallel...
    ► dry-lens        — scanning for duplicated logic
    ► yagni-lens      — scanning for unnecessary code
    ► kiss-lens       — scanning for overcomplicated solutions
    ► consistency-lens — scanning for convention variations
    ► cohesion-lens   — scanning for mixed responsibilities
    ► coupling-lens   — scanning for hidden dependencies
```

**Dispatch prompt for each lens:**
```
PROJECT CONTEXT:
[Project Context Brief]

FILES TO ANALYZE:
[File list with absolute paths]
```

**Timeout:** 3 minutes per agent.

**Timeout handling:** If a lens agent times out, log the timeout, skip that lens, and note in the paradigm summary: "[lens-name] timed out — excluded from analysis."

**Malformed output handling:**

Distinguish between two conditions:
- **Zero observations (clean empty):** Agent acknowledges finding nothing (e.g., "No DRY violations found"). This is a successful result — record "0 observations" and continue. Do NOT retry.
- **Malformed output:** Agent produces text with findings but not in the expected `[X1] [file:line] — [description]` format. Single retry with clarifying prompt: "Your output did not follow the required format. Please re-analyze and produce numbered observations in this format: [X1] [file:line] — [description] / Confidence: [high/medium/low]"
- If retry also fails: log warning, discard that lens's output, note in paradigm summary: "[lens-name] output was unparseable — excluded from analysis."

**After all lenses complete:**

Compress all lens observations into a **Paradigm Summary** (~300-500 tokens). This summary is what domain reviewers receive — not the raw lens output. If the summary exceeds ~500 tokens, keep only high/medium confidence observations.

**Progress update:**
```
  Wave 1 complete: [N] observations across [M] lenses
    dry-lens:         [N] observations
    yagni-lens:       [N] observations
    kiss-lens:        [N] observations
    consistency-lens: [N] observations
    cohesion-lens:    [N] observations
    coupling-lens:    [N] observations
```

**State update:** Mark step `wave1` complete. Write `output_summary`: issue count per paradigm (DRY: N, YAGNI: N, KISS: N, consistency: N, cohesion: N, coupling: N), top 3 critical findings with affected files, pattern-level diagnosis. Update `context.paradigm_summary` with the compressed Paradigm Summary. Set `current_step` to `architecture`. Display updated stage progression header. **Vault checkpoint:** export paradigm summary if vault available (fail-open). Record in `vault_checkpoints` if successful.

### Serial Domain Reviews (Stages 2-5)

Each domain reviewer is dispatched as a subagent with augmented context. The reviewer agents themselves are unchanged — the orchestrator provides additional context via the dispatch prompt.

**Stage ordering is deliberate and load-bearing:**

1. **Architecture first** — sets structural constraints everything else must respect
2. **CloudFormation conditional** — only if CF/SAM/CDK templates detected (`.yaml`/`.json` in common infra directories)
3. **Security third** — security constraints are non-negotiable
4. **Performance fourth** — now knows what architecture allows and what security requires
5. **Quality last** — has the fullest picture

#### Dispatch Prompt Template

```
You are reviewing this project for [domain] concerns.

PROJECT CONTEXT:
[Project Context Brief — ~500 tokens]

PARADIGM OBSERVATIONS (from 6 lens agents):
[Paradigm Summary — ~300-500 tokens]

CONSTRAINTS (from prior domain reviews — these RESTRICT your recommendations):
[Cumulative constraint block — ~200-1200 tokens depending on stage]

DO NOT recommend anything that conflicts with the CONSTRAINTS above.
If you believe a constraint is wrong or should be revisited, flag
the conflict explicitly: "[challenges constraint: X because Y]"
rather than silently ignoring it.

[If any prior stage was skipped due to timeout:]
NOTE: [domain] review was skipped (timeout). Do NOT assume no
[domain] constraints exist — err on the side of flagging potential
[domain] conflicts rather than ignoring them.

CONTEXT (background from prior domain reviews — informational only):
[Key findings from prior stages, compressed to ~300 tokens max]

FILES TO REVIEW:
[File list with absolute paths]

Review these files. Report findings as a numbered list with severity
(critical/high/medium/low) and specific file:line references where
applicable. Tag any finding that depends on an assumption about the
project with [assumption: description].
```

The separation between CONSTRAINTS (behavioral — modifies what you recommend) and CONTEXT (informational — background that informs) is load-bearing. Constraints are exclusions; context is awareness.

#### Constraint Summary Extraction

After each serial domain stage completes, the **orchestrator** (not the domain reviewer) extracts a constraint summary from that stage's raw findings. This is a ~200-300 token block:

```
DOMAIN: [architecture/cloudformation/security/performance]
CONSTRAINTS (restrict downstream recommendations):
  - [Named constraint]: [brief description]
  - [Named constraint]: [brief description]
CLEARED (explicitly not a concern for this project):
  - [Area]: [why it's not a concern]
```

**Cumulative constraint block:** By each serial stage, downstream reviewers receive ONE flat cumulative constraint block (all prior stages merged), not separate blocks per prior stage.

**Aggregate cap:** The cumulative block should not exceed ~1200 tokens. If it exceeds this budget, trim by: (1) dropping CLEARED items first, (2) then compressing constraint descriptions to their essential restriction.

**Timeout:** 5 minutes per domain reviewer.

**Partial failure:** If a domain reviewer times out, log the timeout, skip that stage, and continue. Add a skipped-stage note to subsequent dispatch prompts. The synthesis stage notes which reviewers were skipped.

#### Stage 2: Architecture Review

```
━━━ Stage 2: Architecture Review ━━━━━━━━━━━━━━━━━━━
  Dispatching architecture-reviewer...
```

Uses: `architecture-reviewer` agent. Reads: Project Context Brief + Paradigm Summary. Orchestrator extracts constraint summary after completion.

**State update:** Mark step `architecture` complete. Write `output_summary`: finding count, top concerns with severity, cross-cutting themes. Set `current_step` to `cloudformation`. Display updated stage progression header.

#### Stage 2.5: CloudFormation Review (Conditional)

Only runs if CF/SAM/CDK templates are detected in the project. Check for:
- `*.yaml` or `*.json` in directories named `cloudformation/`, `cfn/`, `infrastructure/`, `infra/`, `cdk.out/`
- Files containing `AWSTemplateFormatVersion` or `AWS::` resource types
- `template.yaml`, `template.json`, `samconfig.toml`

```
━━━ Stage 2.5: CloudFormation Review ━━━━━━━━━━━━━━━
  CF/SAM/CDK templates detected. Dispatching cloudformation-reviewer...
```

If no templates detected:
```
  Stage 2.5: CloudFormation — skipped (no templates detected)
```

Uses: `cloudformation-reviewer` agent. Reads: context + paradigm + architecture constraints. Orchestrator extracts constraint summary.

**State update:** Mark step `cloudformation` complete (or `skipped` with `skip_reason: "no CF templates detected"` and `conditional: true`). Write `output_summary`: finding count + top concerns, or "skipped: no CF detected". Set `current_step` to `security`. Display updated stage progression header. (Skipped cloudformation shows as `—` in the progress display.)

#### Stage 3: Security Review

```
━━━ Stage 3: Security Review ━━━━━━━━━━━━━━━━━━━━━━━
  Dispatching security-reviewer...
```

Uses: `security-reviewer` agent. Reads: context + paradigm + cumulative constraints. Orchestrator extracts constraint summary.

**State update:** Mark step `security` complete. Write `output_summary`: finding count, top concerns with severity. Set `current_step` to `performance`. Display updated stage progression header.

#### Stage 4: Performance Review

```
━━━ Stage 4: Performance Review ━━━━━━━━━━━━━━━━━━━━
  Dispatching performance-reviewer...
```

Uses: `performance-reviewer` agent. Reads: context + paradigm + cumulative constraints. Orchestrator extracts constraint summary.

**State update:** Mark step `performance` complete. Write `output_summary`: finding count, top concerns with severity. Set `current_step` to `quality`. Display updated stage progression header.

#### Stage 5: Quality Review

```
━━━ Stage 5: Quality Review ━━━━━━━━━━━━━━━━━━━━━━━━
  Dispatching quality-reviewer...
```

Uses: `quality-reviewer` agent. Reads: context + paradigm + cumulative constraints (fullest picture). No constraint extraction — last serial stage.

**Error path coverage note:** Error handling completeness is covered by domain reviewers, not a dedicated paradigm lens. quality-reviewer is primary (catches error handling inconsistency, unhandled exceptions, missing null checks). security-reviewer is secondary (catches security-relevant error suppression). cohesion-lens is tertiary (flags error-routing logic mixed into business logic).

**State update:** Mark step `quality` complete. Write `output_summary`: finding count, top concerns with severity. Set `current_step` to `synthesis`. Display updated stage progression header.

### Stage 5.5: Test Debt Classification

> **Conditional stage.** Runs after Stage 5 (Quality), before Stage 6 (Synthesis), only when ALL of the following are true: a supported test runner is detected, the runner binary is on PATH, the user has NOT opted out via `SAIL_PRISM_RUN_TESTS=0`, and the scope-guardrail hook is wired in the active settings.
>
> Spawns the `test-debt-classifier` subagent (see `agents/test-debt-classifier.md`) to run the project's test suite, classify pre-existing failures into 5 categories (real-issue, test-infrastructure-broken, drift, abandoned, quarantine-candidate), and feed them into Stage 6 Synthesis as another themable contributor.

#### 5.5.0: Runner Detection

The orchestrator detects which test runner this project uses. v1 supports two runners — `pytest` and `bash test.sh`. Other runners (`bun`, `cargo`, `go`, `npm`, `jest`, etc.) are deferred to v2.

**Detection markers:**

| Marker | Runner |
|--------|--------|
| `pytest.ini` exists | `pytest` |
| `pyproject.toml` contains `[tool.pytest]` table | `pytest` |
| `setup.cfg` contains `[tool:pytest]` section | `pytest` |
| `test.sh` exists in repo root AND is executable | `bash test.sh` |

**Resolution logic:**

1. **Neither marker found** → skip stage with `skip_reason: no_runner_detected`. Synthesis message: "Stage skipped: no recognized test runner detected."
2. **Exactly one marker found** → use that runner.
3. **Both pytest config AND `test.sh` present** (polyglot project):
   - If `SAIL_PRISM_TEST_RUNNER` is set to `pytest` or `bash test.sh` → use that.
   - Otherwise → skip with `skip_reason: polyglot_ambiguous_no_override`. Synthesis message: "Stage skipped: both pytest config and test.sh detected. Set SAIL_PRISM_TEST_RUNNER=pytest or SAIL_PRISM_TEST_RUNNER='bash test.sh' to choose."

**Override validation.** If `SAIL_PRISM_TEST_RUNNER` is set, validate against the v1-supported set:

| Value | Behavior |
|-------|----------|
| `pytest` | Accept (use pytest if detected, error if not present) |
| `bash test.sh` | Accept (use bash test.sh if `test.sh` present, error if not) |
| Anything else (`bun`, `cargo`, `go`, `npm`, `jest`, etc.) | Skip with `skip_reason: unsupported_override`. Synthesis message: "Stage skipped: SAIL_PRISM_TEST_RUNNER=`<value>` not in v1's supported set (pytest, bash test.sh). Other runners deferred to v2." |

**Binary-missing precheck.** Before invoking the chosen runner, run `command -v <runner>`:

- For `pytest`: `command -v pytest` must succeed
- For `bash test.sh`: `command -v bash` (always present); existence of `test.sh` was already verified by the marker check

If `command -v` fails for the chosen runner → skip with `skip_reason: runner_binary_missing` and emit synthesis finding `test-infrastructure-broken: <runner> not on PATH (project declares <runner> but binary unavailable)`.

The precheck is a fail-fast for the common case, not a guarantee. Runners requiring venv activation or `direnv` may resolve to a system binary that errors at runtime — in that case the runner's first invocation produces a setup-error exit code (e.g., pytest rc=4) that flows into the runner's normal exit-code handling.

#### 5.5.1: Opt-out Gate (`SAIL_PRISM_RUN_TESTS`)

Before any detection or probe runs, check the opt-out env var:

```bash
if [ "${SAIL_PRISM_RUN_TESTS:-1}" = "0" ]; then
    # Skip stage with skip_reason: opt_out_env_var
fi
```

If `SAIL_PRISM_RUN_TESTS=0` is set, skip the stage with `skip_reason: opt_out_env_var`. Synthesis message: "Stage skipped: test runs disabled via SAIL_PRISM_RUN_TESTS=0."

This is the user's universal escape hatch for hostile/side-effect-heavy repos where running the test suite is not safe. It's an env var (not a flag) because env vars are inherited from the parent process and survive across stages — flag-based opt-out would have to be passed through every command invocation.

**Per-project override is deferred to v2.** v1 honors only the env var (binary global). Users wanting per-project enable: shell function or `direnv` setup at the project level (`SAIL_PRISM_RUN_TESTS=1 claude` in project-specific shell config).

#### 5.5.2: Hook-Wiring Self-Probe (AC23)

Before dispatching the subagent, the orchestrator inspects `~/.claude/settings.json` to confirm that `prism-bash-allowlist.sh` is wired in the `PreToolUse` Bash matcher. This catches the **PM2** failure mode: install.sh deploys the hook file but does NOT auto-merge it into the user's existing settings.json — so without the probe, the agent could dispatch and run Bash without its scope guardrail in place.

**Probe logic:**

```bash
settings_path="$HOME/.claude/settings.json"
if [ ! -f "$settings_path" ]; then
    settings_path="$HOME/.claude/settings.local.json"
fi

if [ ! -f "$settings_path" ]; then
    # No settings.json found — skip with hook_not_wired
fi

if ! jq -e '.hooks.PreToolUse[]?.hooks[]? | select(.command | test("prism-bash-allowlist\\.sh"))' \
       "$settings_path" >/dev/null 2>&1; then
    # Hook file deployed but not wired — skip with hook_not_wired
fi
```

If the probe fails, skip with `skip_reason: hook_not_wired`. Synthesis message:

> "Stage skipped: prism-bash-allowlist hook is not wired in your settings.json. Either run `bash install.sh` and restart Claude Code, or add this entry to PreToolUse Bash hooks: `~/.claude/hooks/prism-bash-allowlist.sh`."

Self-disabling beats silent containment failure. The agent never executes Bash without its scope guardrail.

> **Settings reload caveat (known):** users with active sessions when they install the hook will not pick up the wiring until the next session restart. The probe correctly identifies the failure during the still-cached session and tells them what to do.

#### 5.5.3: Stale-State Detection (AC24)

Before initializing the new run, check whether a previous run was interrupted:

```bash
prior_status=$(jq -r '.steps.test_debt.status // "pending"' "$wizard_state_file")
prior_session=$(jq -r '.steps.test_debt.session_id // empty' "$wizard_state_file")

if [ "$prior_status" = "running" ] && [ -n "$prior_session" ] && [ "$prior_session" != "$current_session_id" ]; then
    # Interrupted prior run from a different session — reset to pending
    # but PRESERVE the prior output log (it is append-only and non-destructive)
fi
```

This catches the **PM4** failure mode: user `Ctrl-C`'s mid-Stage-5.5; wizard state stays `status: running`; next `/prism` run could read stale findings or refuse to proceed. The reset path:

1. Write `test_debt: { status: "pending", findings: [], skip_reason: null, session_id: null, output_log_path: null }`
2. Note `interrupted_prior_run: true` in the wizard state for telemetry
3. Continue normal flow

The prior run's `test-debt-output.log` is **preserved** (log files are append-only) so the user can inspect what happened.

#### 5.5.4: Subagent Dispatch

Once all gates pass (opt-out, hook-wiring, stale-state, runner detected, binary present), the orchestrator dispatches the `test-debt-classifier` subagent:

```
━━━ Stage 5.5: Test Debt Classification ━━━━━━━━━━━━━
  Detected runner: <pytest | bash test.sh>
  Dispatching test-debt-classifier subagent...
```

**Dispatch prompt template:**

```
You are the test-debt-classifier subagent for /prism Stage 5.5.

PROJECT CONTEXT:
[Project Context Brief — ~500 tokens from Stage 0]

RUNNER: <pytest | bash test.sh>

INVOCATION:
- For pytest: `pytest -v --tb=line --no-header` with timeout=300000ms
- For bash test.sh: `bash test.sh` with timeout=300000ms
  (override timeout via SAIL_PRISM_TEST_TIMEOUT env var, max 600000ms)

YOUR TASK: Run the test suite, observe failures, classify each into one of
five categories (real-issue, test-infrastructure-broken, drift, abandoned,
quarantine-candidate), emit the JSON schema specified in your agent file.

OUTPUT BOUND: Final return-message ≤ 2000 tokens (≈ 1500 words).

CONSTRAINTS: A scope-guardrail hook (prism-bash-allowlist.sh) enforces your
declared Bash allowlist. Do not improvise outside it.
```

**Timeout for the subagent dispatch itself:** 7 minutes (5-minute test runner + 2-minute classification headroom). On dispatch timeout, emit synthesis finding `test-infrastructure-broken: subagent dispatch timeout` and proceed to Stage 6.

**Empty-findings handling:** If the subagent returns `findings: []` with `status: complete` (zero failures), do NOT contribute any finding to Synthesis. Stage 5.5 contributes ONLY when failures exist.

#### 5.5.5: Output Persistence (AC14)

The orchestrator persists the subagent's full Bash output (not just the classified return-message) to:

```
.claude/wizards/prism-<session_id>/test-debt-output.log
```

The log is **append-only** within a single run. If the runner produces >500 KB, the log captures the full output (no truncation at log level); the in-memory copy passed to Synthesis is truncated to last 500 KB with a `--- truncated ---` marker. Users who need the full output read the log.

> **Convention departure:** wizard dirs traditionally hold only `state.json` (per `docs/WIZARD-STATE.md`). This blueprint adds artifact files to wizard dirs as a deliberate extension. The departure is documented in WIZARD-STATE.md.

#### 5.5.6: Wizard State Schema

The prism wizard state file gains a new `test_debt` step. **Additive — existing wizards lacking the field treat it as `pending`** (forward-compat default).

```json
{
  "steps": {
    ...,
    "quality": { "status": "complete", ... },
    "test_debt": {
      "status": "pending | running | complete | skipped",
      "runner_detected": "pytest | bash test.sh | null",
      "failure_count": 0,
      "findings": [
        {
          "test_id": "tests/test_foo.py::test_bar",
          "category": "real-issue | test-infrastructure-broken | drift | abandoned | quarantine-candidate",
          "severity": "critical | high | medium | low",
          "reason": "≤25 word classification rationale"
        }
      ],
      "output_log_path": ".claude/wizards/prism-<id>/test-debt-output.log | null",
      "skip_reason": "<closed enum value> | null",
      "session_id": "<current session id> | null",
      "interrupted_prior_run": false
    },
    "synthesis": { "status": "pending", ... }
  }
}
```

**Closed `skip_reason` enum** — every code path that sets stage status to `skipped` MUST use one of these exact values. Synthesis renders skip-reason-specific messages per the table in the spec (AC18):

| Value | Set when |
|-------|----------|
| `no_runner_detected` | Detection found no recognized runner |
| `opt_out_env_var` | `SAIL_PRISM_RUN_TESTS=0` is set |
| `runner_binary_missing` | Detection found runner config but `command -v <runner>` failed |
| `polyglot_ambiguous_no_override` | Both pytest config AND `test.sh` present; `SAIL_PRISM_TEST_RUNNER` not set |
| `unsupported_override` | `SAIL_PRISM_TEST_RUNNER` set to a value outside v1's supported set |
| `hook_not_wired` | Stage 5.5 entry self-probe detected `prism-bash-allowlist.sh` not wired in active settings.json |

Implementations consuming the wizard state MUST default-construct an absent `test_debt` field to `{status: "pending", findings: [], skip_reason: null, ...}` — this is the migration path for prism wizards that pre-date this stage.

#### 5.5.7: Security & Side Effects

> **Read this section before running /prism on a repo you do not own or trust.**

Stage 5.5 runs the project's test suite **in-place**. The implications:

- **Tests with side effects WILL execute those side effects.** If the test suite writes to a real database, sends emails, deploys infrastructure, or makes API calls, those effects happen. Test suite isolation is the project's responsibility, not /prism's.
- **`SAIL_PRISM_RUN_TESTS=0`** is the universal opt-out for hostile or unaudited repos. Set it in your shell's startup file or via `direnv` for repos you do not trust.
- **The scope-guardrail hook (`prism-bash-allowlist.sh`) is NOT a sandbox.** It catches agent confusion (the test-debt-classifier reaching outside its declared scope of `pytest`/`bash test.sh`/`git log`). It does not defend against:
  - Hostile test code that runs destructive commands as child processes (PreToolUse hooks fire on Claude Code Bash tool calls, not on processes spawned by allowed commands)
  - Shell metacharacter bypass within otherwise-allowed commands (not modeled)
- **`dangerous-commands.sh` continues to enforce the universal destructive-pattern blocking layer** for ALL Bash calls (including the test-debt-classifier's). That's the safety floor.
- **`SAIL_DISABLED_HOOKS=prism-bash-allowlist`** disables the scope guardrail. Useful for debugging if the allowlist drifts; not useful as a security control. Mid-session env var changes do not propagate to the running Claude Code's hook process — recovery requires session restart.

**State update:** Mark step `test_debt` complete (or `skipped`). Write `output_summary`: runner detected, failure count, finding count by category, skip_reason if skipped. Set `current_step` to `synthesis`. Display updated stage progression header.

### Stage 6: Synthesis

Performed by the orchestrator (this command), not a separate agent. Two explicit sub-steps: mechanical grouping (algorithmic) followed by judgment-based classification (LLM-native).

```
━━━ Stage 6: Synthesis ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Synthesizing findings from [N] agents...
```

#### Test Debt Findings as Synthesis Input

Stage 5.5's `test_debt.findings` are consumed by Synthesis as another themable contributor (alongside paradigm summary and domain reviews). Category-to-severity mapping:

| Test debt category | Severity for synthesis | Synthesis treatment |
|--------------------|------------------------|---------------------|
| `real-issue` | critical | Eligible for **single-source-critical bypass** (theme-equivalent priority even from a single agent source) |
| `test-infrastructure-broken` | high | Standalone finding sorted by severity. Cross-source promotion to theme requires another agent surfacing the same issue. |
| `drift` | medium | Standalone finding |
| `abandoned` | medium | Standalone finding |
| `quarantine-candidate` | low | Standalone finding |

If Stage 5.5 was **skipped** (status=`skipped`, skip_reason set), Synthesis emits NO test-debt findings but DOES surface the skip-reason message in the Stage 7 report (see Domain coverage). If Stage 5.5 ran and returned **zero failures** (`findings: []`), Synthesis emits no test-debt contribution at all (no "all tests pass" finding).

The agent's `test_id` field locates each finding (e.g., `tests/test_foo.py::test_bar`) — Synthesis treats this like a `[file:line]` reference for the co-location merge rule (Sub-Step A step 2).

#### Sub-Step A: Mechanical Grouping

1. **Collect** all findings from paradigm summary + domain reviews + test-debt findings (Stage 5.5 if it ran)
2. **Co-location rule** — Two merge triggers:
   - **Line proximity:** If two or more observations reference the same file:line (or overlapping line ranges within 5 lines), merge into a single grouped observation. List all contributing agents in the Sources field.
   - **Named entity (soft):** If two or more observations reference the same named entity (function name, class name, module name) in the same file but at different lines, flag as "co-located candidates" — grouped for theme consideration but not auto-merged. Review for relatedness in Sub-Step B.
3. **Multi-lens density signal** — Files with observations from 3+ independent lenses are automatically flagged as HIGH priority candidates, regardless of individual observation confidence scores.
4. **Voting threshold** — A named theme requires at least 2 independent observations (from different agents) to be promoted from "standalone finding" to "theme." Single-agent observations remain as standalone findings. **Critical severity bypass:** Single-source findings rated `critical` severity by a domain reviewer are automatically promoted to theme-equivalent priority, placed above medium-priority themes. This bypass applies to `critical` only — `high` severity findings still require cross-source validation.
5. **Conflict detection** — If a domain reviewer's finding contradicts a constraint from a prior stage, tag it: `[challenges constraint: X because Y]`. Surface prominently in the report, do not resolve automatically.

#### Sub-Step B: Judgment-Based Classification

6. **Theme detection** — Group merged observations and multi-observation clusters by affected area/concern, not by source agent. Examples: "Error Handling Inconsistency" (from consistency-lens + quality-reviewer), "Unused Abstraction Layer" (from yagni-lens + architecture-reviewer).
7. **Categorize** each theme:
   - **Discrete** — specific file:line fixes with clear remediation ("change X to Y")
   - **Nebulous** — pattern-level issues requiring human judgment ("adopt consistent error handling pattern across 6 files")
8. **Score** each theme:
   - **Ease** (1-5): How hard is this to fix?
   - **Impact** (1-5): How much does fixing this improve the project?
   - **Risk** (1-5): How bad is it if we DON'T fix this?
   - These scores are heuristic estimates for relative ranking within a single run, not precise measurements.
9. **Prioritize** by composite: Risk x Impact / Ease (higher = fix first). Themes flagged by multi-lens density (step 3) receive +1 to Risk score (capped at 5). **Tie-breaking:** Equal composite scores break by: (1) Risk score descending, then (2) number of contributing sources descending.
10. **Confidence filter** — Paradigm observations tagged `low` confidence are included but marked `[low confidence — verify before acting]`

**State update:** Mark step `synthesis` complete. Write `output_summary`: theme count, remediation priorities (top 3 themes with composite scores), confidence score. Set `current_step` to `report`. Display updated stage progression header.

### Stage 7: Report & Export

Present the remediation plan inline (always displayed regardless of vault availability).

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PRISM ANALYSIS: [project name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Project Context: [1-2 sentence summary]
  Scope: [N files across M directories]
  Lenses applied: 6 paradigm + [N] domain

  [If prior prism reports found in vault:]
  Prior runs: [N] reports found (most recent: [date])
  Recurring themes: [list if any]

  [If any domain reviewers timed out:]
  Note: [reviewer] timed out — findings incomplete for that domain.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

─── THEME 1: [Theme Name] ─────────────────────────────────
Priority: [HIGH/MEDIUM/LOW] (Ease: [1-5] Impact: [1-5] Risk: [1-5])
Category: [Discrete/Nebulous]
Sources: [list of lens and reviewer agents that contributed]

  [Description of the theme — what the pattern is, why it matters]

  [If Discrete:]
    Fix: [specific action]
    Affected:
      [file:line] — [what to change]
      [file:line] — [what to change]

  [If Nebulous:]
    Suggested pattern: [description of the target state]
    Affected files:
      [file:line(s)] — [what's wrong here]
      [file:line(s)] — [what's wrong here]

  [If any observation tagged low confidence:]
    [low confidence — verify before acting]

─── THEME 2: [Theme Name] ─────────────────────────────────
...

─── Standalone Findings ────────────────────────────────
  (Single-source observations below voting threshold.
   Critical findings appear above in themes section.)

  [S1] [severity] [file:line] — [description]
       Source: [agent name]

  [S2] [severity] [file:line] — [description]
       Source: [agent name]
  ...

  Sorted by severity (critical > high > medium > low).
  No Ease/Impact/Risk scoring — insufficient cross-source
  evidence to score reliably.

─── Constraint Extraction Audit ───────────────────────
  (Constraints extracted by orchestrator from domain findings.
   These shaped downstream reviewer behavior.)

  From architecture-reviewer:
    CONSTRAINT: [name] — [description]
    CLEARED: [area] — [reason]

  From security-reviewer:
    CONSTRAINT: [name] — [description]

  [If any constraint was challenged by a downstream reviewer:]
    [challenges constraint: X because Y] — from [reviewer]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Themes identified: [N]
    Discrete: [N] (specific fixes)
    Nebulous: [N] (pattern-level, requires human judgment)

  Priority breakdown:
    HIGH:   [N] themes
    MEDIUM: [N] themes
    LOW:    [N] themes

  Domain coverage:
    Architecture: [N findings / skipped]
    CloudFormation: [N findings / skipped / not applicable]
    Security: [N findings / skipped]
    Performance: [N findings / skipped]
    Quality: [N findings / skipped]
    Test Debt: [N findings (R real-issue, I infra, D drift, A abandoned, Q quarantine) / skipped: <skip_reason_message>]

  [If vault available:]
    Report saved to: Engineering/Findings/YYYY-MM-DD-HHMM-prism-[project].md

  Note: Prism consumes significant session context. Consider
  starting a fresh session for implementation work.

  Next steps:
    • Address HIGH priority themes first
    • Use /blueprint for nebulous themes requiring design work
    • Use /delegate for parallel discrete fixes
    • Re-run /prism after remediation to track improvement

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Vault Export

After presenting the report, export to vault if available:

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null
```

If vault available:
1. Ensure directory: `mkdir -p "$VAULT_PATH/Engineering/Findings"`
2. Generate slug: `YYYY-MM-DD-HHMM-prism-[project-name].md` (HHMM timestamp prevents same-day collision)
3. Hydrate `prism-report.md` vault template with findings
4. Write to vault
5. Report: `Vault: Prism report exported to Engineering/Findings/`

If vault unavailable, skip silently. Report is always displayed inline regardless.

**State update (completion):** Mark step `report` complete. Write `output_summary`: export status, vault path if exported. Set `status` to `"complete"`, `current_step` to `null`. Display final stage progression header with all steps marked `✓`. **Vault checkpoint:** export final report if vault available (fail-open). Record in `vault_checkpoints` if successful.

### Resume Protocol

When invoked with an active session, context is reconstructed from disk before any analysis runs:

1. Read `output_summary` from each completed step — these are the compressed findings budget. See `docs/WIZARD-STATE.md` for per-step content contracts and token budgets (~800-1,450 tokens total for a full prism resume).
2. Read `context` object for `target_path`, `scope_files`, `paradigm_summary`, `cf_detected`.
3. For `wave1` with substeps: any substep with `status: active` is treated as `pending` and re-run (retrying read-only analysis agents is always safe).
4. **Freshness:** Sessions older than 24 hours MUST display a prominent staleness warning in the resume prompt — the codebase may have changed significantly.
5. Resume picks up from `current_step` with full prior-stage context reconstructed from summaries.

> Schema details and full content contracts: `docs/WIZARD-STATE.md`

## Failure Modes

| What Could Fail | Detection | Recovery |
|-----------------|-----------|----------|
| Lens agent timeout (>3 min) | Agent returns no result | Skip lens, note in paradigm summary, continue |
| Domain reviewer timeout (>5 min) | Agent returns no result | Skip domain stage, note in report, add gap note to subsequent dispatches, continue |
| All agents timeout | No findings collected | Report "Prism could not complete — all agents timed out" and exit |
| Vault unavailable during export | vault-config.sh returns VAULT_ENABLED=0 | Skip export silently, display report inline only |
| No source files found | File discovery returns empty list | Report "No source files found in scope" and exit |
| Paradigm summary exceeds budget | Summary >500 tokens | Compress: keep only high/medium confidence observations |
| Lens produces malformed output | Output doesn't match expected format | Single retry, then skip with note |
| Domain reviewer ignores constraints | Findings contradict prior constraints | Tag as "[challenges constraint: X because Y]", surface prominently |
| Cumulative constraint block too large | Block >1200 tokens | Drop CLEARED items first, then compress descriptions |

## Known Limitations

- **All-markdown projects** (like claude-sail itself) produce predictable false positives from dry-lens (YAML frontmatter flagged as duplication) and cohesion-lens
- **Untracked files** are invisible to `git ls-files` — prism assesses tracked files only
- **Mid-rebase/merge state** with conflict markers produces unreliable findings (warning is provided)
- **Cross-run score comparison** is unreliable — Ease/Impact/Risk scores are heuristic estimates for relative ranking within a single run
- **Constraint extraction is LLM judgment** — misextraction is possible and would propagate downstream. Mitigated by the constraint extraction audit in the output report
- **Prism is judgment-based, not metric-based** — complements static analysis tools (SonarQube, ESLint) but does not replace them
