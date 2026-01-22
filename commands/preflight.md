---
description: STOP. You MUST complete this before ANY production operation, deployment, or irreversible action. Skipping has caused incidents.
arguments:
  - name: operation
    description: What operation are you about to perform
    required: false
---

# Preflight

Quick safety check before executing. Forces explicit acknowledgment of assumptions, blast radius, and reversibility.

## Process

### Section 1: Assumptions Inventory

> **What are you assuming to be true?**

| Assumption | Confidence (High/Med/Low) | If Wrong, Impact |
|------------|---------------------------|------------------|
| [assumption] | [confidence] | [consequence] |

> **What don't you know?**

| Unknown | Does It Block Progress? | How to Resolve |
|---------|-------------------------|----------------|
| [unknown] | Yes/No | [resolution path] |

**Flag any Low-confidence assumptions or blocking unknowns.**

### Section 2: Blast Radius Assessment

> **If this goes wrong, what's affected?**

- **Immediate:** [direct impact]
- **Secondary:** [ripple effects]
- **Worst case:** [maximum damage scenario]

> **Recovery time estimate:** [time to fix if wrong]

> **Is this reversible?**
> - [ ] Fully reversible (can undo completely)
> - [ ] Partially reversible (some state loss)
> - [ ] Irreversible (point of no return)

**Flag irreversible operations for extra scrutiny.**

### Section 3: Dependency Check

> **This requires (preconditions):**
> - [ ] [precondition]

> **This will break if (fragile assumptions):**
> - [ ] [fragile assumption]

### Section 4: The 3 AM Test

> **Would you be comfortable if this ran at 3 AM while you were asleep?**
>
> - [ ] **Yes** — Fully specified, understood, recoverable
> - [ ] **No** — Because: [reason]

If "No", this is a strong signal to add more specification or safeguards.

### Section 5: Go/No-Go Decision

Present the summary:

```markdown
## Pre-Flight Summary: [operation]

### Assumptions
| Assumption | Confidence | If Wrong |
|------------|------------|----------|
| ... | ... | ... |

### Unknowns
| Unknown | Blocking? | Resolution |
|---------|-----------|------------|
| ... | ... | ... |

### Blast Radius
- Immediate: [impact]
- Secondary: [impact]
- Worst case: [impact]
- Recovery time: [estimate]
- Reversibility: [Full/Partial/Irreversible]

### Dependencies
- Requires: [list]
- Breaks if: [list]

### 3 AM Test: [Pass/Fail]
[reason if fail]

---

## Decision

- [ ] **GO** — Proceed with execution
- [ ] **NO-GO** — Resolve: [specific blocker]

---
Pre-flight complete.
  • All checks passed → proceed with implementation
  • Concerns flagged → address before proceeding
  • Want tests first → /spec-to-tests
```

## Severity Indicators

Use these to highlight concerns:

- **GREEN (GO):** No blocking unknowns, high confidence, fully reversible
- **YELLOW (CAUTION):** Some medium-confidence assumptions, partially reversible
- **RED (STOP):** Low confidence, irreversible, or fails 3 AM test

## Quick Mode

For Light-path changes, an abbreviated preflight:

```markdown
## Quick Preflight: [operation]

**Main assumption:** [the big one]
**If wrong:** [consequence]
**Reversible:** Yes/No
**3 AM Test:** Pass/Fail

→ [GO/NO-GO]
```

## Output Artifacts

If tracking:
- Append to `.claude/plans/[name]/preflight.md`
- Update state if part of workflow

## Integration

- **Fed by:** `/describe-change` (Light path), `/spec-change` (Standard/Full path)
- **Feeds into:** Implementation or `/spec-to-tests`
- **Can invoke independently** for quick safety checks
