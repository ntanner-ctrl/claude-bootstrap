---
description: You MUST use this after ANY significant implementation. Untested code is unfinished code — run this before declaring work complete.
arguments:
  - name: name
    description: Blueprint name or feature to test
    required: false
---

## Cognitive Traps

Before skipping or simplifying this command, check yourself:

| Rationalization | Why It's Wrong |
|----------------|---------------|
| "Those test failures are pre-existing" | Prove it. Run the tests on the base branch. If you can't, you can't claim they're pre-existing. |
| "The change is too small to break anything" | The smallest changes cause the most surprising failures. A one-character typo can break a build. |
| "I'll write tests after" | "After" never comes. Tests written alongside code catch design issues; tests written after just verify the (possibly wrong) implementation. |

# Test

Guided testing workflow that ensures tests are derived from specification, not implementation.

## Overview

```
Stage 1: Spec Review   → Verify spec has testable criteria
Stage 2: Generate      → Create tests from spec (spec-blind)
Stage 3: Verify        → Run tests, check for tautologies
```

## Pre-check: Active TDD Session

Before starting, check for an active TDD session:
```bash
cat .claude/tdd-sessions/active.json 2>/dev/null
```

- **If active TDD session exists** → Validate phase progression (tests should already exist from RED phase). Skip to Stage 3 (Verify).
- **If no TDD session** → Proceed normally. For NEW features, suggest: "Consider `/tdd` for test-first development."

## Process

### Stage 1: Spec Review

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TEST: [name] │ Stage 1 of 3: Spec Review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Provide the specification to test from:

  [1] Existing spec file (provide path)
  [2] Current /blueprint artifacts (loads from .claude/plans/[name]/)
  [3] Describe criteria now

>
```

#### Vault Check

Before reviewing the spec, check for prior test work:

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null
```

If vault is available (`VAULT_ENABLED=1`, `VAULT_PATH` non-empty, `[ -d "$VAULT_PATH" ]`):
- Search for prior test specs, edge case discoveries, or findings related to the feature
- If matches found: "Vault has N notes related to testing this feature:" [list with 1-line summaries]
- These may contain edge cases or failure modes discovered in prior sessions
- If no matches: proceed silently

If vault unavailable: skip silently (fail-open).

Once spec is loaded, verify testability:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TEST: [name] │ Stage 1 of 3: Spec Review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Reviewing specification for testability...

## Success Criteria
| # | Criterion | Testable? | Issue |
|---|-----------|-----------|-------|
| 1 | [criterion] | ✓ | — |
| 2 | [criterion] | ⚠️ | Vague: "works correctly" |
| 3 | [criterion] | ✓ | — |

## Preservation Contract
| # | Invariant | Testable? | Issue |
|---|-----------|-----------|-------|
| 1 | [invariant] | ✓ | — |

## Failure Modes
| # | Failure | Testable? | Issue |
|---|---------|-----------|-------|
| 1 | [failure] | ✓ | — |

Issues found: 1
  - Criterion 2 is vague. Suggest: "[specific testable version]"

Resolve issues before proceeding? [y/n]
>
```

  Stage 1 complete: [N] criteria reviewed, [N] issues found. Proceeding to Stage 2 (Generate).

### Stage 2: Generate Tests

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TEST: [name] │ Stage 2 of 3: Generate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Generating tests from specification...

⚠️ SPEC-BLIND MODE: I will generate tests from the spec only.
   I should NOT see implementation details.
```

Run `/spec-to-tests` with the reviewed specification.

```
Tests generated:
  - 3 behavior tests (from success criteria)
  - 1 contract test (from preservation contract)
  - 2 failure mode tests (from failure modes)

Total: 6 tests

Proceed to verification? [y/n]
>
```

  Stage 2 complete: [N] tests generated. Proceeding to Stage 3 (Verify).

### Stage 3: Verify

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TEST: [name] │ Stage 3 of 3: Verify
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Running anti-tautology checks...
```

#### Tautology Detection

For each test, check:

```markdown
## Anti-Tautology Review

