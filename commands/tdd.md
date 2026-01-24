---
description: You MUST use this when writing new functionality that needs tests. Enforces RED-GREEN-REFACTOR — tests before implementation, always.
arguments:
  - name: target
    description: File or module path to develop with TDD
    required: false
  - name: mode
    description: "Enforcement level: advisory (default), strict, or aggressive"
    required: false
  - name: plan-context
    description: "Plan name to pre-populate SPEC from (--plan-context feature-auth)"
    required: false
---

# TDD Enforcement

Enforce true RED-GREEN-REFACTOR discipline. Tests MUST exist and fail before implementation proceeds.

## Modes

| Mode | Behavior |
|------|----------|
| **advisory** (default) | Warns on violations, logs but doesn't block |
| **strict** | Blocks implementation until tests exist and fail |
| **aggressive** | Blocks + deletes implementation written before tests |

## Workflow

### Phase 0: Session Setup

1. Parse arguments:
   - `target`: file/module path (ask if not provided)
   - `mode`: advisory/strict/aggressive (default: advisory)

2. Detect test framework:
   ```bash
   # Check for test runners
   ls package.json pyproject.toml Cargo.toml go.mod *.csproj 2>/dev/null
   ```
   - Node: jest, vitest, mocha (check package.json)
   - Python: pytest, unittest (check pyproject.toml/setup.cfg)
   - Go: built-in `go test`
   - Rust: built-in `cargo test`
   - Other: ask user for test command

3. Determine test file path:
   - Convention: `[target].test.[ext]` or `[target].spec.[ext]`
   - Or `tests/[target].[ext]` or `__tests__/[target].[ext]`
   - Ask user to confirm

4. Create session state:
   ```bash
   mkdir -p .claude/tdd-sessions
   ```
   Write `.claude/tdd-sessions/active.json`:
   ```json
   {
     "id": "[generated-uuid]",
     "started": "[ISO-8601]",
     "mode": "[mode]",
     "phase": "spec",
     "target": "[target-path]",
     "test_file": "[test-file-path]",
     "test_command": "[detected-or-provided]",
     "spec": null,
     "checkpoints": {}
   }
   ```

5. Display session header:
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     TDD SESSION │ Mode: [mode] │ Target: [target]
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

     ○ SPEC     Define what behavior to implement
     ○ RED      Write tests that FAIL
     ○ GREEN    Write minimal implementation to PASS
     ○ REFACTOR Clean up (tests must stay green)
     ○ VERIFY   Confirm coverage and quality

   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

---

### Phase 1: SPEC

**Goal:** Define behavior and acceptance criteria BEFORE writing any code.

**If `--plan-context [name]` provided:**
1. Read `.claude/plans/[name]/spec.md` for acceptance criteria
2. Read `.claude/plans/[name]/tests.md` for test assertions (if exists)
3. Pre-populate the spec from plan artifacts:
   ```
   Pre-populated from plan: [name]
   BEHAVIOR: [extracted from spec.md]
   CRITERIA:
     1. [criterion from spec acceptance criteria]
     2. [criterion]

   Confirm these criteria or modify:
   ```
4. User confirms or edits, then proceed to RED phase

**If no `--plan-context`:**
1. Ask user to describe the behavior:
   - "What should this code DO?" (behavior, not implementation)
   - "What are the acceptance criteria?"

2. Produce spec summary:
   ```
   BEHAVIOR: [what it does]
   CRITERIA:
     1. [criterion — testable assertion]
     2. [criterion — testable assertion]
     3. [criterion — testable assertion]
   ```

3. Save to session state (update `spec` field)

4. Update phase to `red` in active.json

5. Display transition:
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     ✓ SPEC     [summary]
     → RED      Write tests that FAIL ← You are here
     ○ GREEN
     ○ REFACTOR
     ○ VERIFY
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   RULES FOR RED PHASE:
     • Write tests for EACH criterion above
     • Tests MUST fail (proving they test real behavior)
     • Do NOT write implementation yet
     • Do NOT write tests that pass trivially
   ```

---

### Phase 2: RED (Write Failing Tests)

**Goal:** Write tests that fail, proving they would catch bugs.

1. Guide test creation:
   - One test per acceptance criterion
   - Tests should assert behavior, not implementation details
   - Tests should fail for the RIGHT reason (not syntax errors)

2. After tests are written, RUN them:
   ```bash
   [test_command]
   ```

3. Validate RED:
   - **All tests FAIL** → Correct. Proceed.
   - **Some tests PASS** → Problem. Either:
     - Implementation already exists (check target file)
     - Test is tautological (assert true === true)
     - Test doesn't test what it claims
   - **Tests error** (syntax/import) → Fix errors first. Errors ≠ failures.

4. Anti-tautology check:
   - Does the test assert something that could be wrong?
   - Would a trivially wrong implementation pass?
   - Would deleting the function body cause the test to fail?

5. If RED is valid:
   - Record checkpoint: `checkpoints.tests_fail = [timestamp]`
   - Update phase to `green`
   - Display transition:
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     ✓ SPEC
     ✓ RED      [N] tests failing as expected
     → GREEN    Write minimal implementation ← You are here
     ○ REFACTOR
     ○ VERIFY
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   RULES FOR GREEN PHASE:
     • Write ONLY enough code to make tests pass
     • No extra features, no premature optimization
     • If tests pass, STOP writing implementation
   ```

