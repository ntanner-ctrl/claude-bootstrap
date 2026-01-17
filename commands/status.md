---
description: Show current planning workflow state
arguments:
  - name: name
    description: Plan name to check (optional, shows all if omitted)
    required: false
---

# Status

Display detailed status for a specific plan or overview of all plans.

## Single Plan Status

When a plan name is provided:

```
/status feature-auth
```

Output:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PLAN STATUS: feature-auth
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Path: Full (recommended: Full)
Created: 2025-01-15 10:30
Last activity: 2 hours ago

Stages:
  ✓ 1. Describe       Completed Jan 15, 10:45
  ✓ 2. Specify        Completed Jan 15, 11:30
  → 3. Challenge      In progress (started 2h ago)
  ○ 4. Edge Cases     Pending
  ○ 5. Review         Pending (optional)
  ○ 6. Test           Pending
  ○ 7. Execute        Blocked (requires: Challenge)

Skipped stages: None

Artifacts:
  ✓ describe.md       1.2 KB
  ✓ spec.md           3.4 KB
  ○ adversarial.md    (not yet created)
  ○ tests.md          (not yet created)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Commands:
  Resume:     /plan feature-auth
  Challenge:  /devils-advocate (current stage)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Overview Status

When no plan name provided:

```
/status
```

Output:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PLANNING STATUS OVERVIEW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Active Plans: 3
Completed (last 30 days): 5
Stale (>7 days inactive): 1

In Progress:
  feature-auth     Stage 3/7 (Challenge)    2 hours ago
  bugfix-login     Stage 2/7 (Specify)      yesterday
  refactor-db      Stage 1/7 (Describe)     9 days ago ⚠️

Recently Completed:
  api-update       Complete                  3 days ago
  ui-refresh       Complete                  1 week ago

Override Patterns (last 30 days):
  2 plans downgraded full → standard
  1 plan downgraded standard → light

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Commands:
  View plan:    /status [name]
  Resume plan:  /plan [name]
  All plans:    /plans
  Overrides:    /overrides

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Stage Status Symbols

| Symbol | Meaning |
|--------|---------|
| ✓ | Completed |
| → | In progress (current) |
| ○ | Pending |
| ⊘ | Skipped |
| ⊗ | Blocked |

## Path Display

Show both recommended and chosen path:

```
Path: Standard (recommended: Full) ⚠️ downgraded
```

Or if matching:
```
Path: Full
```

## Integration

- **Reads from:** `.claude/plans/*/state.json`, `.claude/overrides.json`
- **Linked from:** `/toolkit`, `/plan` wizard
- **Leads to:** `/plan [name]`, `/overrides`
