# Critique Transcript: test-debt-in-prism — Stage 3 Challenge

Mode: critique (Full tier — 12 WUs, security-sensitive risk pattern triggers Full minimum)
Started: 2026-05-01

## Orient Phase

(Written inline by orchestrator — full context already established in session via prior-art investigation, empirical hook verification, vault note review. Independence concern delegated to Diverge phase.)

### Problem Statement (Intent)

The `/prism` command runs a 6-stage holistic code-health review (Plan / Correctness / Cohesion / Documentation / Quality / Synthesis) producing a themed remediation plan. Currently, no stage runs the project's test suite or classifies pre-existing test failures. Failures get triaged inline as `[preexisting, ignoring]` and accumulate indefinitely as silent debt, contradicting the user's standing rule (`feedback_preexisting_test_debt` — "stop dismissing; fix or flag").

This blueprint adds Stage 5.5: a `test-debt-reviewer` subagent that runs the suite via a detected runner, classifies each failure into one of five severity-ordered categories (real-issue / test-infrastructure-broken / drift / abandoned / quarantine candidate), and emits findings to Stage 6 Synthesis as another themable contributor. Single retry is in scope as the quarantine-candidate signal.

This is the first Bash-using prism agent. All 11 existing prism agents (6 lens + 5 domain reviewer) are read-only (Read/Glob/Grep). Containment is via a NEW PreToolUse hook (`prism-bash-allowlist.sh`) that branches on `agent_type` and enforces a per-agent command allowlist; runs alongside `dangerous-commands.sh` without modifying it.

"Done" means: a project with N failing tests gets N classified findings in synthesis output, each with severity + one-line reason, themable with other prism findings.

### Prior Art

- **Industry tooling** (per `prior-art.md`): Trunk, Atlassian Flakinator, BuildPulse, Snowflake, Datadog CI Visibility — all flaky-detection focused with retry/statistical analysis. None classify on a multi-axis taxonomy. The 5-category framing (real-issue / infrastructure / drift / abandoned / quarantine) is genuinely novel — confirmed market gap. Recommendation: **Build** with informed borrowing (retry-based detection from Trunk/Atlassian; severity-axis structure from govuk-rfcs/rfc-069).
- **Vocabulary**: "flaky" is universal; "drift", "abandoned", "real-issue", "test-infrastructure-broken" are our terms of art. Synthesis output and agent prompt must define them up front.
- **Empirical (load-bearing)**: PreToolUse hooks DO fire on subagent Bash calls. `agent_id` and `agent_type` ARE populated. Verified 2026-05-01 by instrumenting `dangerous-commands.sh` to dump stdin during a dispatched general-purpose subagent's Bash call. Issue #34692 (claiming hooks bypass for subagents) does not reproduce on our installation.
- **Predecessor**: anti-pattern-catalog (shipped 2026-04-30, commits 36bff79 + e53a7d2). Debrief lessons: pre-impl empirical gating works (AC14 form-2 pattern); spec-blind hard-threshold tests beat fuzzy contracts; settings.local.json hooks are session-cached (must be accounted for in install messaging).
- **Vault findings consulted**: `2026-03-22-prism-premortem-context-exhaustion` (high-severity operational risk for orchestrator context budget); `2026-04-22-project-scout-integration-test-debt-live-aws-coupling` (concrete prior test-debt example exhibiting drift and abandoned categories — useful to validate classification against); `2026-04-30-debrief-anti-pattern-catalog`.

### Constraints

- 5 classification categories, severity-ordered (load-bearing decision from prior session — do not re-derive)
- Stage 5.5 position between Quality (5) and Synthesis (6) (load-bearing)
- Per-agent Bash allowlist via separate hook, NOT modifying `dangerous-commands.sh`
- v1 scope: classify pre-existing failures only. NO coverage, NO staleness, NO mutation, NO multi-run statistics, NO continuous management, NO opt-in gating
- Default: opt-OUT (`SAIL_PRISM_RUN_TESTS=0` to disable). Run-on-detect is the v1 default behavior.
- All existing prism agents remain read-only. New Bash capability is isolated to `test-debt-reviewer`.
- `dangerous-commands.sh` must be byte-identical post-change.

### Scope Boundaries

