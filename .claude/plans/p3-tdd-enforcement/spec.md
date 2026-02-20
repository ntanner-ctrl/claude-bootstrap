# Priority 3: TDD Enforcement

## Full Specification

### Summary

Create a `/tdd` command that enforces true RED-GREEN-REFACTOR discipline by verifying tests exist and fail before allowing implementation, with optional "aggressive mode" that deletes code written before tests.

---

## What Changes

### Files/Components Touched

| File | Nature of Change |
|------|------------------|
| New: `commands/tdd.md` | Add - main TDD enforcement command |
| New: `hooks/tdd-guardian.sh` | Add - shell hook for pre-edit validation |
| `commands/test.md` | Modify - integrate TDD as prerequisite option |
| `commands/plan.md` | Modify - add TDD stage option |
| New: `docs/TDD-ENFORCEMENT.md` | Add - philosophy and usage guide |

### External Dependencies
- None new (uses existing test runners)

### Database/State Changes
- New state tracking in `.claude/tdd-sessions/[id].json`

---

## The Problem

Claude skips tests. Even when asked for TDD, it often:
1. Writes implementation first
2. Retrofits tests that pass by definition
3. Tests internal implementation details instead of behavior
4. Writes tests that would pass with trivial/wrong implementations

Superpowers solves this by **deleting code written before tests**. That's extreme but effective.

---

## The Solution: Graduated TDD Enforcement

### Mode 1: Advisory (Default)
- Reminds about TDD
- Warns if implementation detected before tests
- Logs violations but doesn't block

### Mode 2: Strict
- Refuses to write implementation until tests exist
- Verifies tests actually fail before proceeding
- Blocks progression on violation

### Mode 3: Aggressive
- Everything in Strict, plus:
- **Deletes implementation code written before tests**
- Requires explicit opt-in

---

## Command Design: `/tdd`

### Invocation
```bash
/tdd [target] [--mode advisory|strict|aggressive] [--target path/to/code]
```

### Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                     TDD ENFORCEMENT                          │
└─────────────────────────────────────────────────────────────┘

Phase 1: SPECIFICATION
  │
  ├── What behavior are we implementing?
  ├── What are the acceptance criteria?
  └── Save to .claude/tdd-sessions/[id]/spec.md

Phase 2: RED (Write Failing Tests)
  │
  ├── Generate test file from spec
  ├── Run tests → MUST FAIL
  │   ├── If tests pass → ERROR: "Tests should fail. Implementation exists?"
  │   └── If tests fail → PROCEED
  └── Checkpoint: tests committed/staged

Phase 3: GREEN (Minimal Implementation)
  │
  ├── NOW you may write implementation
  ├── Write ONLY enough to pass tests
  ├── Run tests → MUST PASS
  │   ├── If tests fail → iterate implementation
  │   └── If tests pass → PROCEED
  └── Checkpoint: implementation committed/staged

Phase 4: REFACTOR (Optional)
  │
  ├── Clean up implementation
  ├── Run tests after each change
  └── Tests MUST still pass

Phase 5: VERIFY
  │
  ├── Anti-tautology check (from /test)
  ├── Behavior focus check
  └── Confirm spec coverage
```

---

## Enforcement Mechanisms

### Pre-Edit Hook (tdd-guardian.sh)

When TDD session is active:

```bash
#!/bin/bash
# tdd-guardian.sh - blocks implementation edits before tests

TDD_SESSION=$(cat .claude/tdd-sessions/active.json 2>/dev/null)
if [ -z "$TDD_SESSION" ]; then
  exit 0  # No active TDD session
fi

PHASE=$(echo "$TDD_SESSION" | jq -r '.phase')
TARGET=$(echo "$TDD_SESSION" | jq -r '.target')
EDIT_FILE="$1"

# If in RED phase and editing implementation file
if [ "$PHASE" = "red" ] && [[ "$EDIT_FILE" == "$TARGET"* ]] && [[ "$EDIT_FILE" != *"test"* ]] && [[ "$EDIT_FILE" != *"spec"* ]]; then
  echo "BLOCKED: TDD session in RED phase"
  echo "You must write failing tests before implementation."
  echo "Current target: $TARGET"
  echo "To write tests, edit: ${TARGET%.*}.test.* or ${TARGET%.*}.spec.*"
  exit 2
fi

exit 0
```

### State Tracking

`.claude/tdd-sessions/active.json`:
```json
{
  "id": "uuid",
  "started": "2026-01-22T10:00:00Z",
  "mode": "strict",
  "phase": "red",
  "target": "src/auth/login.ts",
  "test_file": "src/auth/login.test.ts",
  "spec": {
    "behavior": "User login with email and password",
    "criteria": [
      "Valid credentials return session token",
      "Invalid credentials return 401",
      "Missing fields return 400"
    ]
  },
  "checkpoints": {
    "spec_written": "2026-01-22T10:05:00Z",
    "tests_written": null,
    "tests_fail": null,
    "impl_written": null,
    "tests_pass": null
  }
}
```

### Aggressive Mode: Code Deletion

When aggressive mode is enabled and implementation is detected before tests:

```
⚠️ AGGRESSIVE TDD VIOLATION DETECTED