| Test | Trivial Pass? | Behavior Focus? | Refactor-Safe? | Spec-Derived? |
|------|---------------|-----------------|----------------|---------------|
| test 1 | ✓ No | ✓ Yes | ✓ Yes | ✓ Yes |
| test 2 | ⚠️ Maybe | ✓ Yes | ✓ Yes | ✓ Yes |
| test 3 | ✓ No | ✓ Yes | ✓ Yes | ✓ Yes |

⚠️ Test 2 might pass with trivial implementation.
   Consider: adding edge case assertions.
```

#### Run Tests (if implementation exists)

```
Run tests against current implementation?
  [1] Yes - run tests now
  [2] No - implementation doesn't exist yet (expected)
  [3] Skip - just save the tests

>
```

If run:
```
Test Results:
  ✓ 4 passed
  ✗ 2 failed

Failed tests:
  - test_handles_empty_input: Expected error, got null
  - test_preserves_timestamps: Timestamp changed unexpectedly

This is expected if implementation is incomplete.
If implementation IS complete, these failures indicate spec/impl mismatch.
```

### Completion

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TEST: [name] │ Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Summary

Tests generated: 6
  - Behavior tests: 3
  - Contract tests: 1
  - Failure tests: 2

Tautology check: 5/6 passed (1 flagged for review)

Artifacts:
  - .claude/plans/[name]/tests.md (test specifications)
  - tests/[name].spec.js (executable tests)

## Next Steps

If implementation doesn't exist:
  1. Run tests (they should fail)
  2. Implement until tests pass
  3. If tests need modification → RED FLAG, revisit spec

If implementation exists:
  1. Run tests
  2. Fix failing tests OR fix implementation
  3. Never modify tests just to pass — that defeats the purpose

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Failure Modes

| What Could Fail | Detection | Recovery |
|-----------------|-----------|----------|
| Spec has no testable criteria | Stage 1 finds 0 testable items | Return to spec author. Suggest concrete acceptance criteria. Cannot generate meaningful tests from vague specs. |
| /spec-to-tests produces no tests | Stage 2 output is empty | Spec criteria may be too abstract. Break into smaller, more concrete assertions. |
| All tests pass trivially | Stage 3 anti-tautology check flags majority of tests | Tests are checking implementation, not behavior. Rewrite to test observable outcomes, not internal state. |
| Implementation doesn't exist yet | Stage 3 "run tests" finds no code | Expected state for test-first workflows. Save tests, implement until they pass. |
| Tests require mocks that don't exist | Stage 2 generates tests referencing unavailable dependencies | Use integration tests instead, or stub the dependency interface first. |

## Red Flags

Watch for these anti-patterns:

| Anti-Pattern | Sign | Action |
|--------------|------|--------|
| Tautology | Test passes trivially | Add meaningful assertions |
| Implementation coupling | Test checks internal calls | Rewrite to test behavior |
| Mock everything | All dependencies mocked | Use integration test instead |
| Test modification | Changed test to pass | Review spec vs implementation |

## Known Limitations

- **Spec-dependent quality** — Test quality is bounded by spec quality. Vague specs produce vague tests. /test cannot compensate for a weak specification.
- **No runtime environment awareness** — Tests are generated from spec text, not from runtime context. Environment-specific failures (OS, network, permissions) are not covered unless the spec mentions them.
- **Single test framework assumption** — /spec-to-tests generates tests in the project's detected framework. Projects with multiple test frameworks may need manual adjustment.
- **Anti-tautology is heuristic** — The Stage 3 tautology check uses pattern matching, not formal verification. Some trivially-passing tests may slip through.

## Integration

- **Uses:** `/spec-to-tests` (Stage 2)
- **Part of:** `/blueprint` wizard (Stage 6)
- **Fed by:** `/spec-change` (testable criteria)
- Also available (user-initiated): If `testing-suite` plugin is installed, `/generate-tests` and `/test-coverage` provide comprehensive test automation and coverage analysis
