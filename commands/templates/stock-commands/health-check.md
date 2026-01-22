---
description: Use at session start or when something seems broken. Validates project config, deps, and build before investigating further.
allowed-tools:
  - Bash
  - Read
  - Glob
---

# Project Health Check

Validate that the project is properly configured and ready for development.

## Arguments

Parse `$ARGUMENTS` for:
- `--verbose` or `-v`: Show detailed output for each check
- `--fix`: Attempt to fix issues automatically where possible
- `--skip <check>`: Skip specific checks (deps, config, build, git)

## Health Checks

Perform the following checks in order:

### 1. Dependencies Check

**What to verify:**
- All dependencies are installed
- No missing peer dependencies
- No critical vulnerabilities (optional)

**Python:**
```bash
# Check if requirements are satisfied
pip check

# Check for outdated critical packages
pip list --outdated --format=json | jq '.[] | select(.name | test("security|auth|crypto"))'
```

**Node:**
```bash
# Check for missing dependencies
npm ls --all 2>&1 | grep -E "MISSING|ERR!"

# Security audit (optional)
npm audit --audit-level=high
```

**Rust:**
```bash
cargo check
```

**Go:**
```bash
go mod verify
```

**Status:** PASS if all dependencies satisfied, WARN if outdated, FAIL if missing

### 2. Configuration Check

**What to verify:**
- Required config files exist
- Environment variables are documented
- No obvious misconfigurations

**Checks to perform:**
```bash
# Check for required files
required_files=(".env.example" "README.md")
for file in "${required_files[@]}"; do
    [ -f "$file" ] || echo "Missing: $file"
done

# Check if .env exists when .env.example exists
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    echo "WARN: .env.example exists but .env is missing"
fi

# Validate JSON/YAML configs
for config in $(find . -name "*.json" -path "./config/*"); do
    jq . "$config" > /dev/null 2>&1 || echo "Invalid JSON: $config"
done
```

**Status:** PASS if all configs valid, WARN if optional missing, FAIL if required missing/invalid

### 3. Build Check

**What to verify:**
- Project compiles/builds successfully
- No type errors (for typed languages)
- Linting passes (optional)

**Python:**
```bash
# Type checking
mypy . --ignore-missing-imports 2>&1 | tail -5

# Syntax check
python -m py_compile $(find . -name "*.py" -not -path "./.venv/*" | head -10)
```

**TypeScript:**
```bash
# Type checking
npx tsc --noEmit

# Lint check
npx eslint . --max-warnings 0
```

**Rust:**
```bash
cargo build
cargo clippy -- -D warnings
```

**Go:**
```bash
go build ./...
go vet ./...
```

**Status:** PASS if builds clean, WARN if warnings, FAIL if errors

### 4. Git Check

**What to verify:**
- On expected branch
- Working tree is clean (or has expected changes)
- Remote is configured and accessible

**Checks:**
```bash
# Current branch
branch=$(git branch --show-current)

# Check for uncommitted changes
if ! git diff --quiet; then
    echo "Uncommitted changes present"
fi

# Check remote
git fetch --dry-run 2>&1 | head -3
```

**Status:** PASS if clean and synced, WARN if uncommitted changes, FAIL if remote issues

### 5. Runtime Check (Optional)

**What to verify:**
- Required services are running (database, cache, etc.)
- Required ports are available
- Required tools are installed

**Checks:**
```bash
# Check if required ports are available
for port in 3000 5432 6379; do
    nc -z localhost $port 2>/dev/null && echo "Port $port: IN USE" || echo "Port $port: available"
done

# Check for required tools
for tool in docker docker-compose aws; do
    command -v $tool > /dev/null 2>&1 || echo "Missing tool: $tool"
done
```

## Output Format

```
## Project Health Check

### Dependencies: [PASS/WARN/FAIL]
✓ All 47 dependencies installed
✓ No missing peer dependencies
⚠ 3 packages have updates available

### Configuration: [PASS/WARN/FAIL]
✓ Required config files present
✓ .env configured
⚠ Missing optional: docker-compose.override.yml

### Build: [PASS/WARN/FAIL]
✓ TypeScript compilation successful
✓ No type errors
⚠ 2 ESLint warnings (non-blocking)

### Git: [PASS/WARN/FAIL]
✓ On branch: main
✓ Working tree clean
✓ Remote: origin (up to date)

---

## Summary

**Overall: 3/4 checks passed**

### Issues to Address
1. [WARN] 3 packages have security updates
2. [WARN] 2 ESLint warnings in src/utils.ts

### Quick Fixes
- Run `npm update` to update dependencies
- Run `npm run lint:fix` to auto-fix lint issues
```

## Customization

When installed in a project, customize by:

1. **Add project-specific checks:**
   ```bash
   # Check database migrations
   ./scripts/check-migrations.sh

   # Check for required env vars
   required_vars=("DATABASE_URL" "API_KEY" "SECRET")
   for var in "${required_vars[@]}"; do
       [ -z "${!var}" ] && echo "Missing: $var"
   done
   ```

2. **Add service health checks:**
   ```bash
   # Ping database
   pg_isready -h localhost -p 5432

   # Check Redis
   redis-cli ping
   ```

3. **Configure severity levels:**
   - What's a FAIL vs WARN for your project
   - Which checks are mandatory vs optional

---

$ARGUMENTS
