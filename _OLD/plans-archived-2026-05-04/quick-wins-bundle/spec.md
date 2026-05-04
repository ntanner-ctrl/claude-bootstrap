# Quick Wins Bundle: Priorities 1, 5, 6, 7

## Overview

Four lower-complexity improvements that can be implemented in a single session:

| Priority | Name | Effort | Impact |
|----------|------|--------|--------|
| P1 | Bootstrap Mechanism | Low | **High** |
| P5 | Two-Stage Review | Medium | Medium |
| P6 | Quality Gate | Low | Medium |
| P7 | Protect CLAUDE.md Hook | Low | Low |

**Total Estimated Time:** 4-5 hours
**Can be done in:** 1 session

---

## Priority 1: Bootstrap Mechanism

### The Idea
Inject a small prompt at session start that teaches Claude it has commands and MUST use them.

### Implementation

**Create: `hooks/session-bootstrap.sh`**
```bash
#!/bin/bash
# session-bootstrap.sh - SessionStart hook

cat << 'EOF'
<EXTREMELY_IMPORTANT>
You have Superpowers in this project via claude-bootstrap.

IMMEDIATELY, list available commands:
  ls ~/.claude/commands/*.md | head -20

If a command exists for what you're about to do, you MUST use it.
Not "should." Not "consider." MUST.

Key commands to know:
  /describe-change  → Triage ANY task first
  /plan             → Full planning workflow
  /spec-change      → Detailed specification
  /push-safe        → REQUIRED before git push

BEFORE writing ANY implementation code:
  1. Check if a planning command applies
  2. Check if a test command applies
  3. Announce which commands you're using
</EXTREMELY_IMPORTANT>
EOF
```

**Add to settings.json:**
```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "~/.claude/hooks/session-bootstrap.sh"
      }
    ]
  }
}
```

### Success Criteria
- New sessions see bootstrap message
- Claude proactively searches for commands
- Command usage increases measurably

### Files Changed
| File | Change |
|------|--------|
| New: `hooks/session-bootstrap.sh` | Add |
| `settings-example.json` | Modify - add SessionStart hook |

---

## Priority 5: Two-Stage Review (Spec)

### The Idea
Split code review into spec compliance (did you build what was planned?) and code quality (is it built well?).

### Implementation

**Create: `agents/spec-reviewer.md`**
```markdown
---
name: spec-reviewer
description: Use after implementation to verify code matches specification
---

# Spec Compliance Reviewer

You are a SPEC COMPLIANCE REVIEWER. Your ONLY job is to verify
implementation matches specification.

## You DO NOT care about:
- Code quality or style
- Performance optimization
- Best practices
- Elegance

## You ONLY care about:
- Does code implement the spec? Exactly?
- Are ALL acceptance criteria met?
- Is anything MISSING from spec?
- Is anything ADDED that wasn't in spec?

## Process
1. Read the specification
2. Read the implementation
3. Line-by-line comparison
4. Report discrepancies

## Output Format
```
SPEC COMPLIANCE REVIEW
======================

Specification: [source]
Implementation: [files]

Criteria Check:
  ✓ [criterion] — implemented in [location]
  ✗ [criterion] — NOT FOUND
  ⚠ [extra] — implemented but NOT IN SPEC

Verdict: PASS | FAIL
Discrepancies: [list if FAIL]
```
```

**Create: `agents/quality-reviewer.md`**
```markdown
---
name: quality-reviewer
description: Use after spec compliance passes to review code quality
---

# Code Quality Reviewer

You are a CODE QUALITY REVIEWER. Implementation has already passed
spec compliance. Your concerns are different.

## You DO NOT care about:
- Whether it matches a spec (already verified)
- Feature completeness (already verified)

## You ONLY care about:
- Is code readable and maintainable?
- Are there bugs or edge case issues?
- Does it follow project conventions?
- Are there security concerns?
- Is error handling adequate?
- Is there unnecessary complexity?

## Output Format
```
CODE QUALITY REVIEW
===================

Files Reviewed: [list]

Issues Found:
  🔴 CRITICAL: [issue] — [location]
  🟡 WARNING: [issue] — [location]
  🔵 SUGGESTION: [issue] — [location]

Verdict: PASS | FAIL
Blocking Issues: [list if FAIL]
```
```

**Modify: `commands/delegate.md`** (or create review wrapper)
Add optional flag `--two-stage-review` that routes through both reviewers.

### Success Criteria
- Two separate review agents exist
- Review can be run in sequence
- Spec drift and quality issues caught separately

### Files Changed
| File | Change |
|------|--------|
| New: `agents/spec-reviewer.md` | Add |
| New: `agents/quality-reviewer.md` | Add |
| `commands/delegate.md` | Modify - add review options |

---

## Priority 6: Quality Gate

### The Idea
Add a scoring rubric that blocks progression below a threshold.

### Implementation

