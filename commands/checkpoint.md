---
description: Use before ending a session or when context is getting large. Saves decision rationale for future sessions.
arguments:
  - name: summary
    description: Brief summary of current state (prompted if not provided)
    required: false
---

# Checkpoint

Manual context-save for decision continuity across sessions. Captures what you're doing, why, and what comes next — so future sessions can resume without re-deriving context.

## When to Use

- Before ending a long session
- When context window is getting large (compaction risk)
- After making a non-obvious decision (save the rationale)
- Before switching to a different task
- When you'd be upset if this context was lost

## Process

### Step 1: Gather Context

If no `--summary` provided, ask:
1. "What are you currently working on?"
2. "What key decisions were made (and why)?"
3. "What's the next action?"

### Step 2: Determine Location

```bash
# If active plan exists, checkpoint goes with the plan
if [ -f ".claude/state-index.json" ]; then
    plan=$(jq -r '.active_plan // empty' .claude/state-index.json)
    if [ -n "$plan" ]; then
        # Plan-scoped checkpoint
        mkdir -p ".claude/plans/${plan}/checkpoints"
        DEST=".claude/plans/${plan}/checkpoints/$(date -u +%Y%m%dT%H%M%SZ).json"
    fi
fi

# Otherwise, global checkpoint
if [ -z "${DEST:-}" ]; then
    mkdir -p ".claude/checkpoints"
    DEST=".claude/checkpoints/$(date -u +%Y%m%dT%H%M%SZ).json"
fi
```

### Step 3: Write Checkpoint

Create JSON:
```json
{
  "timestamp": "ISO-8601",
  "summary": "Working on X because Y",
  "decisions": [
    "Chose A over B because [rationale]",
    "Deferred C until [condition]"
  ],
  "next_action": "What to do next when resuming",
  "blockers": [],
  "context": {
    "active_plan": "[name or null]",
    "active_plan_stage": "[N or null]",
    "active_tdd_phase": "[phase or null]",
    "files_in_progress": ["file1.ts", "file2.ts"]
  }
}
```

### Step 4: Confirm

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CHECKPOINT SAVED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Location: [path]
  Summary:  [summary]
  Decisions: [N] recorded
  Next:     [next_action]

  This context will be surfaced on next session start.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 5: Update State Index

If state-index.json exists, update `last_checkpoint`:

```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.last_checkpoint = $ts' .claude/state-index.json > tmp.$$ && mv tmp.$$ .claude/state-index.json
```

## Reading Checkpoints

On session resume, the session-bootstrap hook reads the latest checkpoint and surfaces it. Checkpoints can also be read manually:

```bash
# Latest checkpoint for active plan
cat .claude/plans/[name]/checkpoints/*.json | jq -s 'sort_by(.timestamp) | last'

# Latest global checkpoint
cat .claude/checkpoints/*.json | jq -s 'sort_by(.timestamp) | last'
```

## Notes

- Checkpoints are append-only (never modified, only new ones created)
- Old checkpoints are NOT deleted (they're cheap and provide history)
- The session-bootstrap hook only shows the LATEST checkpoint
- Pair with `/dashboard` to see full active state