- **In**: 5-category classification, single retry, runner detection (bun > pytest > cargo > go > npm > bash test.sh priority), opt-out gate, per-agent allowlist enforcement, raw output persistence to `.claude/wizards/prism-<id>/test-debt-output.log`, synthesis integration, progress-check (heartbeat-based) timeout policy.
- **Out**: coverage gap analysis, persistent test-history tracking, multi-run Bayesian flake statistics, mutation testing, continuous test-debt management, opt-in gating, automatic test repair, structural consumption of test markers (`@pytest.mark.flaky` etc) — though incidentally surfaced when reading test source.

### Unvalidated Assumptions

- **Classification quality**: agent prompt will produce useful labels, not "real-issue for everything." Acceptable v1 risk; iterate on prompt in v2.
- **Heartbeat threshold (90s default)**: right for most projects. Configurable via `SAIL_PRISM_TEST_TIMEOUT`.
- **Subagent isolation contains orchestrator token budget**: AC15 verifies. Load-bearing for the prism-context-exhaustion mitigation.
- **Single retry suffices for quarantine signal**: multi-run statistics is explicitly out of scope. If single retry produces too many false-positive quarantine tags, v2 might add "two retries → quarantine" as a tighter threshold.

### Known Risks

| Risk | Category | Mitigation in spec |
|------|----------|--------------------|
| Prism orchestrator context exhaustion (vault: 2026-03-22) | **operational** | Subagent isolation: classification done in subagent, orchestrator only sees one-line summarized findings |
| Settings.local.json hooks are session-cached | operational | Documented in install messaging; WU12 empirical gate runs in current session via direct hook invocation |
| First Bash-using prism agent sets precedent for future Bash-needing agents | domain | Hook designed with `enforce_for_agent()` function seam for future genericity |
| Hostile-repo default (opt-OUT, not opt-IN) | integration | `SAIL_PRISM_RUN_TESTS=0` env var; prominent docs warning. Accepted v1 risk per user. |
| Classification accuracy depends on prompt quality | technical | Acceptable v1 risk; v2 iteration |
| Allowlist too strict locks out legitimate runner subcommands | technical | Hook fail-opens via `set +e`; `SAIL_DISABLED_HOOKS=prism-bash-allowlist` toggle for emergencies |

---

## Diverge Phase

Three lenses dispatched in parallel, each with independence calibration preamble.

### Correctness Lens — 10 findings

- **C1 (CRITICAL, conf 0.9, false-known)** — Allowlist via prefix matching is bypassable via shell metacharacters (semicolons, double-amp, command-substitution dollar-paren, backticks, eval, redirection, etc.). Spec never specifies HOW commands match against allowlist. AC6-9 fixtures only test direct non-allowlisted command, not compound forms. Containment claim is structurally undermined.
- **C2 (HIGH, conf 0.85, false-known)** — Heartbeat-based liveness incompatible with default test runner output buffering. pytest buffers when piped, bun batches, cargo only streams with --nocapture, go test only emits per-package on completion. Healthy run on a large suite can sit silent past 90s threshold and be killed as "stuck." The agent must invoke runners with output-forcing flags; those flags aren't in WU2 allowlist or WU3 detection.
- **C3 (HIGH, conf 0.85, false-known)** — AC15 doesn't verify the token-budget claim. AC15 says "verify failure appears in synthesis output" — does not measure orchestrator context. 1K performance bound contradicts Q4's stated ~3K for 100 failures. Failure-mode mitigation says truncate above 1K; AC15 doesn't test truncation.
- **C4 (HIGH, conf 0.8, false-known)** — Runner priority order picks wrong runner in polyglot. Django app with bun frontend has bun.lock at root → bun test selected even though tests are pytest. package.json scripts.test is common in Python projects with frontend tooling. claude-sail's own repo has both test.sh AND any future package.json. SAIL_PRISM_TEST_RUNNER override pushes the cost to users who often don't realize detection picked wrong.
- **C5 (HIGH, conf 0.95, false-known)** — Pytest exit codes are factually wrong in spec. Per pytest docs: 0=all passed, **1=some failed**, 2=interrupted, 3=internal error, 4=usage error, 5=no tests collected. Spec says "rc=2 = test failures present; rc=3-5 = collection error" — that's wrong. rc=1 is failures, rc=2 is interruption, rc=5 is "no tests collected" not collection error. Classification logic relying on this systematically misclassifies normal failures.
- **C6 (medium, conf 0.7)** — Single-retry quarantine signal will produce high false positives. Many failures pass on single re-run for transient resource reasons (port released, cache expired, temp file cleaned, DB row rolled back) — none of which are "test is flaky." Industry uses statistical analysis precisely because single-retry is noisy.
- **C7 (medium, conf 0.75)** — Runner-exits-0-but-tests-failed silent failure case is not in failure modes table. Common in npm-test-pipe-true patterns, bash test.sh aggregation, custom wrappers that swallow exit codes. Detection silently passes broken project.
- **C8 (medium, conf 0.8, false-known)** — AC14 verification is one-shot, non-reproducible artifact. Performed by hand on specific date. Verification artifact (tmp file) is gone. Claude Code version drift could re-break. test.sh has no entry for "subagent hooks fire" check.
- **C9 (medium, conf 0.7)** — SAIL_DISABLED_HOOKS=prism-bash-allowlist removes containment without warning. Spec presents as normal recovery option. Couples poorly with hostile-repo opt-OUT default.
- **C10 (medium, conf 0.8, false-known partial)** — Subagent isolation token-budget conflates intermediate and final-message output. Subagent's intermediate Bash output doesn't flow to orchestrator (correct). But subagent's final message DOES return fully — 100 findings × 30 tokens = 3K tokens to orchestrator. Spec needs explicit prompt cap on agent output; missing from WU1.

