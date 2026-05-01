# Change Specification: Blueprint TDD Enforcement + Family Mode Default

## Summary

Remove TDD as a standalone Stage 7 implementation option, enforce TDD at the work-unit level via a `tdd` annotation in the work graph, and change the default challenge mode from `debate` to `family`.

## What Changes

### Files/Components Touched

| File | Nature of Change |
|------|------------------|
| `commands/blueprint.md` | Modify — Stage 7 options (remove TDD option, add new third option), default challenge mode, TDD-at-WU references |
| `commands/spec-change.md` | Modify — Work graph generation must include `tdd` annotation per WU |
| `commands/delegate.md` | Modify — Implementer prompt must respect `tdd: true` WU annotation |
| `commands/tdd.md` | Modify — Add WU-level invocation mode (invoked by delegate/sequential, not standalone from Stage 7) |
| `docs/BLUEPRINT-MODES.md` | Modify — Change default from debate to family, update comparison table, update FAQ |
| `docs/PLANNING-STORAGE.md` | Modify — work-graph.json schema gets `tdd` field per WU |
| `.claude/CLAUDE.md` | Modify — Update references to implementation options and default mode |
| `README.md` | Modify — Update default mode example, any Stage 7 references |
| `commands/README.md` | Modify — Update command descriptions if affected |

### External Dependencies
- [x] None

### Database/State Changes
- [x] State format changes: `work-graph.json` gets a new `tdd: boolean` field per work unit node

## Preservation Contract (What Must NOT Change)

- **Behavior that must survive:**
  - The `/tdd` command still works standalone for ad-hoc TDD sessions outside blueprint
  - Vanilla, debate, and team modes still work when explicitly selected
  - Existing in-progress blueprints with `challenge_mode: "debate"` continue working unchanged
  - The work graph's topological sort, batching, and file conflict detection are unaffected
  - All four challenge modes remain available via `--challenge=` flag
  - Pre-v2 migration defaults to `vanilla` (unchanged — this is backward compat)

- **Interfaces that must remain stable:**
  - `state.json` schema is additive only (new fields, no removed fields)
  - `/delegate --plan` dispatch interface unchanged — TDD annotation is additive to implementer prompt
  - `/tdd --plan-context [name]` still works for manual TDD-from-plan usage

- **Performance bounds that must hold:**
  - Family mode's per-agent liveness check (3min) unchanged
  - Per-round and total timeouts removed — replaced by progress checks + S-1 round limits (see DD-6)
  - Work graph generation adds negligible overhead (one boolean per WU)

## Design Decisions

### DD-1: TDD Annotation as WU Property

During Stage 2 (Specify), each work unit gets a `tdd: true/false` annotation based on module characteristics. The heuristic (from the experiment findings):

| Module Characteristic | TDD Value | Examples |
|----------------------|-----------|----------|
| Clear I/O boundary | `true` | Parser, API client, transformer |
| Error contract / protocol | `true` | Protocol handlers, validators |
| API backward compatibility | `true` | Functions with existing callers |
| Gate / decision logic | `true` | Activation logic, state machines |
| Config / Docker / shell | `false` | docker-compose.yml, Dockerfile |
| Cloud infra / ETL | `false` | Terraform, PySpark, migrations |
| Simple wiring / glue | `false` | Dict assembly, config fields |
| Documentation only | `false` | README, comments, docs |

The spec author (Claude or user) assigns `tdd` during WU definition. This is a recommendation, not a hard gate — the user can override conversationally during execution (e.g., "skip TDD for WU-3" or "add TDD to WU-7"). The override happens in conversation, NOT by mutating work-graph.json — the annotation is a starting recommendation, not a constraint.

### DD-2: Stage 7 Implementation Options (After TDD Removal)

**Current:**
```
[1] Standard implementation (sequential)
[2] TDD-enforced → /tdd --plan-context [name]
[3] Parallel dispatch → /delegate --plan .../spec.md --review
```

**Proposed:**
```
[1] Sequential — work units executed one at a time, TDD applied per-WU annotation
[2] Parallel dispatch → /delegate --plan .../spec.md --review
    TDD applied per-WU annotation within each agent
```

**Note on third option:** The original spec proposed a "Guided Walkthrough" (interactive implementation with human review at each WU). Family debate analysis identified two vault-documented risks: (1) orchestrator context exhaustion from accumulated state across interactive rounds, and (2) permission inheritance blocking interactive approval flows. The Guided Walkthrough is **deferred to a follow-on blueprint** that can design the interactive protocol properly. Stage 7 ships with 2 options for now.

