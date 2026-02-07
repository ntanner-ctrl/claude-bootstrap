---
description: You MUST generate tests from spec BEFORE reading implementation. Spec-blind tests catch what implementation-aware tests miss.
arguments:
  - name: spec
    description: Path to specification or blueprint name
    required: false
---

# Spec to Tests

Generate tests from specification **without** knowledge of implementation. This is the critical constraint that prevents tautological tests.

## The Problem This Solves

```
Traditional TDD:     Spec → Test → Implementation → Test Passes ✓

AI TDD Failure:      Implementation → Test (fitted to impl) → Test Passes ✓
                     (Test is a tautology, not a verification)

Spec-Blind Testing:  Spec → Test (from spec only) → Implementation → Test Passes ✓
                           │
                           └── Test written without seeing implementation
```

## Critical Constraint

**This command receives ONLY:**
- Success criteria (testable statements)
- Preservation contract (what must not break)
- Failure modes (expected failure behaviors)

**This command must NOT access:**
- Implementation plans
- Existing code
- File/function names
- Technical approach

If the user tries to provide implementation details, redirect:

> "For spec-blind tests, I need only the *what*, not the *how*.
> What observable behaviors should this feature have?"

## Process

### Step 1: Gather Specification

From `/spec-change` output or user input:

```markdown
## Input Required

### Success Criteria
| Criterion | Testable Statement |
|-----------|-------------------|
| [what should happen] | [how to verify] |

### Preservation Contract
| Invariant | Must Remain True |
|-----------|------------------|
| [existing behavior] | [should not change] |

### Failure Modes
| Failure Condition | Expected Behavior |
|-------------------|-------------------|
| [when this happens] | [system should do this] |
```

### Step 2: Generate Behavior Tests

From success criteria, generate tests in plain English first:

```markdown
## Behavior Tests (from Success Criteria)

### Test: [criterion in plain English]
- **Setup:** [what state to create]
- **Action:** [what to trigger]
- **Assert:** [what to verify]
```

Then translate to code:

```javascript
test("[criterion in plain English]", () => {
  // Setup: [from spec]
  // Action: [from spec]
  // Assert: [from spec]
});
```

### Step 3: Generate Contract Tests

From preservation contract:

```markdown
## Contract Tests (from Preservation Contract)

### Test: [invariant] is preserved
- **Pre-state:** [establish invariant holds]
- **Action:** [perform the change]
- **Assert:** [invariant still holds]
```

```javascript
test("[invariant] is preserved after [action]", () => {
  // Establish pre-state where invariant holds
  // Perform the action
  // Assert invariant still holds
});
```

### Step 4: Generate Failure Mode Tests

From failure modes:

```markdown
## Failure Mode Tests

### Test: fails gracefully when [condition]
- **Setup:** [create failure condition]
- **Action:** [trigger operation]
- **Assert:** [correct failure behavior]
```

```javascript
test("fails gracefully when [condition]", () => {
  // Create failure condition
  // Trigger the operation
  // Assert correct failure behavior (not crash)
});
```

### Step 5: Anti-Tautology Review

Run each test through this checklist:

```markdown
## Test Review Checklist

For each test, verify:

| Test | Could pass with wrong impl? | Tests behavior not structure? | Survives refactor? | Derived from spec? |
|------|----------------------------|------------------------------|-------------------|-------------------|
| [test] | [yes = bad] | [yes = good] | [yes = good] | [yes = good] |
```

**Red flags:**
- Test mocks everything (tests nothing)
- Test checks internal method calls (couples to implementation)
- Test passes with trivial/wrong implementation
- Test would break if you refactored (but behavior unchanged)

## Output Format

```markdown
# Generated Tests: [feature/spec name]

## Source Specification

### Success Criteria Used
| Criterion | Test Coverage |
|-----------|--------------|
| [criterion] | [test name(s)] |

### Preservation Contract Used
| Invariant | Test Coverage |
|-----------|--------------|
| [invariant] | [test name(s)] |

### Failure Modes Used
| Failure | Test Coverage |
|---------|--------------|
| [failure] | [test name(s)] |

## Generated Tests

### Behavior Tests

\`\`\`javascript
// Test: [criterion 1]
test("[plain English description]", () => {
  // Setup
  // Action
  // Assert
});

// Test: [criterion 2]
...
\`\`\`

### Contract Tests

\`\`\`javascript
// Test: [invariant] is preserved
test("[invariant] remains true after [action]", () => {
  // Pre-state
  // Action
  // Assert invariant
});
\`\`\`

### Failure Mode Tests

\`\`\`javascript
// Test: graceful failure when [condition]
test("handles [failure condition] gracefully", () => {
  // Setup failure condition
  // Trigger
  // Assert correct failure behavior
});
\`\`\`

## Anti-Tautology Review

| Test | Trivial Pass? | Behavior Focus? | Refactor-Safe? | Spec-Derived? |
|------|---------------|-----------------|----------------|---------------|
| ... | ✓ | ✓ | ✓ | ✓ |

## Implementation Notes

These tests should:
1. **Fail initially** — nothing is implemented yet
2. **Pass without modification** — implementation meets spec
3. **If tests need changing** — that's a red flag (spec incomplete or impl deviated)

---
Tests generated from specification. Next:
  • Run tests (should fail — nothing implemented)
  • Implement until tests pass
  • If tests need modification → revisit spec
```

## Test Philosophy Notes

### Prefer Integration/Contract Tests

```javascript
// GOOD: Tests observable behavior
test("user can complete checkout flow", async () => {
  // End-to-end behavior test
});

test("API returns valid response shape", async () => {
  // Contract test
});

// AVOID: Tests implementation details
test("calls internal helper method", () => {
  expect(mockHelper).toHaveBeenCalled(); // Fragile
});
```

### Property-Based Testing (When Applicable)

```javascript
// Test invariants that should always hold
test.property("sorted output is always in order", (input) => {
  const result = sort(input);
  return isOrdered(result);
});
```

## Output Artifacts

Save to:
- Blueprint tracking: `.claude/plans/[name]/tests.md`
- Project tests: `tests/[feature].spec.js` or equivalent

## Integration

- **Fed by:** `/spec-change` (success criteria, preservation contract, failure modes)
- **Part of:** `/blueprint` wizard (Stage 6), `/test` wizard
- **Verified by:** Running test suite