### Completeness Lens — 10 findings

- **M1 (HIGH, conf 0.85, false-known)** — Migration path for existing prism installations unspecified. Spec assumes greenfield. Doesn't address: in-flight wizard state files lacking test_debt; install.sh upgrade-in-place handling; stale agent file cleanup; existing state-machine handling absent fields. Preservation Contract claims "additive — existing consumers ignore unknown fields" but says nothing about NEW consumers handling OLD state.
- **M2 (medium, conf 0.9)** — No telemetry distinguishing skip reasons. State schema has skip_reason but no enumeration. AC12/AC13 verify both produce em-dash, indistinguishable from runner-detected-but-binary-missing or CI-default-skip.
- **M3 (HIGH, conf 0.95)** — Runner-detected-but-binary-missing case unspecified. pytest.ini exists but pytest not on PATH (venv inactive, polyglot Cargo.toml without cargo, bun on nvm). Spec's failure-mode table doesn't cover. Behavior undefined.
- **M4 (HIGH, conf 0.9, false-known)** — Bash allowlist never enumerated explicitly in spec. WU1 says "declared allowlist enumeration"; WU2 says "test runners + git log path/to/test". Full list never written. Open: cd for monorepos? which pytest? python -m pytest? pytest --co -q? AC6/AC7 use single-token examples not exercising realistic surface.
- **M5 (medium, conf 0.85)** — Multi-classification handling unspecified. A failure can be drift AND quarantine candidate. Spec mandates "one of the above" with no tiebreak rule. Inter-run classification instability likely.
- **M6 (medium, conf 0.8)** — No per-project override for global SAIL_PRISM_RUN_TESTS=0. User opting out globally cannot enable for one safe project without mutating shell env. No .claude/sail.local.json mechanism.
- **M7 (medium, conf 0.85, false-known)** — Zero-failures behavior implicit. Failure-modes table claims "verified via integration test" but no AC enforces this and no integration test is enumerated.
- **M8 (medium, conf 0.7)** — CI-environment behavior unaddressed. /prism may run in CI: doubles build time, races parent CI's pytest, agent_type populated reliably outside interactive Claude unverified, different env defaults likely needed.
- **M9 (medium, conf 0.75)** — No user feedback loop after fixing classified failures. No persistent state means re-runs cannot distinguish "never had failures" from "had failures, fixed them." Motivational/discipline loop is broken.
- **M10 (HIGH, conf 0.9, false-known)** — Heartbeat mechanism mechanics unspecified. Q1 says subagent emits, orchestrator monitors, kills if stuck. HOW each step works is unspecified — "monitor" and "kill" are wishful words. WU4 implementer has no contract to implement against.