---

### Phase 3: GREEN (Minimal Implementation)

**Goal:** Write the minimum code to make tests pass.

1. Unlock implementation file (phase is now `green`)

2. Remind:
   - "Write ONLY enough to pass the tests"
   - "No extra features"
   - "No optimization"
   - "Simple and correct > clever"

3. After implementation, RUN tests:
   ```bash
   [test_command]
   ```

4. Validate GREEN:
   - **All tests PASS** → Correct. Proceed.
   - **Some tests FAIL** → Iterate implementation. DO NOT modify tests.
   - **New tests PASS that weren't failing** → Suspicious. Check if implementation is over-engineered.

5. If GREEN is valid:
   - Record checkpoint: `checkpoints.tests_pass = [timestamp]`
   - Update phase to `refactor`

---

### Phase 4: REFACTOR (Optional)

**Goal:** Improve code quality without changing behavior.

1. Display refactoring options:
   ```
   Now you may refactor. Rules:
     • Tests MUST pass after every change
     • Don't add new behavior (that needs new RED phase)
     • Focus: readability, naming, structure
     • Run tests after EACH refactoring step
   ```

2. After each refactoring change, RUN tests:
   ```bash
   [test_command]
   ```
   - **Pass** → Continue refactoring or move to verify
   - **Fail** → UNDO last refactoring change. Tests are the truth.

3. When done (user says "done" or no more changes):
   - Update phase to `verify`

---

### Phase 5: VERIFY

**Goal:** Confirm tests are high-quality and cover the spec.

Run these checks:

1. **Coverage check:** Each acceptance criterion has a corresponding test
2. **Behavior focus:** Tests assert outcomes, not implementation details
3. **Independence:** Tests don't depend on each other's state
4. **Determinism:** Tests produce same result every run (no time/random dependencies)
5. **Anti-tautology:** Would a wrong implementation pass any test?

Display final report:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TDD SESSION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Target: [target]
  Mode: [mode]
  Duration: [time]

  Phases:
    ✓ SPEC      [N] acceptance criteria
    ✓ RED       [N] tests written, all failed correctly
    ✓ GREEN     All tests passing
    ✓ REFACTOR  [N] improvements made
    ✓ VERIFY    Quality checks passed

  Violations: [N] (advisory only)
  Files:
    Test:  [test_file]
    Impl:  [target]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Clean up: remove `.claude/tdd-sessions/active.json` (archive to `.claude/tdd-sessions/[id].json`)

**If `--plan-context [name]` was used**, update `.claude/plans/[name]/state.json`:
```json
{
  "execution": {
    "method": "tdd",
    "phase": "complete",
    "test_file": "[test_file]",
    "target": "[target]",
    "criteria_met": N,
    "timestamp": "ISO-8601"
  }
}
```

---

## Enforcement by Mode

### Advisory Mode

When violations are detected (impl before tests):
```
⚠️  TDD ADVISORY: Implementation detected before tests.
    File: [path]
    Recommendation: Write tests first, then implement.
    This violation has been logged.
```
Log to session state but DO NOT block.

### Strict Mode

When violations are detected:
```
🚫 TDD VIOLATION: Cannot write implementation during RED phase.
   File: [path]
   Phase: RED (tests must fail first)

   To proceed:
     1. Write tests in [test_file]
     2. Run tests to confirm they fail
     3. Then implementation is unlocked
```
Block the edit (exit code 2 from hook).

### Aggressive Mode

When violations are detected:
```
⚠️  AGGRESSIVE TDD VIOLATION
    Implementation found: [path]
    No corresponding tests: [test_file]

    Options:
      [1] Delete implementation, restart from RED (recommended)
      [2] Abort TDD session, keep implementation
      [3] Downgrade to advisory mode

    Choose:
```

If user chooses 1:
- Back up to `.claude/tdd-sessions/[id]/backup/`
- Delete or revert the implementation file
- Reset phase to `red`

---

## Session Management

### Resume
If active session exists when `/tdd` is invoked:
```
Active TDD session found:
  Target: [target]
  Phase: [phase]
  Started: [time]

  [1] Resume this session
  [2] Abort and start new
```

### Abort
To manually end a TDD session:
```
/tdd --abort
```
Archives session state with `aborted: true`.

### Status
Check current TDD state inline:
```
/tdd --status
```

---

## Test Framework Detection

| Indicator | Framework | Test Command |
|-----------|-----------|--------------|
| `jest` in package.json | Jest | `npx jest [file]` |
| `vitest` in package.json | Vitest | `npx vitest run [file]` |
| `mocha` in package.json | Mocha | `npx mocha [file]` |
| `pytest` importable | Pytest | `pytest [file]` |
| `go.mod` exists | Go test | `go test ./[pkg]` |
| `Cargo.toml` exists | Cargo test | `cargo test` |
| `.csproj` exists | dotnet test | `dotnet test` |

If undetected, ask user for test command.
