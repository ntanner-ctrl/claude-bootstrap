# Claude Code Hook Patterns Research

Research and patterns adapted from [TheDecipherist/claude-code-mastery](https://github.com/TheDecipherist/claude-code-mastery).

Credit to that project for documenting these patterns and making their work public.

---

## 1. Dangerous Command Patterns Comparison

### Their Patterns (block-dangerous-commands.sh)

| Category | Pattern | What It Catches |
|----------|---------|-----------------|
| **Destructive rm** | `rm\s+-rf\s+/($\|[^a-zA-Z])` | rm -rf / (root) |
| | `rm\s+-rf\s+~` | rm -rf ~ (home) |
| | `rm\s+-rf\s+\.\.` | rm -rf .. (parent escape) |
| | `rm\s+-rf\s+/\*` | rm -rf /* (root wildcard) |
| | `rm\s+-rf\s+~/\*` | rm -rf ~/* (home wildcard) |
| | `rm\s+-rf\s+/home` | rm -rf /home |
| **Force push** | `git\s+push.*(-f\|--force).*\s+(main\|master\|production\|release)` | Force push to protected branches |
| **Permissions** | `chmod\s+777` | World-writable permissions |
| | `chmod\s+a\+rwx` | Alternative world-writable |
| **Remote exec** | `curl.*\|\s*(sh\|bash)` | Pipe remote script to shell |
| | `wget.*\|\s*(sh\|bash)` | Wget variant |
| **Disk ops** | `dd\s+.*of=/dev/(sd\|hd\|nvme\|disk)` | Direct disk writes |
| | `mkfs` | Any filesystem formatting |
| **Exfiltration** | `(curl\|wget\|nc\|netcat).*\.(env\|pem\|key\|secret)` | Sending sensitive files |
| **Env exposure** | `(cat\|less\|head\|tail\|more\|bat)\s+.*\.env` | Reading .env files |

### Hookify Default (dangerous-rm.local.md)

| Pattern | What It Catches |
|---------|-----------------|
| `rm\s+-rf` | Any rm -rf (broad) |

### Gap Analysis

**Their patterns are more surgical** - they block specific dangerous targets rather than blanket-blocking `rm -rf`. This matters because:
- `rm -rf node_modules` is safe and common
- `rm -rf /` is catastrophic

**Patterns hookify should add:**
1. Force push to protected branches
2. chmod 777 / world-writable
3. Curl/wget pipe to shell
4. Direct disk operations (dd, mkfs)

---

## 2. Fail-Open vs Fail-Closed Pattern

### The Pattern

```python
try:
    # Normal hook logic
    data = json.loads(sys.stdin.read())
    # ... validation ...
except json.JSONDecodeError as e:
    print(f"Hook warning: Invalid JSON - {e}", file=sys.stderr)
    sys.exit(0)  # ALLOW operation despite error
except Exception as e:
    print(f"Hook error: {e}", file=sys.stderr)
    sys.exit(0)  # ALLOW operation despite error
```

### Why Fail-Open?

| Approach | When Hook Breaks | Consequence |
|----------|------------------|-------------|
| **Fail-Closed** | All operations blocked | Work stops entirely |
| **Fail-Open** | Operations allowed | Security gap, but work continues |

**Their reasoning**: Hook bugs shouldn't block legitimate work. Security enforcement only activates when the hook is functioning correctly.

### When to Use Each

| Scenario | Approach | Why |
|----------|----------|-----|
| Development env | Fail-open | Productivity over paranoia |
| Production deploys | Fail-closed | Better to fail than deploy bad code |
| Personal projects | Fail-open | You're the only one affected |
| Shared codebases | Context-dependent | Team should decide |

### Implementation Guidance

```bash
# Fail-open pattern in bash
set +e  # Don't exit on error
# ... hook logic ...
# Only exit non-zero if EXPLICITLY blocking
```

```python
# Fail-open pattern in Python
def main():
    try:
        # Hook logic here
        if should_block:
            sys.exit(2)
        sys.exit(0)
    except Exception as e:
        print(f"Hook error (allowing operation): {e}", file=sys.stderr)
        sys.exit(0)  # Fail open
```

---

## 3. Exit Codes as Communication

### The Convention

| Code | Meaning | Claude Sees |
|------|---------|-------------|
| `0` | Allow operation | Nothing (proceeds silently) |
| `1` | User-facing error | Error message shown to user |
| `2` | Block with feedback | stderr sent TO CLAUDE as context |

### The Key Insight

**Exit code 2 is special**: It blocks the operation AND sends stderr back to Claude as feedback. This allows you to explain *why* something was blocked, so Claude can adjust.

```bash
# Example: Blocking with explanation to Claude
if [[ "$cmd" =~ chmod\ 777 ]]; then
    echo "Blocked: chmod 777 creates security vulnerability. Use specific permissions like 755." >&2
    exit 2  # Block AND send message to Claude
fi
```

Claude then knows not just that it was blocked, but *why* - and can suggest alternatives.

### Practical Usage

```bash
#!/bin/bash
# PreToolUse hook demonstrating exit codes

cmd=$(echo "$1" | jq -r '.tool_input.command // empty')

# Exit 0: Allow
if [[ -z "$cmd" ]]; then
    exit 0
fi

# Exit 2: Block with feedback to Claude
if [[ "$cmd" =~ rm\ -rf\ / ]]; then
    echo "BLOCKED: Refusing to delete root filesystem." >&2
    echo "Consider: rm -rf ./specific-directory instead" >&2
    exit 2
fi

# Exit 1: Error (rare - use for hook failures)
if ! command -v jq &> /dev/null; then
    echo "Hook error: jq not installed" >&2
    exit 1
fi

exit 0
```

---

## 4. Timeout on Quality Checks

### The Pattern

```bash
TIMEOUT=30  # seconds

run_check() {
    local name="$1"
    local cmd="$2"

    if timeout "$TIMEOUT" bash -c "$cmd" 2>/dev/null; then
        echo "✓ $name passed"
    else
        echo "✗ $name failed (non-blocking)"
    fi
    return 0  # Always return success - don't block on lint failures
}
```

### Why Timeout Matters

| Scenario | Without Timeout | With Timeout |
|----------|-----------------|--------------|
| ESLint on huge codebase | Hangs for 5+ minutes | Fails after 30s, work continues |
| TypeScript on complex types | Can hang indefinitely | Bounded execution |
| pytest with slow tests | Blocks until complete | Aborts gracefully |

### Implementation Guidance

```bash
# Timeout with graceful fallback
if timeout 30 npm run lint 2>/dev/null; then
    echo "Lint passed"
elif [[ $? -eq 124 ]]; then
    echo "Lint timed out - skipping (non-blocking)"
else
    echo "Lint failed - check manually"
fi
```

**Key insight**: The return code 124 specifically means "timeout killed the process" - you can detect and handle this case.

### Recommended Timeouts

| Check Type | Timeout | Rationale |
|------------|---------|-----------|
| Formatters (prettier, black) | 10s | Should be fast |
| Linters (eslint, ruff) | 30s | May need more time |
| Type checkers (tsc, mypy) | 60s | Complex projects need time |
| Tests | Don't use in hooks | Tests should run separately |

---

## 5. 8-Point Security Audit Framework

From their security-audit skill:

### The Checklist

| # | Category | What to Check | Tool Commands |
|---|----------|---------------|---------------|
| 1 | **Secrets Exposure** | Hardcoded creds, .gitignore, git history | `git log -p \| grep -i password`, `git secrets --scan` |
| 2 | **Dependencies** | Known vulnerabilities | `npm audit`, `pip-audit`, `cargo audit`, `govulncheck` |
| 3 | **Input Validation** | SQL injection, command injection, XSS | Manual review of user input handlers |
| 4 | **Auth & AuthZ** | Password hashing, sessions, CSRF, rate limiting | Check bcrypt/argon2, session config |
| 5 | **Transport Security** | HSTS, TLS 1.2+, secure cookies | Check headers, SSL config |
| 6 | **Error Handling** | Stack traces in prod, generic messages | Review error handlers |
| 7 | **File Uploads** | Server-side validation, size limits, malware scan | Review upload handlers |
| 8 | **API Security** | Auth required, rate limits, CORS | Review API middleware |

### Severity Classification

| Severity | Color | Response Time | Examples |
|----------|-------|---------------|----------|
| Critical | Red | Block deployment | SQL injection, hardcoded secrets in repo |
| High | Orange | Fix within 7 days | Missing rate limiting, weak password hashing |
| Medium | Yellow | Fix within 30 days | Verbose error messages, missing CSRF |
| Low | Green | Backlog | Minor config improvements |

### Integration with Your security-pro Plugin

Your existing `/security-audit` command could adopt this structured checklist format. The 8 categories ensure comprehensive coverage rather than ad-hoc checking.

---

## Summary: What to Implement

### Shell Hooks to Create

1. **notify.sh** - WSL Toast notifications (immediate value)
2. **after-edit.sh** - Auto-format on file changes
3. **secret-scanner.sh** - Scan staged files before commits

### Hookify Rules to Add

Augment the default `dangerous-rm` rule with:
- Force push to protected branches
- chmod 777
- Curl/wget pipe to shell
- Direct disk operations

### Patterns to Apply

- Fail-open in all hooks (exit 0 on errors)
- Use exit code 2 for Claude feedback
- Timeout all quality checks (30s default)

---

*Research compiled from TheDecipherist/claude-code-mastery, January 2026*