### Coherence Lens — 10 findings

- **H1 (CRITICAL, conf 0.95, false-known)** — Spec's "first Bash-using prism agent" premise is FALSE. Verified empirically: all 6 reviewer agents (architecture, cloudformation, security, performance, quality, spec) declare Bash in tools list. Preservation Contract claim "11 agents remain read-only" is false. **Refinement post-verification:** existing reviewers DECLARE Bash but don't reference Bash/grep/shell/command in prompt content — effectively read-only by prompt discipline. So functionally test-debt-reviewer is the "first ACTIVELY Bash-using" agent, but the spec's literal claim is wrong and must be reframed.
- **H2 (low, conf 0.85)** — Stage 5.5 numbering convention. Minor: note `test_debt` is state-machine name (consistent with cloudformation), "Stage 5.5" is display label (consistent with "Stage 2.5"). Cite cloudformation precedent in Decisions.
- **H3 (medium, conf 0.8, false-known)** — Promised `enforce_for_agent()` refactor seam doesn't match the case-statement design. A case-statement IS the dispatch — there's no single function. Real seam = function taking (agent_type, command) → exit, with case-statement INSIDE. Spec L132-152 conflates the two patterns.
- **H4 (HIGH, conf 0.85, false-known)** — Subagent-isolation-contains-token-budget claim has no supporting mechanism in current prism.md. prism.md describes Wave 1 lens compression on the way OUT to next stage, not subagent → orchestrator return. Token-budget mitigation is prompt-discipline, not structural. AC15 doesn't measure orchestrator context.
- **H5 (HIGH, conf 0.9, false-known)** — AC14 misrepresents what was verified. 2026-05-01 verification used `dangerous-commands.sh` — verified PreToolUse fires for subagents (general claim). WU12 verifies the NEW `prism-bash-allowlist.sh` fires for `test-debt-reviewer` dispatch (specific claim, unverified). Spec L82 conflates them with "Already verified 2026-05-01."
- **H6 (medium, conf 0.75)** — 5-category severity gradient flattens through prism's voting threshold. prism's voting requires 2+ independent observations to promote standalone → theme; single-source critical bypasses. Real-issue (critical) becomes themes; categories 2-5 stay as standalone findings sorted by severity. Spec doesn't address whether this is desired.
- **H7 (medium, conf 0.8, false-known)** — `.claude/wizards/prism-*/test-debt-output.log` is a convention departure. Per WIZARD-STATE.md, wizard dirs hold ONLY state.json. Spec proposes adding artifact files. Framed as "wizard already creates the dir" — true but misleading.
- **H8 (HIGH, conf 0.85)** — Test runner scripts execute arbitrary shell as child processes invisible to PreToolUse hooks. Hooks fire on Claude Code Bash tool calls, not on shell child processes invoked by allowed commands. `bash test.sh` (this very repo's runner) executes arbitrary shell. A buggy or malicious test.sh could perform destructive operations — dangerous-commands.sh does NOT see it because it's a child process of the allowed `bash test.sh`. Real threat in opt-out-default mode.
- **H9 (low, conf 0.7)** — Agent name `test-debt-reviewer` overloads `*-reviewer` convention. Existing reviewers are read-only code reviewers; test-debt-reviewer is an EXECUTOR. Better name: `test-debt-classifier`, `test-runner-agent`, `test-debt-investigator`.
- **H10 (low, conf 0.7)** — install.sh hook count update under-specified. WU11 says "agent count 12 → 13, hook count update" but doesn't enumerate which file. CLAUDE.md says "19 shell files: 18 hooks + 1 utility" — drifts to 20. test.sh likely greps CLAUDE.md or README for counts.

---

## Phase 2.5: Interaction Scan

Cross-perspective intersections producing compound failure modes.

### CF-1: "Containment is theater" — *critical*
**Sources:** C1 + H1 + H8
- C1: allowlist bypassable via shell metacharacters
- H1: preservation contract "11 agents read-only" claim is false (agents declare Bash)
- H8: test scripts run arbitrary shell as child processes invisible to hooks

**Compound:** Three independent failure modes converge on the security framing. Each finding alone might be addressable; together they suggest the per-agent allowlist hook provides much weaker containment than spec claims. Either accept "best-effort defense, not a containment boundary" framing, or design real containment (sandbox / capability filtering / read-only test environments).

### CF-2: "Token budget is hand-waved" — *high*
**Sources:** C3 + H4 + C10
- C3: AC15 doesn't verify token-budget; 1K bound vs 3K Q4 estimate is internal contradiction
- H4: subagent isolation is prompt-discipline, not Claude Code structural property
- C10: spec needs explicit prompt cap on agent output; missing from WU1

**Compound:** The mitigation for the prism-context-exhaustion vault risk (highest-priority operational risk this design must address) is unverified, partially incorrect about underlying mechanism, and missing prompt-level constraint required to make it work.

### CF-3: "Runner exit-code interpretation is broken" — *high*
**Sources:** C5 + C7 + M3
- C5: pytest exit codes documented wrong in spec
- C7: runner-exits-0-but-tests-failed silent failure not handled
- M3: runner-detected-but-binary-missing not handled

**Compound:** The agent's primary signal — "did tests pass or fail?" — is interpreted via exit code, but spec gets codes wrong, doesn't handle silent failures, and doesn't handle binary-missing. Multiple failure modes produce silent miscategorization with no visible signal.

### CF-4: "Liveness check is wishful" — *high*
**Sources:** C2 + M10
- C2: heartbeat threshold incompatible with default test-runner output buffering
- M10: heartbeat mechanism mechanics entirely unspecified

**Compound:** Both mechanism design AND default-behavior compatibility are missing. Implementing this is authoring-from-scratch with no contract, and even then would kill healthy runs as "stuck."

### CF-5: "Detection is wrong for real projects" — *high*
**Sources:** C4 + M3
- C4: runner priority picks wrong runner in polyglot
- M3: binary-missing case unhandled

**Compound:** Detection both picks wrong tool AND fails when right tool is missing. First user trying it on a real polyglot or non-dev-environment project gets nonsensical classification.

### Lower-priority intersections
- **M1 + H7**: state-schema migration + wizard-dir convention departure — both touch state-machine boundary
- **C2 + C5 + M3 + C7**: all four touch the runner-interaction layer (collection, exit codes, output, missing binary) — together suggest runner-integration sub-spec needs significant rewrite

---

## Stage 3 Verdict (orchestrator synthesis, replacing Converge agent dispatch given clarity of findings)

**Verdict: REWORK**

Spec needs targeted revision before Stage 4 (Edge Cases) and downstream stages. Five compound failures, one critical (CF-1) and four high (CF-2 through CF-5). Confidence in current spec dropped from 0.85 (post-Stage-2) to ~0.45.

**Regression target:** Stage 2 (Specify)

**Required spec changes (numbered for revision):**
1. Reframe "first Bash-using prism agent" → "first ACTIVELY Bash-using" + correct Preservation Contract (H1)
2. Specify allowlist enforcement mechanism — parse + reject metacharacters, OR explicit downgrade to "best-effort" labeling (C1, M4)
3. Add child-process invisibility risk to Failure Modes; document opt-OUT default's hostile-repo implication beyond DB/email (H8)
4. Fix AC15 to verify token budget; resolve 1K vs 3K contradiction; add explicit prompt cap to WU1 (C3, H4, C10)
5. Fix pytest exit codes; specify exit-code handling for ALL listed runners; add runner-exits-0-with-failures detection (C5, C7)
6. Specify heartbeat mechanism (or replace with file-mtime poll / process-still-running check) and force runner output flags such as -v / --nocapture (C2, M10)
7. Rethink runner priority — language-primary heuristic instead of speed-priority; handle binary-missing (C4, M3)
8. Enumerate full allowlist explicitly (M4)
9. Document migration path for existing prism installations (M1)
10. Add telemetry distinguishing skip reasons (M2)
11. Specify zero-failures and multi-classification behavior (M5, M7)
12. Clarify AC14 (general hook firing) vs WU12 (specific new hook); they are not redundant (H5)
13. Reconsider agent name (`test-debt-reviewer` → `test-debt-classifier` if user agrees) (H9)
14. Address theme-flattening — synthesis-stage handling for non-critical category findings (H6)

**Non-critical findings to defer or note:**
- C6 (single-retry false positives): accepted v1 risk, document as known limitation
- C8 (AC14 reproducibility): add to test.sh as session-start sanity check
- C9 (disable warning): add one-line warning when env var triggers disable
- M6, M8, M9 (per-project override, CI behavior, feedback loop): defer to v2; document as future work
- H2, H3, H7, H10: minor; bundle into spec rev

**Skipped phases:**
Phase 3 (Clash) and Phase 3.5 (Refine) skipped given clarity of compound findings. Picture would not change with cross-examination — rebuttals on individual findings won't dissolve the compound failures, and Refine has nothing to resolve (no contested 0.4-0.6 confidence findings; all critical/high findings are above 0.7).

---

## Stage 3 Re-Critique (rev2 quick re-Diverge)

User opted for path (b): quick re-Diverge only (no full pipeline) given rev2's surgical scope.

### Diverge Phase (rev2)

Three lenses dispatched in parallel against rev2 spec.md + spec.diff.md + rev1 adversarial.md.

**Note on disposition vocabulary (corrected post-session):** Original prompt used `DISPOSITION_VERIFIED` for rev1-finding-was-fixed. User correctly flagged this is inaccurate — agents performed text-conformity checks, not behavioral verification. Relabeled below using honest vocabulary:
- `text_conforms` — spec text matches the disposition claim
- `fact_checked` — claim matches an external authoritative source (e.g., pytest docs)
- `behaviorally_verified` — claim verified by executed test (0 such items pre-implementation)
- `partial` — text/fact mostly matches but with caveats
- `new_issue` — issue introduced by or surfaced via the rev2 changes

### Correctness Lens — 8 findings

- **C1 (low, 0.95, fact_checked)** — Pytest exit codes in rev2 are factually correct (matches authoritative pytest docs)
- **C2 (low, 0.90, fact_checked)** — Cargo (101=test failures) and go (1=failures, 2=build error) exit codes correct
- **C3 (medium, 0.75, partial)** — 1K-vs-3K contradiction resolved (single 2K bound) but AC15's word-count math is wrong: 2K tokens ≈ 1500 words (not 2667). Bound is ~2x too lenient as written. **FIXED in rev2-polish (AC15 reads "≤ 1500" now).**
- **C4 (medium, 0.80, new_issue)** — Failure-modes recovery references "top-25 fallback" while WU1/Q4 specify "top-50" — internal contradiction
- **C5 (high, 0.80, partial)** — Bash-tool timeout substituted for heartbeat (CF-4 mitigation), BUT spec doesn't specify the agent must pass `timeout` parameter on every Bash invocation. Without explicit spec, harness default applies (2 min) which is too short. **FIXED in rev2-polish (WU1 item (h) added).**
- **C6 (medium, 0.80, partial)** — Language-primary detection algorithm under-specified (which extensions, what threshold, generated-files handling)
- **C7 (high, 0.85, new_issue)** — False-pass detection regex misses common formats: JSON output, JUnit XML, emoji/unicode markers, large output windows that push summary past 50 lines. **FIXED in rev2-polish (multi-format scan over 200 lines).**
- **C8 (medium, 0.75, new_issue)** — AC25 verifies producer-side migration but consumer-side default-construction responsibility unassigned. **FIXED in rev2-polish (AC25 expanded; Decisions clarifies consumer-side default-construct in WU4/WU7).**

### Completeness Lens — 8 findings

- **M1 (medium, 0.75, partial)** — Migration silent on abandoned mid-run wizards and concurrent-active-wizard install (acknowledged as deferred to v2)
- **M2 (high, 0.85, partial)** — `skip_reason` values implied across spec but never enumerated as closed set. **FIXED in rev2-polish (skip_reason Enumeration section added).**
- **M3 (low, 0.65, text_conforms with seam)** — Binary-missing precheck location split between detection and runner-invocation; both implied; defense-in-depth seam noted
- **M4 (medium, 0.80, partial)** — Allowlist not enumerated; lives in WU1 prompt + WU2 hook with no parity AC (downgraded under threat-model reframe; minor drift risk remains)
- **M5 (low, 0.85, text_conforms)** — Multi-classification tiebreak rule covered in narrative + WU1 + AC23
- **M7 (low, 0.75, text_conforms)** — Zero-failures contract covered at agent level; synthesis-no-contribution path verifiable only via inspection (acceptable)
- **M10 (medium, 0.70, partial)** — Bash-tool timeout handles partial-output retrieval, but partial-output classification contract underspecified. **FIXED in rev2-polish (WU1 item (i) — do NOT classify on truncated output; emit only meta-finding).**
- **M-NEW1 (high, 0.85, new_issue)** — User-facing threat-model documentation has no work unit. Failure Modes claims docs "call this out prominently" but no WU creates them. **FIXED in rev2-polish (WU15 added).**
- **M-NEW2 (high, 0.90, new_issue)** — `SAIL_PRISM_TEST_RUNNER` override has undefined behavior for runners outside priority-6 (jest, vitest, mocha, rspec, phpunit, ctest). **FIXED in rev2-polish (Decisions row + AC26 + new failure-mode row + new skip_reason value `unsupported_override`).**
- **M-NEW3 (medium, 0.85, new_issue)** — AC15 fixture project required but creation not a WU. **FIXED in rev2-polish (WU14 added).**
- **M-NEW4 (medium, 0.70, new_issue)** — Forced runner flags vs project's existing config interaction not addressed (deferred — acceptable v1 risk)
- **M-NEW5 (medium, 0.75, new_issue)** — WU13 spec-vs-prompt content drift has no cross-reference verification (deferred — acceptable; WU13 content is now folded into WU1 authoring per work-graph clarification)

### Coherence Lens — 8 findings

- **H1 (low, 0.80, text_conforms)** — Preservation Contract corrected; "first ACTIVELY Bash-using" framing replaces literal claim. Asymmetric guardrail coverage noted as accepted v1.
- **H4 (n/a, 0.92, text_conforms)** — Token-budget claim coherent across Threat Model / Decisions / Performance Bounds / AC15 / WU1 / Q4
- **H5 (n/a, 0.95, text_conforms)** — AC14 vs WU12 distinction explicit
- **H8 (n/a, 0.93, text_conforms)** — Child-process invisibility consistently framed as known threat-model boundary
- **H9 (low, 0.85, partial)** — Rename applied to spec.md and work-graph.json; NOT applied to upstream describe.md and prior-art.md (acceptable as historical artifacts; spec.diff.md captures rename)
- **H6 (medium, 0.80, partial)** — "Synthesis Integration" section claim in spec.diff resolves to a clause inside WU6 description; minor docs-naming inconsistency
- **H3 (n/a, 0.95, text_conforms)** — Refactor seam language properly removed
- **H10 (high, 0.88, new_issue)** — AC15 fixture project undefined. **FIXED in rev2-polish (WU14 added).**
- **H11 (medium, 0.88, new_issue)** — work-graph.json had WU1 + WU13 both at depends_on=[] but WU13's content lives inside WU1's file. **FIXED in rev2-polish (WU1 depends_on=[WU13]).**
- **H12 (medium, 0.85, new_issue)** — state.json's challenge-stage status not flipped post-regression (rev1 "complete" record still present). **FIXED in rev2-polish (challenge stage updated to track rev1+rev2 separately).**
- **H13 (medium, 0.82, new_issue)** — `test-infrastructure-broken` category overloaded (8+ subtypes — interrupted, internal error, build error, etc.). Acceptable broadening; spec narrative could tighten.
- **H14 (medium, 0.83, new_issue)** — Consumer-side default-construction responsibility unassigned. **FIXED in rev2-polish (AC25 expanded + Decisions clarification).**

### Aggregate verdict (rev2 + polish)

- **CF-1 through CF-5** (rev1 compounds): all addressed
- **High-severity rev2 issues:** 6 — all addressed in rev2-polish (C5, C7, M2, M-NEW1, M-NEW2, H10)
- **Medium-severity rev2 issues:** 11 — selectively addressed in polish (C3, C8, M2 partial, M10, H10, H11, H12, H14, M-NEW3); deferred-with-rationale (M1, M4, M-NEW4, M-NEW5, H6, H13)
- **Low-severity:** 2 — accepted as-is

**Verdict: PASS WITH POLISH APPLIED** (no formal regression; rev2-polish changes inline). Proceeding to Stage 4 (Edge Cases).

