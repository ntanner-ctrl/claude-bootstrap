---
description: You MUST use this after ANY significant implementation. Untested code is unfinished code — run this before declaring work complete.
arguments:
  - name: name
    description: Blueprint name or feature to test
    required: false
---

## State Management

At the start of this wizard, initialize or resume persistent state in `.claude/wizards/`.

### State Initialization

```
1. Ensure .claude/wizards/ exists (mkdir -p .claude/wizards/)
2. Check for active session: ls .claude/wizards/test-*/state.json
   - If multiple matches: select most recent by created_at timestamp, archive others
3. If active session found (status == "active"):
   - Validate version == 1 (if mismatch: treat as corrupt, start fresh)
   - Compute session age from created_at
   - If age > 4 hours: prefix display with ⚠️  "Note: session is [age] old — may be stale"
   - Display stage progression header (see Stage Progression below)
   - Prompt:
       Previous test session from [age ago] — paused at [current_step].
         [1] Resume from [current_step]
         [2] Abandon and start fresh
   - If status == "error": show "Previous session errored at [step]." then same [1]/[2] prompt
   - On Resume: reconstruct context from output_summaries + context object (see Resume Protocol below)
   - On Abandon: set status: "abandoned", create new session
4. If no active/error session → create new directory + state.json:
   - session_id: "test-YYYYMMDD-HHMMSS" (current timestamp)
   - wizard: "test", version: 1, status: "active"
   - current_step: "tdd_check"
   - steps: { tdd_check: {status:"pending"}, spec_review: {status:"pending"}, generate_tests: {status:"pending"}, verify: {status:"pending"} }
   - context: { spec_source: null, blueprint_name: null, tdd_active: null }
5. Cleanup: for each .claude/wizards/test-*/state.json where age > 7 days AND status in (complete, abandoned, error):
   move directory to .claude/wizards/_archive/ (fail-open: skip if error)
6. Display stage progression header
```

### Stage Progression Display

Render this header at each stage transition (read from state.json):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TEST │ Stage: [current stage name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [status] TDD Check
  [status] Spec Review
  [status] Generate Tests
  [status] Verify

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Status symbols: `✓` complete, `→` active, `○` pending, `—` skipped

### Resume Protocol

On resume, reconstruct working context from state.json before continuing:

- Read `context` object: `spec_source`, `blueprint_name`, `tdd_active`
- Read `output_summary` from each completed step:
  - `tdd_check`: TDD active (yes/no), phase if active — skip pre-check logic, use stored result
  - `spec_review`: spec source, work unit count, testability verdict — skip re-loading spec
  - `generate_tests`: test count, coverage areas, anti-tautology results — tests already generated
- Resume from `current_step`, briefing user on prior progress from the summaries

### State Write Points

After each step completes, update state.json with:
- step status: "complete", completed_at: ISO timestamp
- output_summary per the Test Content Contract (see docs/WIZARD-STATE.md)
- current_step: next step name
- updated_at: ISO timestamp

On completion: status: "complete", current_step: null

**Vault checkpoint:** After generate_tests completes, if vault is configured, export test specifications (fail-open — vault unavailability does not block wizard progress).

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

**State update:** Mark `tdd_check` complete. output_summary: "TDD active: [yes/no][, phase: [phase] if yes]". Set `context.tdd_active`. Set `current_step: "spec_review"` (or `"verify"` if skipping to Stage 3).

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

**State update:** Mark `spec_review` complete. output_summary: "Spec from [source], [N] work units/criteria, testability: [high/medium/low with issue count]". Set `context.spec_source`, `context.blueprint_name`. Set `current_step: "generate_tests"`.

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

**State update:** Mark `generate_tests` complete. output_summary: "[N] tests generated: [N] behavior, [N] contract, [N] failure mode; anti-tautology: [N]/[N] clean". Set `current_step: "verify"`. Trigger vault checkpoint if configured (fail-open).

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

**State update:** Mark `verify` complete. output_summary: "Tests run: [yes/no][; passed: N, failed: N if run]". Set `status: "complete"`, `current_step: null`, `updated_at: ISO timestamp`.

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