Implementation code found in: src/auth/login.ts
But no tests exist in: src/auth/login.test.ts

In aggressive mode, this implementation will be DELETED.

Options:
  [1] Delete implementation, proceed with TDD (recommended)
  [2] Abort TDD session, keep implementation
  [3] Convert to advisory mode, keep both

Choose [1/2/3]:
```

If user chooses 1:
```bash
# Backup to .claude/tdd-sessions/[id]/deleted/
mkdir -p .claude/tdd-sessions/[id]/deleted
cp src/auth/login.ts .claude/tdd-sessions/[id]/deleted/
git checkout src/auth/login.ts  # or truncate if new file
```

---

## Integration with Existing Commands

### With `/test`
```yaml
# In /test, add TDD prerequisite check
Pre-check:
  Active TDD session?
  ├── Yes → Validate phase progression
  └── No → Proceed normally (suggest /tdd for new work)
```

### With `/plan`
```yaml
# In /plan Stage 7 (Execute), add TDD option
Execute Options:
  [1] Standard implementation
  [2] TDD-enforced implementation ← invokes /tdd
```

### With `/spec-change`
```yaml
# Spec output includes TDD-ready criteria
Success Criteria → directly usable as TDD spec
```

---

## Preservation Contract

- **Existing test workflow:** `/test` still works without TDD enforcement
- **Non-TDD work:** Can still write code normally if not in TDD session
- **Test frameworks:** Works with any test runner (detects from project)

---

## Success Criteria

| Criterion | How to Verify |
|-----------|---------------|
| RED phase blocks implementation | Try to edit impl file in red phase → blocked |
| Tests must actually fail | Write passing test → error until it fails |
| GREEN phase requires passing tests | Can't proceed to refactor with failing tests |
| Aggressive mode deletes pre-test code | Enable aggressive, write impl first → deleted |
| Integration with /test works | /tdd session flows into /test verification |

---

## Failure Modes

| What Could Fail | Detection | Recovery |
|-----------------|-----------|----------|
| Hook misidentifies test files | Files named weird | Configurable test patterns |
| Tests pass unexpectedly | Mock data / existing impl | Clear instructions on why this is wrong |
| Aggressive mode too destructive | User anger | Backup before delete, easy recovery |
| Can't detect test framework | No jest/pytest/etc | Fallback to manual verification |

---

## Rollback Plan

1. Remove `commands/tdd.md`
2. Remove `hooks/tdd-guardian.sh`
3. Remove from settings.json hooks config
4. All TDD sessions are in `.claude/tdd-sessions/` - can delete

---

## Open Questions

1. **Should aggressive mode be the default?** Superpowers does this. We could make strict default and aggressive opt-in.

2. **How to handle existing codebases?** TDD for new code is easy. What about adding tests to existing code? (Maybe a separate mode: "retrofit")

3. **Multi-file features?** Should one TDD session span multiple files, or one session per file?

4. **CI integration?** Should there be a way to run TDD validation in CI?

---

## Senior Review Simulation

- **They'd ask:** "What about integration tests that span multiple units?"
  - Answer: TDD session can have multiple test files; red phase needs ALL to fail

- **Non-obvious risk:** Developers might game the system (write trivially-failing tests)
  - Mitigation: Anti-tautology check inherited from /test

- **Standard approach:** Most TDD tools don't delete code, they just report
  - Counter: That's why TDD is often skipped. Teeth matter.

- **What bites first-timers:** Not understanding why tests "should" fail
  - Mitigation: Clear explanation that RED proves the test would catch bugs

---

## Implementation Steps

### Phase 1: Core Command (2 hours)
1. Create `commands/tdd.md` with workflow
2. Implement state tracking (JSON files)
3. Add phase progression logic

### Phase 2: Guardian Hook (1 hour)
1. Create `hooks/tdd-guardian.sh`
2. Integrate with settings.json
3. Test blocking behavior

### Phase 3: Aggressive Mode (1 hour)
1. Add deletion logic with backup
2. Add recovery commands
3. Test thoroughly

### Phase 4: Integration (1 hour)
1. Connect to `/test` for verification
2. Add to `/plan` as execution option
3. Document in new guide

### Phase 5: Pressure Testing (1 hour)
1. Test all three modes
2. Try to bypass/game the system
3. Strengthen weak points

---

**Estimated Total Effort:** 1 dedicated session (6-7 hours)
**Dependencies:** None, but benefits from P2 (enforcement language)
**Blocks:** Nothing - independent feature
**Risk Level:** Medium (aggressive mode needs careful testing)
