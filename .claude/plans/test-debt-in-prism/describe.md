# Describe: test-debt-in-prism

## Change Summary

Add a conditional Stage 5.5 to `/prism`: a `test-debt-reviewer` agent that runs the project's test suite using a detected runner (`bun test`, `pytest`, `cargo test`, `bash test.sh`, `go test ./...`, `npm test`), classifies each pre-existing failure into one of four categories, and feeds findings into prism's Stage 6 Synthesis as another themable contributor. Stage skipped with `—` in progress display when no runner detected. Gated by `SAIL_PRISM_RUN_TESTS=0` env-var opt-out for hostile-repo scenarios.

This is the first Bash-using prism agent. Containment is via per-agent Bash allowlist enforced by a NEW PreToolUse hook (separate from `dangerous-commands.sh`) that branches on `agent_type`. Hook feasibility was empirically confirmed during pre-blueprint setup.

## Classification (4 categories, severity ordering)

1. **real-issue** (highest) — code is broken, test correctly catches it
2. **drift** — test references API/symbol that has moved or changed
3. **abandoned** — test was for a feature/endpoint never finished
4. **quarantine candidate** — flaky/timing-dependent; should be marked as such or removed

Per failing test the agent: reads test + symbol(s) under test, classifies, surfaces to Synthesis with severity and a one-line "why this is failing." Single retry (run once, if pass-on-rerun → quarantine candidate signal) is in scope.

## Goal Clarity

The desired outcome is unambiguous: when a project has pre-existing failing tests, `/prism` Stage 5.5 will run the suite, label each failure with one of the four categories, and Synthesis will theme those labels alongside other prism findings (Error Handling, Documentation, etc.). "Done" means: a project with `N` failing tests gets `N` classified findings in the synthesis output, each with severity + one-line explanation, and the user can act on them as a debt-class instead of dismissing them inline.

## Constraints

### In scope (v1)
- Classification of pre-existing test failures into the 4 categories
- Single retry as quarantine-candidate signal
- Test runner detection for bun, pytest, cargo, bash test.sh, go, npm
- `SAIL_PRISM_RUN_TESTS=0` opt-out gate
- Per-agent Bash allowlist via new PreToolUse hook (branches on `agent_type`)
- Optional: persist raw test output to `.claude/wizards/prism-*/test-debt-output.log`

### Explicit non-goals (v1)
- Coverage gap analysis (different problem — what's missing vs what's broken)
- Test staleness (last-run, last-failed timestamps) — needs persistent state we don't have
- Mutation testing — different scale of investment
- Multi-run Bayesian flake statistics — Trunk/Atlassian Flakinator scope, over-engineered for single-shot prism
- Continuous test-debt management — prism is periodic, not continuous
- /quality-sweep getting the same stage — quality-sweep is change-scoped, test-debt is whole-project (wrong scope match)

