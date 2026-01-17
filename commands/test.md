---
description: Testing workflow wizard - spec to tests to verification
arguments:
  - name: name
    description: Plan name or feature to test
    required: false
---

# Test

Guided testing workflow that ensures tests are derived from specification, not implementation.

## Overview

```
Stage 1: Spec Review   → Verify spec has testable criteria
Stage 2: Generate      → Create tests from spec (spec-blind)
Stage 3: Verify        → Run tests, check for tautologies
```

## Process

### Stage 1: Spec Review

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TEST: [name] │ Stage 1 of 3: Spec Review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Provide the specification to test from:

  [1] Existing spec file (provide path)
  [2] Current /plan artifacts (loads from .claude/plans/[name]/)
  [3] Describe criteria now

>
```

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

## Red Flags

Watch for these anti-patterns:

| Anti-Pattern | Sign | Action |
|--------------|------|--------|
| Tautology | Test passes trivially | Add meaningful assertions |
| Implementation coupling | Test checks internal calls | Rewrite to test behavior |
| Mock everything | All dependencies mocked | Use integration test instead |
| Test modification | Changed test to pass | Review spec vs implementation |

## Integration

- **Uses:** `/spec-to-tests` (Stage 2)
- **Part of:** `/plan` wizard (Stage 6)
- **Fed by:** `/spec-change` (testable criteria)
