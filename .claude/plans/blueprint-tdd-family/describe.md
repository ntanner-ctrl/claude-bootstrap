# Triage: Blueprint TDD + Family Mode Changes

## Change Summary

Two architectural shifts to the blueprint workflow:

1. **TDD becomes atomic-level enforcement** — Remove TDD as a standalone Stage 7 implementation option. Instead, annotate each work unit with `tdd: true/false` during Stage 2 (Specify), and enforce RED-GREEN-REFACTOR at the individual WU level for both sequential and parallel paths.

2. **Family mode becomes default challenge mode** — Change the default from `debate` to `family`. Assess family mode for strengths and weaknesses, and implement scaffolding improvements based on findings.

## Discrete Steps

| # | Step |
|---|------|
| 1 | Remove TDD as a standalone implementation option from blueprint Stage 7 |
| 2 | Embed TDD enforcement into the standard (sequential) implementation path |
| 3 | Embed TDD enforcement into the parallel implementation path |
| 4 | Determine what the replacement third option should be (design decision) |
| 5 | Implement the replacement third option |
| 6 | Change default challenge mode from `debate` to `family` |
| 7 | Assess family mode for strengths and weaknesses |
| 8 | Implement scaffolding improvements based on assessment findings |

## Risk Flags

- [x] User-facing behavior change — default mode changes, option removal

## Path Determination

**8 steps + 1 risk flag → Full path**

## Execution Preference

**Auto** — steps 1-3 are tightly coupled, 4-5 are a design decision followed by implementation, 6 is independent, and 7-8 are sequential. Natural mix of parallel and serial work.

## Vault Context

Vault has 5 notes directly relevant to this work:

1. **[hybrid-tdd-parallel-dispatch-experiment](2026-03-25)** — Controlled experiment proving TDD + parallel works. 100% first-pass GREEN with good specs. Recommends `tdd: true/false` as WU property.
2. **[family-debate-catches-critical-bugs](2026-03-20)** — Family mode caught 6 critical bugs that vanilla/debate would have missed. Mother's synthesis was key mechanism.
3. **[compound-failures-family-mode](2026-03-18)** — Family mode's parallel children + synthesis mother is especially good at finding compound failures.
4. **[debate-convergence-pattern](2026-03-18)** — Debate rounds converge predictably. 3 rounds sufficient.
5. **[adversarial-review-taxonomy](2026-03-20)** — Pattern: different techniques find orthogonal failure classes. Family mode best for compound failures and edge cases.
