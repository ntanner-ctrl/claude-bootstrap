---
description: Use when you need orientation on active work. Lists all in-progress blueprints with their current stage and path.
---

# Blueprints

Display all in-progress blueprints in the current project.

## Process

1. Check for `.claude/plans/` directory
2. For each subdirectory, read `state.json`
3. Auto-migrate pre-v2 plans if `blueprint_version` is missing (see `/blueprint` migration)
4. **Filter out archived blueprints** (`current_stage == "archived"`) by default — these are closed work, not active. Count them and show the count in a footer line.
5. Display summary sorted by last activity

## Flags

- `--all` — include archived blueprints in the listing (suppresses the default filter)

## Output Format

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                     ACTIVE BLUEPRINTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [name]          Stage [N]/8 ([stage name])   [mode] Last: [time ago]
  [name]          Stage [N]/8 ([stage name])   [mode] Last: [time ago]
  [name]          Complete                             Last: [time ago]
  [name]          HALTED (3/3 regressions)             Last: [time ago]
  [name]          Stage [N]/8 ([stage name])   [mode] Last: [time ago] ⚠️ stale

[N] archived (hidden) — run /blueprints --all to show

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Commands:
  Resume:     /blueprint [name]
  Start new:  /blueprint [new-name] or /describe-change
  View:       /status [name]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If the archived count is 0, omit the "[N] archived (hidden)" line entirely.

## Stale Detection

Mark blueprints as stale if no activity in 7+ days:
```
  feature-x       Stage 3/8 (Challenge)   debate  Last: 9 days ago ⚠️ stale
```

## Override Summary

If overrides exist, append:

```
Override History (last 30 days):
  [N] blueprints downgraded from recommended path
  Run /overrides for details
```

## Empty State

If no active blueprints exist (after filtering archived):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                     ACTIVE BLUEPRINTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  No active blueprints.
  [N] archived (hidden) — run /blueprints --all to show

  Start planning:
    /blueprint [name]    Full planning workflow
    /describe-change     Quick triage first

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If there are no blueprints at all (active or archived), omit the archived line.

## Integration

- **Read from:** `.claude/plans/*/state.json`
- **Linked from:** `/toolkit`, `/status`
- **Leads to:** `/blueprint [name]` to resume
