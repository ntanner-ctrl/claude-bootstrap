# Pre-Mortem: /prism

## Premise
Prism was implemented and shipped two weeks ago. It failed. This post-mortem focuses on OPERATIONAL failures — installation, UX, maintenance, and real-world usage patterns.

## Most Likely Cause of Failure

**Context window exhaustion during synthesis (F17)** — the orchestrator's own session context is never modeled. By Stage 5 (quality review), the orchestrator holds 6,000-10,000+ tokens of accumulated context before synthesis begins. Synthesis is inline (not a subagent), so it runs in an already-saturated session. The output appears complete but may contain confabulated file:line references and invented constraint summaries. Silent failure — the report looks right but isn't.

## Findings

### NEW — Actionable (should add to spec)

| ID | Finding | Severity | Recommendation |
|----|---------|----------|----------------|
| F7 | No progress indication during 15-30 min runtime | HIGH | R2: Add structured progress narration per stage |
| F11 | Constraint extraction audit missing from vault export template | HIGH | R3: Add audit section to vault note template |
| F12 | /quality-sweep vs /prism confusable, no decision guide | HIGH | R7: Add decision rule to /toolkit and README |
| F17 | Orchestrator session token budget never modeled | HIGH | R1: Add token estimation step to Stage 0 |
| F19 | Session survivability after prism unaddressed | MEDIUM | R6: Add "start fresh session" note to report footer |
| F4 | Vault template in wrong directory (templates/vault-notes/ is for bootstrap targets) | MEDIUM | Move to inline in prism.md or separate location |
| F8 | No minimum scope floor — 3-file project gets 11 agents | MEDIUM | R4: Warn below 10 files |
| F3 | Description trigger field not yet specified — risk of false invocations | MEDIUM | R5: Specify tight trigger + add evals fixture |

### NEW — Acknowledge Only (not spec changes)

| ID | Finding | Note |
|----|---------|------|
| F2 | Users with old installs get "command not found" | Existing limitation of all claude-sail commands; not prism-specific |
| F5 | 100-file warning fires on claude-sail itself | Correct behavior; first-run test should use a different project |
| F6 | Lens output on all-markdown projects is low signal | Covered in Known Limitations section |
| F9 | Directory rename breaks longitudinal tracking | Inherent to slug-based naming; low frequency |
| F14 | New domain reviewers require manual prism updates | Standard maintenance; add note to "Adding a new agent" guide |
| F15 | No lens prompt tuning feedback loop | Inherent to static markdown architecture |
| F18 | Non-deterministic Wave 1 ordering | Doesn't affect correctness; minor cross-run variance |

### COVERED — Already in spec or adversarial findings

| ID | Finding | Covered by |
|----|---------|-----------|
| F1 | Test.sh count mismatch on partial updates | W10, W11 work units (coupled dependency noted) |
| F10 | No diff mechanism between prism runs | Vault "Recurring Themes" section (partial) |
| F13 | prism-to-blueprint handoff underspecified | Next Steps section (pointer, not bridge) |
| F16 | test.sh doesn't specify which assertion to update | W11 work unit (trivial label may understate risk) |

## Recommendations Summary

| # | Recommendation | Addresses | Effort |
|---|---------------|-----------|--------|
| R1 | Token budget estimation in Stage 0 | F17 | Small — estimate formula + user display |
| R2 | Structured progress narration per stage | F7 | Small — stage headers in orchestrator |
| R3 | Constraint audit in vault export template | F11 | Trivial — add section to template |
| R4 | Minimum scope floor warning (<10 files) | F8 | Trivial — one check + message |
| R5 | Evals fixture for prism trigger behavior | F3 | Small — add to evals.json |
| R6 | "Start fresh session" note in report footer | F19 | Trivial — one line in output format |
| R7 | Decision rule in /toolkit for sweep vs prism | F12 | Trivial — one line in README |

## Contributing Factors

1. No progress indication (F7) — user can't tell which stage is running
2. Vault export omits constraint audit (F11) — primary auditability mechanism lost on save
3. No minimum scope guard (F8) — tiny projects establish false baseline
4. No session context warning (F19) — user acts on findings in exhausted session

## Early Warning Signs Missed

1. No token budget success criterion in the spec
2. test.sh criterion is count-only, no behavioral eval for prism
3. naksha-inspired blueprint (similar complexity) needed 4 revisions — flagged as neutral, should have been a warning
4. "All agents see all files" deferred as v2 concern but is the root cause of v1 context exhaustion
