# Debrief: critique-architecture

## Ship Reference
- Commit: 42bce39
- Date: 2026-03-28
- Files: 5 modified, 8 plan artifacts added (+2618 lines)

## Spec Delta
No regressions triggered. Spec stable through implementation. Zero revisions.

## Deferred Items
- **PM-2 (turn-level checkpointing implementation):** Spec describes it but implementation is behavioral — Claude must follow the instruction. No enforcement mechanism.
- **PM-5/R4 (critique-mode behavioral evals):** test.sh has no critique-specific fixtures. Deferred to first real-world usage — need actual critique output to build meaningful fixtures.
- **PM-6/PM-7 (Light tier production validation):** Light tier is specified but untested end-to-end. Gated as "use at your own risk" until 3 real runs validate it.
- **T1 (ID mapping storage location):** Spec says state.json. Implementation is behavioral.
- **T2 (Light tier Diverge reinforcement math):** Tuning parameter deferred to empirical observation.
- **OQ-1/OQ-2/OQ-3 (Refine thresholds, Orient cap, anonymization effectiveness):** Original open questions remain empirically unvalidated.

## Discoveries
- **The bootstrapping paradox was educational:** This blueprint used family mode to challenge its own replacement. Family mode's final act was producing a thorough 2-round challenge (CONVERGED at 0.91) and a 1-round edge case analysis (0.92) of the architecture designed to replace it.
- **Pre-mortem found a nearly orthogonal failure class (11% overlap):** PM-1 (context exhaustion) was the single most important finding and could not have been caught by design review. Back-of-envelope token math should be a standard pre-mortem exercise.
- **O(N²) context growth in Clash was hidden in plain sight:** The architecture says "parallel agents, sparse cross-examination" which sounds efficient, but N positions × N examinations is quadratic. The context budget check (R1) was the operational fix.
- **Edge case E6 (dedup destroys compound signal) was a silent ordering bug:** The spec described deduplication and compound detection as sequential steps without specifying that dedup must preserve agreement counts. This class of bug — correct steps in wrong order — only surfaces through boundary analysis.

## Reflection

### Wrong Assumptions
- Assumed "read-only scan" was a self-explanatory architectural description. It wasn't — "read-only" contradicted "downstream agents consume output" without an explicit handoff mechanism (E5).
- Assumed WU count was a sufficient proxy for tier selection. It isn't — a 1-WU auth change is higher-stakes than a 10-WU display refactor (F5).

### Difficulty Calibration
- **Easier than expected:** The implementation itself was straightforward — inserting a coherent section into blueprint.md. The adversarial findings mapped cleanly to spec additions.
- **Harder than expected:** The adversarial stages were thorough and context-heavy. Running family mode's full 2-round challenge + 1-round edge cases + pre-mortem consumed significant context.

### Advice for Next Planner
- Run back-of-envelope token math during the pre-mortem, not after.
- Edge case analysis of ordering dependencies (what runs before what, what state must exist) catches bugs that design review misses.
- The pre-mortem's "imagine it shipped and failed" frame is genuinely different from "what could go wrong." The former produces operational failures; the latter produces design concerns.
