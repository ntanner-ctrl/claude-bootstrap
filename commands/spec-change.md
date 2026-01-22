---
description: You MUST create this for ANY change touching >3 files OR involving risk flags. No implementation without spec.
arguments:
  - name: name
    description: Name of the change (for tracking)
    required: false
---

# Spec Change

Create a comprehensive specification that forces completeness before implementation begins. The standard is: **"Could a script follow this?"**

## Process

Guide the user through each section, gathering information interactively.

### Section 1: Summary

> **Summarize this change in one sentence.**

### Section 2: What Changes

#### Files/Components Touched

> **What files or components will this touch?**

Build a table:

| File/Component | Nature of Change |
|----------------|------------------|
| [path]         | [add/modify/delete/rename] |

#### External Dependencies

> **Does this affect external dependencies?**
> - [ ] None
> - [ ] New dependencies: [list]
> - [ ] Updated dependencies: [list]
> - [ ] Removed dependencies: [list]

#### Database/State Changes

> **Does this involve database or persistent state changes?**
> - [ ] None
> - [ ] Schema changes: [describe]
> - [ ] Data migrations: [describe]
> - [ ] State format changes: [describe]

### Section 3: Preservation Contract

**This section is often forgotten but critical.**

> **What must NOT change?**
>
> Even when we change things, some behaviors must survive.

- **Behavior that must survive:** [list invariants]
- **Interfaces that must remain stable:** [list APIs, contracts]
- **Performance bounds that must hold:** [list constraints]

### Section 4: Success Criteria

> **How will we know this worked?**
>
> Must be testable. "It works" is not a criterion.

| Criterion | How to Verify |
|-----------|---------------|
| [observable outcome] | [specific test/check] |

### Section 5: Failure Modes

> **What could go wrong, and how would we know?**

| What Could Fail | Detection Method | Recovery Action |
|-----------------|------------------|-----------------|
| [failure scenario] | [how to detect] | [what to do] |

### Section 6: Rollback Plan

> **If this needs to be reverted, what's the plan?**

1. [step]
2. [step]
3. [step]

Consider:
- Can we revert the code change alone?
- Are there database migrations to reverse?
- Is there state cleanup needed?
- Who needs to be notified?

### Section 7: Dependencies (Preconditions)

> **What must be true before starting?**

- [ ] [precondition]
- [ ] [precondition]

### Section 8: Open Questions

> **What's still unclear?**
>
> Don't bury uncertainty. Surface it here.

- [question]
- [question]

### Section 9: Senior Review Simulation

> **What would someone with 10 more years of experience flag?**

- **They'd probably ask about:** [concern]
- **The non-obvious risk is:** [risk]
- **The "standard approach" I might be missing:** [approach]
- **What bites first-timers here:** [gotcha]

## Output Format

Compile all gathered information into this template:

```markdown
# Change Specification: [title]

## Summary
[one sentence]

## What Changes

### Files/Components Touched
| File | Nature of Change |
|------|------------------|
| ... | ... |

### External Dependencies
[checklist results]

### Database/State Changes
[checklist results]

## Preservation Contract (What Must NOT Change)
- Behavior that must survive: [list]
- Interfaces that must remain stable: [list]
- Performance bounds that must hold: [list]

## Success Criteria
| Criterion | How to Verify |
|-----------|---------------|
| ... | ... |

## Failure Modes
| What Could Fail | Detection Method | Recovery Action |
|-----------------|------------------|-----------------|
| ... | ... | ... |

## Rollback Plan
1. ...
2. ...

## Dependencies (Preconditions)
- [ ] ...

## Open Questions
- ...

## Senior Review Simulation
- They'd ask about: ...
- Non-obvious risk: ...
- Standard approach I might be missing: ...
- What bites first-timers: ...

---
Specification complete. Next steps:
  • Quick safety check → /preflight
  • Challenge assumptions → /devils-advocate
  • Probe boundaries → /edge-cases
  • Generate tests → /spec-to-tests
  • Ready to build → proceed or /delegate
```

## Output Artifacts

If tracking:
- Save to `.claude/plans/[name]/spec.md`
- Update `.claude/plans/[name]/state.json` stage to "specify: complete"

## Integration

- **Fed by:** `/describe-change` (determines if spec is needed)
- **Feeds into:** `/preflight`, `/devils-advocate`, `/edge-cases`, `/spec-to-tests`