**Create: `commands/quality-gate.md`**
```markdown
---
description: You MUST pass this before completing ANY significant implementation
arguments:
  - name: threshold
    description: Minimum score to pass (default 85)
    required: false
---

# Quality Gate

Score implementation against rubric. Blocks completion below threshold.

## Rubric (100 points)

| Category | Points | Criteria |
|----------|--------|----------|
| **Functionality** | 25 | All acceptance criteria met |
| **Tests** | 20 | Tests exist, pass, cover edge cases |
| **Security** | 20 | No obvious vulnerabilities, input validated |
| **Code Quality** | 15 | Readable, follows conventions |
| **Documentation** | 10 | Comments where needed, README updated |
| **Performance** | 10 | No obvious bottlenecks |

## Process

1. **Collect Evidence**
   For each category, gather:
   - What was implemented
   - What tests exist
   - Security considerations addressed

2. **Score**
   Rate each category honestly.

3. **Gate**
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     QUALITY GATE
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   Score: [X]/100
   Threshold: [Y]

   Breakdown:
     Functionality:  [25]/25  ████████████████████████████
     Tests:          [15]/20  ████████████████████░░░░░░░░
     Security:       [20]/20  ████████████████████████████
     Code Quality:   [12]/15  ████████████████████████░░░░
     Documentation:  [5]/10   ██████████████░░░░░░░░░░░░░░
     Performance:    [8]/10   ████████████████████████░░░░

   Status: [PASS ✓ | BLOCKED ✗]

   [If blocked]
   Must address:
     - Tests: Missing edge case coverage (+5 needed)
     - Documentation: README not updated (+5 needed)

   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

## Integration

- Run automatically at end of `/plan` execute stage
- Can be invoked manually anytime
- Blocks PR creation if below threshold
```

### Success Criteria
- Gate command exists and scores correctly
- Below-threshold work is blocked
- Integration with /plan workflow

### Files Changed
| File | Change |
|------|--------|
| New: `commands/quality-gate.md` | Add |
| `commands/plan.md` | Modify - add gate to execute stage |

---

## Priority 7: Protect CLAUDE.md Hook

### The Idea
Prevent accidental modification of CLAUDE.md files that contain critical project instructions.

### Implementation

**Create: `hooks/protect-claude-md.sh`**
```bash
#!/bin/bash
# protect-claude-md.sh - PreToolUse hook for Edit/Write

# Get the file being edited (passed as argument or via env)
FILE_PATH="${1:-$CLAUDE_TOOL_ARG_FILE_PATH}"

# Check if it's a CLAUDE.md file
if [[ "$FILE_PATH" == *"CLAUDE.md"* ]] || [[ "$FILE_PATH" == *"claude.md"* ]]; then
  echo "⚠️  PROTECTED FILE DETECTED"
  echo ""
  echo "You are about to modify: $FILE_PATH"
  echo ""
  echo "CLAUDE.md files contain critical project instructions."
  echo "Modifications should be intentional, not accidental."
  echo ""
  echo "If this is intentional, the user should explicitly approve."
  echo ""
  echo "Reason for modification required:"

  # Return code 2 = ask user for confirmation
  exit 2
fi

exit 0
```

**Add to settings.json:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/protect-claude-md.sh"
          }
        ]
      }
    ]
  }
}
```

### Success Criteria
- Edits to CLAUDE.md trigger confirmation
- User can still modify if intentional
- Accidental modifications prevented

### Files Changed
| File | Change |
|------|--------|
| New: `hooks/protect-claude-md.sh` | Add |
| `settings-example.json` | Modify - add to PreToolUse |

---

## Combined Implementation Plan

### Order of Implementation

```
1. Bootstrap Mechanism (P1)     [45 min]
   └── Most impactful, enables others

2. Protect CLAUDE.md (P7)       [30 min]
   └── Simple, quick win

3. Quality Gate (P6)            [1 hour]
   └── Self-contained command

4. Two-Stage Review (P5)        [1.5 hours]
   └── Most complex in this bundle
```

### Checklist

- [ ] Create `hooks/session-bootstrap.sh`
- [ ] Create `hooks/protect-claude-md.sh`
- [ ] Create `commands/quality-gate.md`
- [ ] Create `agents/spec-reviewer.md`
- [ ] Create `agents/quality-reviewer.md`
- [ ] Update `settings-example.json`
- [ ] Update `commands/plan.md` for gate integration
- [ ] Test all hooks work
- [ ] Test quality gate scoring
- [ ] Test two-stage review flow

---

## Success Criteria (Bundle)

| Item | Verification |
|------|--------------|
| Bootstrap shows at session start | New session shows EXTREMELY_IMPORTANT block |
| CLAUDE.md is protected | Try to edit → confirmation required |
| Quality gate blocks | Score <85 → blocked status |
| Two reviewers work | Run both, get different feedback |

---

## Rollback

All additions are:
- New files (delete to rollback)
- Settings changes (revert JSON)

No breaking changes to existing functionality.
