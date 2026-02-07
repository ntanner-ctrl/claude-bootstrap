---
description: Use when ending a session. Closes Empirica epistemic tracking with postflight assessment before exit.
---

# End Session

Graceful session closure that preserves epistemic data. Runs postflight self-assessment while you're still in the loop, then tells the user to `/exit`.

## Why This Exists

Without explicit closure, Empirica sessions become epistemically orphaned — the record gets closed (via SessionEnd hook) but no learning delta is captured. This command ensures the postflight self-assessment happens while you can still reflect on what you learned.

## Process

### Step 1: Check for Active Empirica Session

```bash
# Read active session from project-scoped pointer
ACTIVE_SESSION_FILE=".empirica/active_session"
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -n "$GIT_ROOT" ] && [ -f "$GIT_ROOT/$ACTIVE_SESSION_FILE" ]; then
    SESSION_ID=$(cat "$GIT_ROOT/$ACTIVE_SESSION_FILE")
elif [ -f "$ACTIVE_SESSION_FILE" ]; then
    SESSION_ID=$(cat "$ACTIVE_SESSION_FILE")
fi
```

If no active session is found, skip to Step 4 (just show the exit message).

### Step 2: Run Postflight Assessment

Call `mcp__empirica__execute_postflight` with:
- `session_id`: The active session ID from Step 1
- `task_summary`: A 2-3 sentence summary of ALL work completed this session (not just the last task)

Then call `mcp__empirica__submit_postflight_assessment` with honest self-assessment vectors for your CURRENT epistemic state. Rate each of the 13 vectors (0.0-1.0) based on where you are NOW:

| Vector | What to assess |
|--------|---------------|
| `engagement` | How deeply did you engage with the task? |
| `know` | How much do you now know about the domain? |
| `do` | How much practical ability did you gain? |
| `context` | How well do you understand the project context? |
| `clarity` | How clear is your understanding? |
| `coherence` | How well does everything fit together? |
| `signal` | How strong was the signal-to-noise ratio? |
| `density` | How information-dense was the work? |
| `state` | How well do you know the current state of things? |
| `change` | How much changed from your initial understanding? |
| `completion` | How complete is the work? |
| `impact` | How impactful was the session? |
| `uncertainty` | How much uncertainty remains? |

**Be honest.** The value of postflight is in the delta between preflight and postflight. Inflated scores corrupt the calibration data.

### Step 3: Log Key Findings (if any)

If you learned something significant during this session that wasn't already logged, call `mcp__empirica__finding_log` now. This is your last chance to capture it.

### Step 4: Confirm and Prompt Exit

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SESSION CLOSED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Empirica:  [session_id or "no active session"]
  Postflight: [completed / skipped]
  Findings:   [N logged this session]

  Type /exit to end the conversation.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Notes

- This command does NOT automatically exit — the user must type `/exit` after
- If no Empirica session is active, the command still works (just shows the exit prompt)
- The SessionEnd hook (`session-end-empirica.sh`) acts as a safety net for cases where `/end` wasn't used
- Pair with `/checkpoint` if you also want to save decision context for future sessions