### Unchangeable
- Existing prism stages 1-6 architecture (we're inserting between 5 and 6, not modifying them)
- Read-only nature of all existing prism agents (lenses + domain reviewers)
- The four classification categories themselves (load-bearing decision from prior session — do not re-derive)
- The per-agent allowlist enforcement pattern (load-bearing)

## Success Criteria (testable)

1. **Detection works:** Given a project with `pytest` available, Stage 5.5 detects pytest as the runner. Given a project with no recognized runner, Stage 5.5 displays `—` and skips.
2. **Opt-out works:** With `SAIL_PRISM_RUN_TESTS=0`, Stage 5.5 always shows `—` and never invokes the agent, even if a runner is detected.
3. **Classification produces output:** Given a project with K failing tests, the agent emits K findings, each with one of {real-issue, drift, abandoned, quarantine candidate} and a one-line reason.
4. **Synthesis consumes findings:** Stage 5.5 findings appear in Stage 6 Synthesis output alongside findings from other stages, themable.
5. **Allowlist hook enforces:** When `test-debt-reviewer` attempts a Bash command outside its declared allowlist (e.g., `curl`), the new hook blocks with feedback. When it runs `pytest` (allowlisted), the hook allows.
6. **Hook does not interfere with other agents:** A lens agent (e.g., `dry-lens`) running in prism is unaffected by the new hook.
7. **No regression in existing prism behavior:** All existing prism stage outputs match pre-change golden behavior when Stage 5.5 is skipped.

## Risk Flags

- ✅ **User-facing behavior change** — `/prism` adds a new stage; output format gains a new findings source
- ✅ **Security-sensitive** — first Bash-using prism agent; new allowlist hook sets the precedent for future Bash-needing prism agents

(Other dimensions: no DB/migration, no auth/authz user-facing, no deletion, no external API, no production target, no finance)

## Steps (decomposition — 9 discrete actions)

| # | Step | Touches |
|---|------|---------|
| 1 | Create `agents/test-debt-reviewer.md` (4-category classifier mandate, declared Bash allowlist, prompt template) | `agents/` |
| 2 | Create new PreToolUse hook (`hooks/prism-bash-allowlist.sh`) that branches on `agent_type == "test-debt-reviewer"` and enforces allowlist | `hooks/` (NEW file, NOT modifying dangerous-commands.sh) |
| 3 | Implement test runner detection (helper logic in prism.md or shared utility) | `commands/prism.md` |
| 4 | Wire Stage 5.5 in prism.md (conditional execution, "—" skip when no runner; runs after Stage 5 Quality, before Stage 6 Synthesis) | `commands/prism.md` |
| 5 | Implement `SAIL_PRISM_RUN_TESTS=0` opt-out gate | `commands/prism.md` |
| 6 | Update Synthesis stage to consume test-debt findings as themable contributor | `commands/prism.md` |
| 7 | Update prism wizard state schema to include `test_debt` step | `commands/prism.md` (state structure) |
| 8 | Add test.sh coverage: agent presence, hook allowlist behavior, runner detection, opt-out gate, Stage 5.5 wiring | `test.sh` |
| 9 | Refresh metadata: `install.sh` agent count (12→13), `README.md` table, `agents/README.md` entry, `settings-example.json` hook wiring | `install.sh`, `README.md`, `agents/README.md`, `settings-example.json` |

## Hook Architecture Decision (working assumption — finalized in spec)

**New separate hook, not modifying `dangerous-commands.sh`.**

Overlap analysis: zero meaningful overlap. The two hooks enforce orthogonal concerns (universal destructive patterns vs agent-specific capability boundary) on different traffic shapes. Both run on the PreToolUse Bash matcher; both can independently exit 2; harness aggregates rejection reasons. Existing precedent: `secret-scanner.sh` + `dangerous-commands.sh` already coexist on the same matcher with the same pattern.

Reasons separate wins:
- Single responsibility (different concerns, different evolution rates)
- Smaller blast radius (bug in allowlist hook only affects prism)
- Discoverability (`prism-bash-allowlist.sh` is self-explanatory)
- Future genericity (the pattern was explicitly called "to reuse for any future Bash-needing prism agent" — clean home for that to evolve)
- Testability (separate test scope)

Open spec-stage question: should the v1 hook hard-code the test-debt-reviewer's allowlist, or read allowlists from agent-frontmatter (more general, more complex)? Default: hard-code in v1, refactor toward general if/when a second Bash-using agent appears.

## Path Recommendation

**Full path.** Two paths in the triage table both land here:
- 8+ steps + any flag → Full
- 4-7 steps + risk flag → Full

Either way, this gets the full pipeline: critique mode (default) for Challenge + Edge Cases, Pre-Mortem (especially relevant given the `2026-03-22-prism-premortem-context-exhaustion` vault finding — the orchestrator is already at risk and we're adding load), Test, Execute, Debrief.

## Execution Preference

**Auto.** The work graph has clear parallelism: steps 1, 9 are mostly independent; 2 is independent of others except for testing-time interactions; 3-7 cluster on prism.md with some internal sequencing; 8 depends on all of above. Letting the work-graph analysis at Stage 2 drive parallelization keeps options open without prejudging.

## Inherited Context (from pre-stage work)

- **Pre-session brief:** `~/.claude/projects/-home-nick-claude-sail/memory/project_test_debt_design.md` — load-bearing decisions on classification taxonomy and per-agent allowlist pattern.
- **Prior-art report:** `prior-art.md` (this dir) — Build recommendation; no industry tool fits; vocabulary findings; empirical hook feasibility verdict.
- **Hook feasibility:** Empirically confirmed 2026-05-01 — subagent Bash calls fire PreToolUse hooks with `agent_id`/`agent_type` populated. Issue #34692 does not reproduce on our installation.
- **Vault context:** prism-premortem-context-exhaustion (high-severity, this design must account for it); project-scout-integration-test-debt-live-aws-coupling (concrete prior test-debt example we can validate classification against); anti-pattern-catalog debrief (predecessor; lessons on pre-impl empirical gating + spec-blind hard-threshold tests).
- **User rule:** `feedback_preexisting_test_debt` — "stop dismissing test failures; fix or flag for cleanup." Standing instruction motivating this whole blueprint.

## Open Implementation Questions (for spec stage)

- Test runner timeout policy: how does the agent handle runners that take >5 min? Soft progress check vs hard timeout? (Memory `feedback_timeouts_vs_liveness` says prefer progress checks.)
- Raw test output persistence: write to `.claude/wizards/prism-*/test-debt-output.log` for user inspection? (Probably yes — failures lose detail in synthesis.)
- Allowlist enforcement granularity: hard-coded for v1 vs agent-frontmatter-driven for genericity?
- Token budget: prism orchestrator context exhaustion is a known issue; Stage 5.5 will add ~1-2K tokens (raw output + classification). How does this interact with the existing budget design?
