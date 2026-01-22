---
description: You MUST run this after ANY implementation changes. Detects test framework and runs full suite to catch regressions.
allowed-tools:
  - Bash
  - Read
  - Glob
---

# Test Runner

Run all tests for this project with automatic framework detection.

## Arguments

Parse `$ARGUMENTS` for:
- `--coverage` or `-c`: Include coverage reporting
- `--fast` or `-f`: Skip slow tests (uses framework-specific markers)
- `--verbose` or `-v`: Verbose output
- `[pattern]`: Run only tests matching pattern

## Detection & Execution

### Step 1: Detect Test Framework

Check for these indicators in order:

| Indicator | Framework | Command |
|-----------|-----------|---------|
| `pytest.ini`, `pyproject.toml [tool.pytest]`, `conftest.py` | pytest | `pytest` |
| `setup.py` with test requirements | pytest/unittest | `python -m pytest` |
| `package.json` with `jest` | Jest | `npm test` |
| `package.json` with `vitest` | Vitest | `npm test` |
| `package.json` with `mocha` | Mocha | `npm test` |
| `Cargo.toml` | Cargo | `cargo test` |
| `go.mod` | Go | `go test ./...` |
| `mix.exs` | ExUnit | `mix test` |
| `Gemfile` with `rspec` | RSpec | `bundle exec rspec` |

### Step 2: Locate Test Directories

Standard locations to check:
- `tests/`, `test/`, `__tests__/`
- `spec/` (Ruby/JavaScript)
- `*_test.py`, `test_*.py` (Python)
- `*.test.ts`, `*.spec.ts` (TypeScript)
- `*_test.go` (Go)

### Step 3: Prepare Environment

**Python:**
```bash
# Activate virtual environment if present
if [ -d ".venv" ]; then
    source .venv/bin/activate
elif [ -d "venv" ]; then
    source venv/bin/activate
fi
```

**Node:**
```bash
# Ensure dependencies installed
if [ ! -d "node_modules" ]; then
    npm install
fi
```

### Step 4: Build Test Command

**Python (pytest):**
```bash
cmd="pytest"
[ "$verbose" = true ] && cmd="$cmd -v"
[ "$coverage" = true ] && cmd="$cmd --cov=. --cov-report=html"
[ "$fast" = true ] && cmd="$cmd -m 'not slow'"
[ -n "$pattern" ] && cmd="$cmd -k '$pattern'"
```

**Node (Jest/Vitest):**
```bash
cmd="npm test"
[ "$coverage" = true ] && cmd="$cmd -- --coverage"
[ -n "$pattern" ] && cmd="$cmd -- --testNamePattern='$pattern'"
```

**Rust:**
```bash
cmd="cargo test"
[ -n "$pattern" ] && cmd="$cmd $pattern"
```

**Go:**
```bash
cmd="go test ./..."
[ "$verbose" = true ] && cmd="$cmd -v"
[ "$coverage" = true ] && cmd="$cmd -coverprofile=coverage.out"
[ -n "$pattern" ] && cmd="$cmd -run '$pattern'"
```

### Step 5: Execute and Report

Run the command and capture results. Report:
- Total tests run
- Passed / Failed / Skipped counts
- Duration
- Coverage percentage (if enabled)
- Failed test details

## Output Format

```
## Test Results

**Framework:** pytest
**Duration:** 12.3s

### Summary
✓ 45 passed
✗ 2 failed
○ 3 skipped

### Failed Tests

1. `test_user_auth.py::test_login_invalid_password`
   AssertionError: Expected 401, got 500

2. `test_api.py::test_rate_limiting`
   TimeoutError: Test exceeded 5s limit

### Coverage (if --coverage)
- Overall: 78%
- Uncovered files:
  - src/utils/legacy.py (0%)
  - src/services/deprecated.py (23%)
```

## Customization

When this command is installed in a project, you can customize it:

1. **Add project-specific test directories:**
   ```bash
   # Add to detection
   TEST_DIRS="tests/ integration_tests/ e2e/"
   ```

2. **Add pre-test setup:**
   ```bash
   # Database migrations, fixtures, etc.
   ./scripts/setup-test-db.sh
   ```

3. **Add post-test cleanup:**
   ```bash
   # Clean up test artifacts
   rm -rf .test-cache/
   ```

4. **Configure CI-specific behavior:**
   ```bash
   if [ "$CI" = "true" ]; then
       # Use CI-friendly output
       cmd="$cmd --ci"
   fi
   ```

---

$ARGUMENTS
