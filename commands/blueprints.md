---
description: Use when you need orientation on active work. Lists all in-progress blueprints with their current stage and path.
---

# Blueprints

Display all in-progress blueprints in the current project.

## Process

1. Check for `.claude/plans/` directory
2. For each subdirectory, read `state.json`
3. Auto-migrate pre-v2 plans if `blueprint_version` is missing (see `/blueprint` migration)
4. Display summary sorted by last activity

## Output Format

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                     ACTIVE BLUEPRINTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [name]          Stage [N]/7 ([stage name])   [mode] Last: [time ago]
  [name]          Stage [N]/7 ([stage name])   [mode] Last: [time ago]
  [name]          Complete                             Last: [time ago]
  [name]          HALTED (3/3 regressions)             Last: [time ago]
  [name]          Stage [N]/7 ([stage name])   [mode] Last: [time ago] ⚠️ stale

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Commands:
  Resume:     /blueprint [name]
  Start new:  /blueprint [new-name] or /describe-change
  View:       /status [name]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Stale Detection

Mark blueprints as stale if no activity in 7+ days:
```
  feature-x       Stage 3/7 (Challenge)   debate  Last: 9 days ago ⚠️ stale
```

## Override Summary

If overrides exist, append:

```
Override History (last 30 days):
  [N] blueprints downgraded from recommended path
  Run /overrides for details
```

## Empty State

If no blueprints exist:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                     ACTIVE BLUEPRINTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  No active blueprints.

  Start planning:
    /blueprint [name]    Full planning workflow
    /describe-change     Quick triage first

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Integration

- **Read from:** `.claude/plans/*/state.json`
- **Linked from:** `/toolkit`, `/status`
- **Leads to:** `/blueprint [name]` to resume