**Rationale for removing old option [2] (global TDD):** TDD as a global choice applies blanket coverage to modules where it adds no value (Docker config, infra, glue code). Per-WU annotation provides precision without losing coverage.

### DD-3: How TDD Enforcement Works Per-WU

When a WU has `tdd: true`, the implementation path (whether sequential, parallel, or guided) wraps that WU's execution in the TDD cycle:

1. **RED**: Write tests for the WU's acceptance criteria (from spec). Tests must fail.
2. **GREEN**: Write minimal implementation to pass tests.
3. **REFACTOR**: Clean up while keeping tests green.

For **sequential** (option 1): The main agent runs RED-GREEN-REFACTOR inline for each `tdd: true` WU.

For **parallel** (option 2): Each dispatched agent's implementer prompt includes TDD instructions when its WU has `tdd: true`. The agent runs the full cycle autonomously.

**Delegate integration mechanism (WU-4):** During delegate.md Step 3 (Dispatch Tasks), when constructing the implementer prompt for each task:
1. Check if `work-graph.json` exists at `.claude/plans/[name]/work-graph.json`
2. If it exists, look up the corresponding WU node by matching the task's description/files to a WU entry
3. If the WU has `tdd: true` (strict boolean equality — string "true" does NOT match), append TDD instructions after the existing PLAN CONTEXT block. For multi-file WUs, match by any file in the WU's `files` list; first match wins; no match = tdd: false:
   ```
   TDD ENFORCEMENT (this work unit):
     This work unit requires test-driven development.
     1. RED: Write tests for the acceptance criteria. Tests MUST fail.
     2. GREEN: Write minimal implementation to pass tests.
     3. REFACTOR: Clean up while keeping tests green.
     Do NOT write implementation before tests exist and fail.
   ```
4. If `tdd: false` or work-graph.json not found: standard implementation (no TDD instructions)

This follows the existing pattern in delegate.md's `--plan-context` mechanism (lines 393-403) which already reads adversarial.md and tests.md from the plan directory.

For `tdd: false` WUs: Standard implementation without test-first discipline. Tests can still be written afterward (and are encouraged), but the RED-GREEN-REFACTOR sequence is not enforced.

### DD-4: Default Challenge Mode Change

Change the default from `debate` to `family` across all references:
- `blueprint.md`: `--challenge=` default
- `BLUEPRINT-MODES.md`: comparison table, FAQ
- `README.md`: example command
- `CLAUDE.md`: architecture overview

**Backward compatibility:** Existing blueprints with `"challenge_mode": "debate"` in state.json are unaffected — the mode is locked at creation time. Only NEW blueprints get the new default.

**Resume behavior:** On resume, the challenge mode is ALWAYS read from `state.json` `challenge_mode` field, NOT from the command's YAML frontmatter default. This ensures that a debate-mode blueprint created before the default change continues using debate mode after the toolkit is updated.

### DD-5: Family Mode Assessment Findings

Based on vault evidence and architectural analysis:

**Strengths (preserve these):**
1. Mother's synthesis catches compound failures that linear debate misses
2. Elder Council's vault integration provides historical grounding
3. Multi-round convergence produces deeper analysis than 3-round debate
4. Dialectical (thesis/antithesis/synthesis) > adversarial (winner/loser) for spec review

**Weaknesses (address these):**
1. **Token cost is 3-5x debate mode** — families use ~10-30 agent calls vs debate's ~6
2. **Elder Council vault dependency** — without vault, Elders lose their main differentiator
3. **No early-exit for simple specs** — even obvious specs run the full family pipeline
4. **Child-Defend can be sycophantic** — "genuinely believes the spec is sound" prompt can produce weak defense that Mother can't synthesize against

**Proposed scaffolding improvements:**

**S-1: Complexity-adaptive rounds.** Add a complexity signal derived from the work graph (WU count + WU complexity distribution). The signal determines max family rounds:

| Signal | Condition | Max Rounds |
|--------|-----------|------------|
| Simple | ≤3 WUs AND no High-complexity WUs | 1 |
| Medium | 4-5 WUs OR 1+ High-complexity WU | 2 |
| Complex | ≥6 WUs | 3 |

This preserves depth where it matters while reducing token waste on simple changes. The signal is computed from work-graph.json at the start of Stage 3/4, not from a separate schema. Users can override with `--rounds=N` if needed.

