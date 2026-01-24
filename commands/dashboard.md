---
description: Use when resuming work or checking progress across all active workflows.
arguments: []
---

# Dashboard

Aggregated view of all active work. Reads state-index, plan state, and TDD state to show a unified picture.

## Process

### Step 1: Read State

Check for active state sources:

```bash
# State index (maintained by hook)
cat .claude/state-index.json 2>/dev/null

# Active plans (fallback if no state-index)
ls .claude/plans/*/state.json 2>/dev/null

# Active TDD session
cat .claude/tdd-sessions/active.json 2>/dev/null

# Recent checkpoints
ls -t .claude/plans/*/checkpoints/*.json .claude/checkpoints/*.json 2>/dev/null | head -3
```

### Step 2: Compute Status

For each active item, determine:
- **Plan**: name, current stage, time since last update
- **TDD**: target, current phase, mode
- **Checkpoint**: timestamp, relative time ("20 min ago")
- **Delegate**: whether delegation is in progress

### Step 3: Display

**When active work exists:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DASHBOARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Active:
  Plan: [name]  Stage [N]/7  [time] ago
  TDD:  [target]  [PHASE]    [status]

Context:
  Last checkpoint: [relative time]

Tips:
  /status [name]   Detail on specific plan
  /checkpoint      Save current context
  /plans           List all plans
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**When no active work:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DASHBOARD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  No active work detected.

  Recent plans:
    [name]  Stage 7/7  completed [date]
    [name]  Stage 4/7  paused [date]

  Start something:
    /plan [name]     New planning workflow
    /tdd [target]    TDD session
    /describe-change Triage a change
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**When delegation is active:**

Add to active section:
```
  Delegate: [N] agents running
    Task 1: [description] (in progress)
    Task 2: [description] (complete)
```

### Step 4: Suggestions

Based on state, suggest next action:

| State | Suggestion |
|-------|------------|
| Plan at stage 7 | "Ready to implement. Use /delegate --plan or /tdd" |
| TDD in RED phase | "Write failing tests for [target]" |
| TDD in GREEN phase | "Implement minimal code to pass tests" |
| No checkpoint in 1h+ | "Consider /checkpoint to save context" |
| Multiple stale plans | "Consider closing stale plans" |

## Notes

- This command does NOT modify any state — read-only
- Designed for quick glance, not detailed inspection (use /status for that)
- Works without state-index.json (falls back to scanning .claude/)
