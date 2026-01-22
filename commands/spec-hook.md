---
description: You MUST create this before implementing ANY new hook. Hooks without specs have undefined failure modes.
arguments:
  - name: name
    description: Name of the hook to specify
    required: true
---

# Spec Hook

Define a safety hook with explicit patterns, false positive/negative analysis, and testing strategy. Hooks are critical safety infrastructure—specify them carefully.

## Process

Guide the user through each section.

### Section 1: Purpose

> **What does this hook prevent? (one sentence)**

Be specific about the danger being caught.

### Section 2: Trigger Point

> **When does this hook run?**

- [ ] **PreToolUse** — Before Claude executes a tool
- [ ] **PostToolUse** — After Claude executes a tool
- [ ] **Notification** — On notifications
- [ ] **SessionStart** — When session begins
- [ ] Other: [specify]

> **Which tool(s) trigger this hook?**

Matcher pattern: `Bash`, `Edit|Write`, `*`, etc.

### Section 3: What This Catches

> **What dangerous patterns does this hook block?**

| Pattern | Why It's Dangerous | Example |
|---------|-------------------|---------|
| [regex or description] | [consequence if allowed] | [concrete example] |

### Section 4: What This Allows (Allowlist)

> **What similar-looking patterns are safe?**
>
> Explicit allowlist prevents false positives.

| Pattern | Why It's Safe | Example |
|---------|---------------|---------|
| [pattern] | [justification] | [concrete example] |

**Key insight:** Surgical blocking > blanket blocking. Don't block `rm -rf`; block `rm -rf /` and `rm -rf ~`.

### Section 5: Exit Codes

> **How should the hook signal its decision?**

| Code | Meaning | What Claude Sees |
|------|---------|------------------|
| `0` | Allow | Nothing (proceeds silently) |
| `1` | Error | Error message shown to user |
| `2` | Block with feedback | stderr sent TO CLAUDE as context |

**Exit code 2 is key:** It blocks AND explains why, so Claude can suggest alternatives.

### Section 6: False Positive Analysis

> **When would this block something legitimate?**

| Scenario | Mitigation |
|----------|------------|
| [legitimate use that matches dangerous pattern] | [how to handle] |

Consider:
- Development/testing scenarios
- Edge cases in naming
- Platform differences
- Intentional overrides

### Section 7: False Negative Analysis

> **When would this miss something dangerous?**

| Scenario | Accepted Risk? | Alternative Protection |
|----------|----------------|------------------------|
| [dangerous thing that bypasses pattern] | Yes/No | [other safeguard] |

Be honest about gaps. No hook catches everything.

### Section 8: Testing Strategy

> **How do we verify this hook works?**

**Positive tests (should block):**
```bash
# This SHOULD be blocked:
[command that triggers the hook]
```

**Negative tests (should allow):**
```bash
# This should be ALLOWED:
[command that looks similar but is safe]
```

### Section 9: Fail-Open vs Fail-Closed

> **If the hook itself breaks, what happens?**

- [ ] **Fail-open:** Operations continue (hook bug = security gap)
- [ ] **Fail-closed:** Operations blocked (hook bug = work blocked)

**Recommendation:** Fail-open for development, fail-closed for production deploys.

### Section 10: Senior Review Simulation

> **What would a security engineer flag?**

- **Bypass risk:** [how might someone work around this?]
- **Maintenance burden:** [will patterns need updating?]
- **Performance impact:** [is this hook expensive?]

## Output Format

For shell-based hooks:

```bash
#!/bin/bash
# Hook: [name]
# Purpose: [one sentence]
# Trigger: [PreToolUse|PostToolUse] on [matcher]

set +e  # Fail-open pattern

# Parse input
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# [Pattern checks]
if [[ "$COMMAND" =~ [dangerous_pattern] ]]; then
    # Check allowlist
    if [[ "$COMMAND" =~ [safe_exception] ]]; then
        exit 0  # Allow
    fi
    echo "Blocked: [explanation]" >&2
    echo "Suggested alternative: [alternative]" >&2
    exit 2  # Block with feedback to Claude
fi

exit 0  # Allow by default
```

For hookify (prompt-based) rules:

```yaml
# [name].local.md
---
hookify-rules:
  - name: [rule-name]
    description: [one sentence]
    match:
      tool: [Bash|Edit|Write|*]
      pattern: "[regex pattern]"
    action: [block|warn]
    message: |
      [Explanation of why this is blocked/warned]
      [Suggested alternative]
---
```

## Output Artifacts

Save to appropriate location:
- Shell hook: `~/.claude/hooks/[name].sh` (make executable)
- Hookify rule: `~/.claude/[name].local.md`
- Bootstrap toolkit: `hooks/[name].sh` or `hookify-rules/[name].local.md`

Don't forget to update `~/.claude/settings.json` to register shell hooks.

---
Specification complete. Next:
  • Run positive tests → Does it block what it should?
  • Run negative tests → Does it allow what it should?
  • Deploy → Install and register the hook
