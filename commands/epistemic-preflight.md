---
description: Submit preflight epistemic vectors at session start. Use after seeing the calibration context from the SessionStart hook.
---

# Epistemic Preflight

Capture your preflight self-assessment vectors and store them in `~/.claude/epistemic.json`.

## Instructions

### Step 1: Read Session Context

```bash
cat ~/.claude/.current-session 2>/dev/null || echo "NO_SESSION"
```

If no session marker exists, create one:
```bash
mkdir -p ~/.claude
SESSION_ID="session-$(date +%Y%m%d-%H%M%S)-$$"
PROJECT=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || basename "$(pwd)")
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf "SESSION_ID=%s\nPROJECT=%s\nSTARTED=%s\n" "$SESSION_ID" "$PROJECT" "$NOW" > ~/.claude/.current-session
```

### Step 2: Self-Assess

Rate each of these 13 vectors from 0.0 to 1.0 based on your CURRENT epistemic state:

| Vector | What to assess |
|--------|---------------|
| `engagement` | How aligned are you with this task? |
| `know` | How much do you know about the domain/codebase? |
| `do` | How confident are you in your ability to execute? |
| `context` | How well do you understand the surrounding context? |
| `clarity` | How clear are the requirements/goals? |
| `coherence` | How well does your approach hold together? |
| `signal` | How relevant is the available information? |
| `density` | How information-dense do you expect this work to be? |
| `state` | How well do you understand the current system state? |
| `change` | How much change do you expect to produce? |
| `completion` | How much progress do you expect to make? |
| `impact` | How impactful do you expect this work to be? |
| `uncertainty` | How much uncertainty remains? |

### Step 3: Store Vectors

Write vectors to `epistemic.json`. Use the Bash tool:

```bash
#!/usr/bin/env bash
set +e

EPISTEMIC_FILE="${HOME}/.claude/epistemic.json"
EPISTEMIC_TMP="${EPISTEMIC_FILE}.tmp"
SESSION_FILE="${HOME}/.claude/.current-session"

# Read session context
SESSION_ID=$(grep "^SESSION_ID=" "$SESSION_FILE" 2>/dev/null | cut -d= -f2)
PROJECT=$(grep "^PROJECT=" "$SESSION_FILE" 2>/dev/null | cut -d= -f2)
STARTED=$(grep "^STARTED=" "$SESSION_FILE" 2>/dev/null | cut -d= -f2)

if [ -z "$SESSION_ID" ]; then
    echo "ERROR: No session ID found. Run SessionStart hook first." >&2
    exit 1
fi

# Initialize if needed
if [ ! -s "$EPISTEMIC_FILE" ]; then
    if [ -f "$(git rev-parse --show-toplevel 2>/dev/null)/scripts/epistemic-init.sh" ]; then
        bash "$(git rev-parse --show-toplevel 2>/dev/null)/scripts/epistemic-init.sh"
    elif [ -f "${HOME}/.claude/scripts/epistemic-init.sh" ]; then
        bash "${HOME}/.claude/scripts/epistemic-init.sh"
    else
        echo "ERROR: epistemic.json not found and init script unavailable" >&2
        exit 1
    fi
fi

# VECTORS — replace these values with your actual self-assessment
ENGAGEMENT={{engagement}}
KNOW={{know}}
DO={{do}}
CONTEXT={{context}}
CLARITY={{clarity}}
COHERENCE={{coherence}}
SIGNAL={{signal}}
DENSITY={{density}}
STATE={{state}}
CHANGE={{change}}
COMPLETION={{completion}}
IMPACT={{impact}}
UNCERTAINTY={{uncertainty}}

# Upsert session entry (overwrites if already exists — handles double submission)
jq --arg id "$SESSION_ID" \
   --arg project "$PROJECT" \
   --arg ts "$STARTED" \
   --argjson eng "$ENGAGEMENT" \
   --argjson kno "$KNOW" \
   --argjson do_ "$DO" \
   --argjson ctx "$CONTEXT" \
   --argjson cla "$CLARITY" \
   --argjson coh "$COHERENCE" \
   --argjson sig "$SIGNAL" \
   --argjson den "$DENSITY" \
   --argjson sta "$STATE" \
   --argjson chg "$CHANGE" \
   --argjson com "$COMPLETION" \
   --argjson imp "$IMPACT" \
   --argjson unc "$UNCERTAINTY" \
   '
   # Remove existing entry for this session (handles double submission)
   .sessions = [.sessions[] | select(.id != $id)] |
   # Add new entry
   .sessions += [{
     id: $id,
     project: $project,
     timestamp: $ts,
     preflight: {
       engagement: $eng, know: $kno, do: $do_, context: $ctx,
       clarity: $cla, coherence: $coh, signal: $sig, density: $den,
       state: $sta, change: $chg, completion: $com, impact: $imp,
       uncertainty: $unc
     },
     postflight: null,
     deltas: null,
     task_summary: "",
     paired: false
   }] |
   .last_updated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
   ' "$EPISTEMIC_FILE" > "$EPISTEMIC_TMP" && mv "$EPISTEMIC_TMP" "$EPISTEMIC_FILE"

if [ $? -eq 0 ]; then
    echo "Preflight vectors recorded for session ${SESSION_ID} (project: ${PROJECT})."
else
    echo "ERROR: Failed to write preflight vectors" >&2
    exit 1
fi
```

Replace `{{vector}}` placeholders with your actual 0.0-1.0 scores before running.

### Step 4: Confirm

Report: "Preflight vectors recorded for session {SESSION_ID}."

Store the session ID for use throughout this conversation — you'll need it for postflight.
