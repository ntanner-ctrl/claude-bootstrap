# Describe: wizard-state-management

## Context

This blueprint is a continuation of `wizard-standardization` (completed 2026-03-24). That blueprint added structural sections (cognitive traps, failure modes, known limitations, vault awareness) to all 5 Workflow Wizards. This blueprint adds the *behavioral* layer: state machines, persistence, resumability, and vault checkpoints.

## Problem Statement

Only `/blueprint` has state management. The other 4 wizards (`/prism`, `/review`, `/test`, `/clarify`) are ephemeral — they run start-to-finish with no persistent state. This means:

- **No resume on compaction** — if context compacts mid-wizard, progress is lost
- **No stage enforcement** — nothing prevents skipping stages; `blueprint-stage-gate.sh` has nothing to check
- **No confidence tracking** — no epistemic integration outside blueprint
- **No status display** — blueprint's `✓/→/○` stage markers exist nowhere else
- **No vault checkpoints** — intermediate findings aren't captured; only final output (if any) goes to vault

TDD's `tdd-sessions/active.json` pattern proves that state tracking enables enforcement (the TDD guardian hook verifies phase progression). Blueprint's `state.json` + `manifest.json` proves that state tracking enables resumability and regression loops. Both have paid dividends in practice.

## What "Wizard-Grade State Management" Means

Derived from blueprint's state infrastructure:

| Capability | Blueprint Has It | Others Need It |
|-----------|-----------------|----------------|
| `state.json` with stage tracking | ✓ | ✓ |
| Stage progression display (`✓/→/○`) | ✓ | ✓ |
| Resume from state on re-invocation | ✓ | ✓ |
| Resume after context compaction (read state from disk) | ✓ | ✓ |
| Vault checkpoint at key moments | ✓ | ✓ |
| Confidence scoring per stage | ✓ | Nice-to-have |
| Manifest (token-dense recovery) | ✓ | Probably overkill for shorter wizards |
| Regression loops | ✓ | Blueprint-specific, not needed |

## Design Challenge: Different Progression Shapes

Each wizard has a unique progression shape — the state schema must accommodate all of them:

| Wizard | Shape | Stages |
|--------|-------|--------|
| `/blueprint` | Linear with regression loops | 7 stages + sub-stages (4.5), feedback loops |
| `/prism` | Parallel wave → serial chain → synthesis | Stage 0 (context) → Wave 1 (6 parallel) → Stages 2-5 (serial) → Stage 6 (synthesis) → Stage 7 (report) |
| `/review` | Linear with optional tail | 5 stages, last 2 optional/plugin-dependent |
| `/test` | Linear with conditional skip | 3 stages, Stage 1 skippable if TDD active |
| `/clarify` | Conditional branching | 6 steps, Steps 2-5 conditionally run based on Step 1 assessment |

A shared schema must handle: linear stages, parallel waves, conditional steps, and optional stages. It should NOT force every wizard into blueprint's exact shape.

## Steps (Decomposed)

1. **Design shared wizard state schema** — lightweight `state.json` that works for all progression shapes. Must support: linear, parallel, conditional, optional stages. Reference blueprint's schema but don't copy its complexity wholesale.
2. **Add state management to `/prism`** — stage tracking (Wave 1 parallel, Stages 2-5 serial, synthesis), resume on compaction, vault checkpoint after Wave 1 and after synthesis
3. **Add state management to `/review`** — stage tracking (5 stages), resume on compaction, vault checkpoint after compilation
4. **Add state management to `/test`** — stage tracking (3 stages), resume on compaction, vault checkpoint after test generation
5. **Add state management to `/clarify`** — step tracking (conditional steps), resume on compaction, vault checkpoint after summary
6. **Add stage progression display** (`✓/→/○` status block) to all 4 wizards
7. **Update `test.sh`** — add wizard state validation (state.json valid JSON when wizard active)
8. **Document the wizard state contract** — so future wizard authors know the requirements

## Triage Result

- **Steps:** 8
- **Risk flags:** User-facing behavior change
- **Path:** Full
- **Execution preference:** Auto

## Key Design Questions for Stage 2 (Specify)

1. **Where does wizard state live?** Blueprint uses `.claude/plans/[name]/`. Should other wizards use a parallel structure like `.claude/wizards/[name]/`? Or reuse `.claude/plans/`?
2. **How heavyweight is the state?** Blueprint has state.json + manifest.json + multiple artifact files. `/clarify` finishes in 2-3 minutes — does it need all that? What's the minimum viable state?
3. **How do parallel stages (prism Wave 1) map to state?** Blueprint's family mode tracks `family_progress.agents_completed`. Prism needs similar tracking for 6 parallel lens agents.
4. **Should the state schema be versioned?** Blueprint has `blueprint_version: 2` and a migration path. Is this needed for all wizards from day 1?
5. **What triggers vault checkpoints?** Blueprint exports at completion. Should intermediate vault writes happen (e.g., after prism's Wave 1), or only on completion?

## Vault Context

Relevant vault findings (search for these in the next session):
- `2026-03-22-prism-premortem-context-exhaustion` — orchestrator context exhaustion; relevant to prism state design
- `2026-03-22-prism-serial-context-compression` — serial context must be compressed between stages
- `2026-03-24-liveness-probes-over-timeouts` — progress checks over hard timeouts for agent workflows
- Session `2026-03-24` wizard-standardization — the blueprint that preceded this work

## Predecessor

Blueprint: `wizard-standardization` (completed, all tests passing, not yet committed)
Files modified by predecessor: `commands/{blueprint,prism,clarify,review,test}.md`, `README.md`, `commands/README.md`, `test.sh`
