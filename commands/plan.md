---
description: You MUST use this for ANY non-trivial implementation task. Skipping planning leads to confident mistakes that cost more to fix than to prevent.
arguments:
  - name: name
    description: Name for this plan (required for new plans, optional to resume)
    required: false
---

# Plan

Guided planning workflow that walks through all stages. Use this for full planning discipline, or when you want the toolkit to guide you through the right steps.

## Overview

```
Stage 1: Describe    → /describe-change (triage)
Stage 2: Specify     → /spec-change (full specification)
Stage 3: Challenge   → /devils-advocate (assumption check)
Stage 4: Edge Cases  → /edge-cases (boundary probing)
Stage 5: Review      → /gpt-review (external perspective) [optional]
Stage 6: Test        → /spec-to-tests (spec-blind tests)
Stage 7: Execute     → Implementation
```

## Process

### Starting or Resuming

**New plan:**
```
/plan feature-auth
```

Creates `.claude/plans/feature-auth/` and starts at Stage 1.

**Resume existing:**
```
/plan feature-auth
```

If plan exists, shows current stage and resumes.

**List all plans:**
```
/plans
```

### Stage Navigation

Present the current stage header:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PLANNING: [name] │ Stage [N] of 7: [Stage Name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Stages:
  ✓ 1. Describe     [completed timestamp]
  ✓ 2. Specify      [completed timestamp]
  → 3. Challenge    ← You are here
  ○ 4. Edge Cases
  ○ 5. Review (optional)
  ○ 6. Test
  ○ 7. Execute

Commands:
  'next'     Advance to next stage (requires current stage complete)
  'back'     Return to previous stage
  'skip'     Skip current stage (requires reason)
  'status'   Show progress
  'exit'     Exit wizard (progress saved)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Stage Execution

Each stage invokes its corresponding command:

| Stage | Command | Can Skip? | Auto-skipped When |
|-------|---------|-----------|-------------------|
| 1. Describe | `/describe-change` | No | Never |
| 2. Specify | `/spec-change` | Yes | Light path |
| 3. Challenge | `/devils-advocate` | Yes | Light/Standard path |
| 4. Edge Cases | `/edge-cases` | Yes | Light/Standard path |
| 5. Review | `/gpt-review` | Yes | Always optional |
| 6. Test | `/spec-to-tests` | Yes | Light path |
| 7. Execute | Exit wizard | No | Never |

### Path-Based Stage Selection

After Stage 1 (Describe), the triage result determines the path:

**Light Path:** 1 → 7 (describe → execute)
- Stages 2-6 auto-skipped
- Quick preflight recommended but not required

**Standard Path:** 1 → 2 → 7 (describe → specify → execute)
- Stages 3-6 optional
- Preflight recommended

**Full Path:** 1 → 2 → 3 → 4 → 5 → 6 → 7 (all stages)
- Stage 5 (Review) always optional
- Other stages recommended

### Skip Handling

When user requests skip:

```
You're about to skip Stage [N]: [name]

This stage normally catches:
  - [what this stage finds]

Are you sure? Provide a reason for the skip:
> [user reason]

Skip recorded. Proceeding to Stage [N+1].
```

Skips are logged in `state.json` and visible in `/overrides`.

### State Persistence

On any action, update `.claude/plans/[name]/state.json`:

```json
{
  "name": "[name]",
  "created": "2025-01-15T10:30:00Z",
  "updated": "2025-01-16T14:22:00Z",
  "recommended_path": "full",
  "chosen_path": "full",
  "current_stage": 3,
  "stages": {
    "describe": { "status": "complete", "completed": "2025-01-15T10:45:00Z" },
    "specify": { "status": "complete", "completed": "2025-01-15T11:30:00Z" },
    "challenge": { "status": "in_progress", "started": "2025-01-16T14:00:00Z" },
    "edge_cases": { "status": "pending" },
    "review": { "status": "pending", "skippable": true },
    "test": { "status": "pending" },
    "execute": { "status": "blocked" }
  },
  "skipped": [],
  "notes": ""
}
```

### Completion

When Stage 7 (Execute) is reached:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PLANNING: [name] │ Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Planning complete! Summary:

  Path: [Light/Standard/Full]
  Stages completed: [N]/7
  Skipped: [list or "None"]

  Artifacts:
  - .claude/plans/[name]/describe.md
  - .claude/plans/[name]/spec.md
  - .claude/plans/[name]/adversarial.md
  - .claude/plans/[name]/tests.md

Ready to implement. Artifacts saved for reference.

  Implementation options:
    [1] Standard implementation (manual, using plan artifacts as reference)
    [2] TDD-enforced → /tdd --plan-context [name] (pre-populates SPEC from criteria)
    [3] Subagent-dispatched → /delegate --plan .claude/plans/[name]/spec.md --plan-context [name] --review

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Output Artifacts

All artifacts saved to `.claude/plans/[name]/`:
- `state.json` — Progress tracking
- `describe.md` — Triage output
- `spec.md` — Full specification
- `adversarial.md` — Challenge findings (appended by each adversarial command)
- `preflight.md` — Pre-flight checklist
- `tests.md` — Generated test specs

## Integration

- **Wraps:** All planning commands
- **Tracked in:** `.claude/plans/[name]/`
- **Listed by:** `/plans`
- **Status checked by:** `/status`
