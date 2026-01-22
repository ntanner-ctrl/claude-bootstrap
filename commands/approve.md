---
description: Use to advance a planning stage after review. Marks current stage complete and unlocks the next stage.
arguments:
  - name: plan
    description: Plan name to approve current stage
    required: true
  - name: notes
    description: Optional notes about the approval
    required: false
---

# Approve

Explicitly approve a planning stage to advance to the next. Used in the staged planning protocol to enforce gates between stages.

## Purpose

Creates explicit checkpoints in the planning process:
- Forces acknowledgment that a stage is complete
- Records approval timestamp and any notes
- Enables "proceed despite concerns" with documentation
- Prevents accidental advancement

## Process

### Step 1: Identify Current Stage

Load plan state and show current position:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  APPROVE: [plan name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Current stage: [N]. [Stage Name]
Status: [in_progress / complete]

Stage output:
  [summary of what was produced in this stage]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 2: Approval Options

```
Approval options:

  [1] Approve - stage is complete, advance to next
  [2] Approve with concerns - proceed but note issues
  [3] Not ready - stay at current stage

>
```

#### Option 1: Clean Approval

```
✓ Stage [N] approved.

Advancing to Stage [N+1]: [Next Stage Name]

Next command: /[next-stage-command]
```

Update `state.json`:
```json
{
  "stages": {
    "[current]": {
      "status": "complete",
      "completed": "[timestamp]",
      "approved_by": "user",
      "concerns": null
    }
  },
  "current_stage": [N+1]
}
```

#### Option 2: Approve with Concerns

```
What concerns are you proceeding despite?
> [user input]

⚠️ Stage [N] approved with noted concerns:
   "[concerns]"

This is recorded for retrospective review.

Advancing to Stage [N+1]: [Next Stage Name]
```

Update `state.json`:
```json
{
  "stages": {
    "[current]": {
      "status": "complete",
      "completed": "[timestamp]",
      "approved_by": "user",
      "concerns": "[noted concerns]"
    }
  }
}
```

#### Option 3: Not Ready

```
Stage [N] remains in progress.

What needs to happen before approval?
> [user input]

Noted. Run /[current-stage-command] to continue work,
then /approve [plan] when ready.
```

### Step 3: Update State

Write approval to `state.json` and any artifacts.

## Approval Log

All approvals are logged in the plan state:

```json
{
  "approval_log": [
    {
      "stage": "specify",
      "timestamp": "2025-01-15T11:30:00Z",
      "concerns": null
    },
    {
      "stage": "challenge",
      "timestamp": "2025-01-15T14:00:00Z",
      "concerns": "Didn't challenge API availability - out of scope"
    }
  ]
}
```

## Output Format

```markdown
# Approval: [plan] - Stage [N]

**Stage:** [stage name]
**Status:** Approved [/ Approved with concerns]
**Timestamp:** [datetime]
**Concerns:** [none / listed concerns]

**Next stage:** [N+1]. [next stage name]
**Next command:** /[command]
```

## Integration

- **Updates:** `.claude/plans/[name]/state.json`
- **Used by:** `/plan` wizard (internally)
- **Standalone use:** For explicit gate control outside wizard
- **Feeds into:** `/status`, approval log