**S-2: Strengthen Child-Defend prompt.** Replace "genuinely believes" framing with "steelman" framing: "Find the strongest possible case FOR this specification. What design choices are correct that a casual reader might question? What constraints are handled that aren't obvious?" This produces a more rigorous defense that gives Mother better material to synthesize.

**S-3: Elder Council graceful degradation.** When vault is unavailable, the Elder Council should compensate by doing a deeper analytical review (what patterns from software engineering generally apply?) rather than just skipping the historical dimension. Add a prompt section: "If no vault history is available, draw on general software engineering principles and common failure patterns for this type of system."

### DD-6: Replace Timeouts with Progress Checks (Liveness Probes)

**Problem:** The existing family mode hard timeouts (3min/agent, 10min/round, 25min/total) are a blunt instrument. They kill productive work as readily as stuck work. With S-1 allowing up to 3 rounds of 5 agents, the worst-case wall time (~36min) exceeds the 25min cap — but a 36-minute run that's visibly progressing should not be killed.

**Design principle:** Don't cap how long the cooking takes. Verify the cooking continues.

**Resolution: Replace total timeout with periodic progress checks.**

Remove the per-round (10min) and total (25min) hard timeouts. Keep only the per-agent timeout (3min) as a liveness check for individual agents. Add periodic progress checks between agents:

**Progress check protocol:**
After each agent completes (or after the per-agent timeout fires), verify:
1. **Did the agent produce output?** If yes → progress confirmed, continue to next agent.
2. **Did the per-agent timeout fire?** If yes → the agent is stuck. Log the stall, skip this agent, continue with remaining agents in the round (same as current behavior for individual agent timeout).
3. **Between rounds:** After Elder Council completes (or is skipped), the convergence verdict is itself a progress check — CONVERGED stops the loop, CONTINUE advances to the next round with carry-forward context.

**Check-in frequency:** After every agent completion. This is natural — there's no polling overhead because the orchestrator already waits for each serial agent (Mother, Father, Elder) to complete before dispatching the next. The check is: "did I get output?" Yes → proceed. No (timeout) → skip + log.

**What this removes:**
- Per-round timeout (10min) — replaced by per-agent checks. A round that takes 15min because the Elder Council did a thorough vault search is fine if it's producing output.
- Total timeout (25min) — replaced by round-count limit (S-1: 1/2/3 rounds). The upper bound on work is the round count, not wall time.

**What this preserves:**
- Per-agent timeout (3min) — an individual agent that produces nothing for 3 minutes is stuck, not thorough.
- Round count limit (S-1) — bounds total work by complexity, not clock.
- Forced convergence on max rounds exhausted — same behavior as before.

**Preservation contract update:** "Family mode's per-agent liveness check (3min) unchanged. Total timeout and per-round timeout removed — replaced by progress checks after each agent and round-count limits from S-1."

## Work Units

| ID | Description | Files | Dependencies | Complexity | TDD |
|----|-------------|-------|-------------|------------|-----|
| WU-1 | Update work-graph.json schema with `tdd` field (JSON boolean, absent defaults to false) | `docs/PLANNING-STORAGE.md` | None | Low | false |
| WU-2 | Add TDD annotation heuristic to spec-change.md | `commands/spec-change.md` | WU-1 | Medium | false |
| WU-3 | Restructure Stage 7 options in blueprint.md (2 options, add TDD summary line) | `commands/blueprint.md` | WU-2 | Medium | false |
| WU-4 | Add TDD-per-WU support to delegate.md | `commands/delegate.md` | WU-2 | Medium | false |
| WU-5 | Update tdd.md for WU-level invocation | `commands/tdd.md` | WU-2 | Low | false |
| WU-6 | Change default challenge mode to family | `commands/blueprint.md`, `docs/BLUEPRINT-MODES.md` | WU-3 | Low | false |
| WU-7 | Implement family mode scaffolding improvements (S-1, S-2, S-3) | `commands/blueprint.md` | WU-6 | High | false |
| WU-8 | Update documentation (README, CLAUDE.md, commands/README.md, BLUEPRINT-MODES.md token cost table) | `README.md`, `.claude/CLAUDE.md`, `commands/README.md`, `docs/BLUEPRINT-MODES.md` | WU-3, WU-6, WU-7 | Low | false |

