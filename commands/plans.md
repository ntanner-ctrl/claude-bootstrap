---
description: Use when you need orientation on active work. Lists all in-progress plans with their current stage and path.
---

# Plans

Display all in-progress plans in the current project.

## Process

1. Check for `.claude/plans/` directory
2. For each subdirectory, read `state.json`
3. Display summary sorted by last activity

## Output Format

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                     IN-PROGRESS PLANS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [name]          Stage [N]/7 ([stage name])   Last: [time ago]
  [name]          Stage [N]/7 ([stage name])   Last: [time ago]
  [name]          Complete                      Last: [time ago]
  [name]          Stage [N]/7 ([stage name])   Last: [time ago] ⚠️ stale

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Commands:
  Resume a plan:    /plan [name]
  Start new:        /plan [new-name] or /describe-change
  View details:     /status [name]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Stale Detection

Mark plans as stale if no activity in 7+ days:
```
  feature-x       Stage 3/7 (Challenge)   Last: 9 days ago ⚠️ stale
```

## Override Summary

If overrides exist, append:

```
Override History (last 30 days):
  [N] plans downgraded from recommended path
  Run /overrides for details
```

## Empty State

If no plans exist:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                     IN-PROGRESS PLANS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  No active plans.

  Start planning:
    /plan [name]         Full planning workflow
    /describe-change     Quick triage first

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Filtering (Future)

Could add filters:
```
/plans --stale        # Only stale plans
/plans --active       # Only non-stale
/plans --complete     # Completed plans
```

## Integration

- **Read from:** `.claude/plans/*/state.json`
- **Linked from:** `/toolkit`, `/status`
- **Leads to:** `/plan [name]` to resume
