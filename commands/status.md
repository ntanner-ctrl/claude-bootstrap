---
description: Use when resuming work or checking progress on a blueprint. Shows current stage, completed work, and next steps.
arguments:
  - name: name
    description: Blueprint name to check (optional, shows all if omitted)
    required: false
---

# Status

Display detailed status for a specific blueprint or overview of all blueprints.

## Single Blueprint Status

When a blueprint name is provided:

```
/status feature-auth
```

Output:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BLUEPRINT STATUS: feature-auth
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
  Resume:     /blueprint feature-auth
  Challenge:  /devils-advocate (current stage)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Overview Status

When no blueprint name provided:

```
/status
```

Output:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BLUEPRINT STATUS OVERVIEW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Active Blueprints: 3
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
  2 blueprints downgraded full → standard
  1 blueprint downgraded standard → light

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Commands:
  View blueprint:    /status [name]
  Resume blueprint:  /blueprint [name]
  All blueprints:    /blueprints
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

Show both recommended and chosen path for a blueprint:

```
Path: Standard (recommended: Full) ⚠️ downgraded
```

Or if matching:
```
Path: Full
```

## Integration

- **Reads from:** `.claude/plans/*/state.json`, `.claude/overrides.json`
- **Linked from:** `/toolkit`, `/blueprint` wizard
- **Leads to:** `/blueprint [name]`, `/overrides`