**Atomic coupling: WU-6 MUST NOT ship without WU-7.** The vault evidence for family-as-default was domain-scoped ("specs touching hooks or safety features"), not universal. S-1 complexity-adaptive rounds (WU-7) is what makes universal default viable by capping cost for simple specs. If WU-7 regresses or is deferred, WU-6 must also be reverted.

**Note:** All WUs are `tdd: false` because this is a markdown-only change to a pure documentation/command toolkit — there is no executable code to test via RED-GREEN-REFACTOR. The toolkit's verification is `bash test.sh` which checks syntax, counts, and lint rules.

## Success Criteria

| Criterion | How to Verify |
|-----------|---------------|
| TDD is not listed as a standalone Stage 7 option | Read blueprint.md completion section — only 3 options, none named "TDD-enforced" |
| New Stage 7 has 2 options: Sequential, Parallel (Guided deferred) | Read blueprint.md completion section |
| Work graph schema includes `tdd: boolean` per WU | Read PLANNING-STORAGE.md and grep for `tdd` field |
| spec-change.md includes TDD annotation heuristic table | Read spec-change.md Work Units section |
| delegate.md adds TDD instructions to implementer prompt for `tdd: true` WUs | Read delegate.md Step 3 section |
| Default challenge mode is `family` in all references | `grep -r "debate.*default\|default.*debate" commands/ docs/ README.md` returns 0 matches |
| Family is listed as `(default)` in all mode selection references | `grep -r "family.*default\|default.*family" commands/ docs/` returns matches |
| Existing `challenge_mode: "debate"` in state.json still works | Read blueprint.md migration/resume logic |
| Child-Defend prompt uses steelman framing, not "genuinely believes" | Read blueprint.md Family Mode section |
| Elder Council has graceful degradation for no-vault | Read blueprint.md Elder Council section |
| Complexity-adaptive rounds use WU count + complexity (no risk_flags) | Read blueprint.md Family Mode Loop Control |
| Stage 7 displays "WUs with tdd:true: N of M" before implementation options | Read blueprint.md completion section |
| BLUEPRINT-MODES.md has token cost comparison row in table | Read docs/BLUEPRINT-MODES.md |
| delegate.md reads work-graph.json tdd field in Step 3 dispatch | Read delegate.md Step 3 |
| `bash test.sh` passes | Run test.sh |

## Failure Modes

| What Could Fail | Detection Method | Recovery Action |
|-----------------|------------------|-----------------|
| test.sh count checks fail after changes | test.sh Category 3 | Update expected counts in test.sh |
| Existing blueprints break on resume | Manual test: resume a debate-mode blueprint | Ensure pre-v2 migration and resume logic unchanged |
| Family mode timeouts change unintentionally | Read blueprint.md timeout section | Verify timeout values unchanged (3/10/25 min) |
| Delegate doesn't respect tdd annotation | Manual test: create spec with mixed tdd WUs, run delegate | Check implementer prompt includes TDD instructions |

## Rollback Plan

1. `git revert [commit]` — all changes are markdown, fully revertible
2. No state migration needed — work-graph.json `tdd` field is additive
3. No external systems affected

## Dependencies (Preconditions)

- [x] Current `bash test.sh` passes (baseline)
- [x] Understanding of family mode architecture (vault findings read)
- [x] Understanding of TDD experiment results (vault findings read)

## Open Questions

1. **Should the guided walkthrough (option 3) have a "batch review" variant?** — e.g., review every 3 WUs instead of every 1, for medium-sized blueprints. *Decision: Start with per-WU review. Batching can be added later if needed.*

2. **Should complexity-adaptive rounds be overridable?** — e.g., `--rounds=3` to force max rounds on a simple spec. *Decision: Yes, allow override via a comment in state.json or a flag. Family mode already has `max_rounds: 3` hardcoded; make this a configurable default.*

## Senior Review Simulation

- **They'd probably ask about:** "What happens to in-progress blueprints that were created with TDD as their Stage 7 choice? Is there state that records that?" — Answer: No. The Stage 7 choice is ephemeral (presented at completion, not stored in state.json). So there's no migration needed.
- **The non-obvious risk is:** Family mode as default will increase token usage for users who previously defaulted to debate. Users on tight budgets might be surprised.
- **The standard approach I might be missing:** A progressive disclosure pattern — start with debate-like simplicity and only escalate to family depth when needed. But this is addressed by S-1 (complexity-adaptive rounds).
- **What bites first-timers here:** Changing defaults in a tool that others have muscle-memoried. The `--challenge=debate` flag still works, but users who relied on the default getting debate will now get family.

---
Specification complete.
