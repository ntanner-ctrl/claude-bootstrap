---
description: Use when ending a session. Closes Empirica epistemic tracking with postflight assessment and exports session artifacts to Obsidian vault before exit.
---

# End Session

Graceful session closure that preserves epistemic data and exports session artifacts to the Obsidian vault. Runs postflight self-assessment and vault export while you're still in the loop, then tells the user to `/exit`.

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

### Step 2.5: Vault Export

Export session artifacts to the Obsidian vault. This step is Claude-executed (using Read/Write/Bash tools), not a shell script.

#### 2.5.1: Source Vault Config

Use the Bash tool to source vault-config.sh and extract config values:

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo "VAULT_ENABLED=$VAULT_ENABLED" && echo "VAULT_PATH=$VAULT_PATH" && echo "VAULT_EXPORT_MARKER=$VAULT_EXPORT_MARKER"
```

This evaluates the `$(id -u)` and `$(date +%Y%m%d)` subshells at runtime. Do NOT read vault-config.sh as text.

If `VAULT_ENABLED=0` or vault path is empty/missing/unwritable, skip with note: "Vault export skipped (vault disabled or not accessible)." and continue to Step 3.

#### 2.5.2: Ensure Vault Structure

```bash
mkdir -p "$VAULT_PATH/Engineering/Decisions" "$VAULT_PATH/Engineering/Findings" "$VAULT_PATH/Engineering/Blueprints" "$VAULT_PATH/Engineering/Patterns" "$VAULT_PATH/Sessions" "$VAULT_PATH/Ideas"
```

#### 2.5.3: Collect Session Artifacts

Scope artifacts to "this session" using the session-start timestamp:

1. Read session-start timestamp: `cat /tmp/.claude-session-start-$(id -u)` (ISO-8601).
   **Fallback:** If absent or empty, use `$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)`. Log: "Session-start timestamp missing — scoping artifacts to last 24 hours."
2. Read `.empirica/active_session` for session ID. Fallback: `session-YYYY-MM-DD-HHMM`.
3. **Decision records:** Read `.claude/decisions/*.md` files. Each has `date:` frontmatter in ISO-8601. Include where `date:` >= session-start timestamp.
4. **Empirica findings:** Read `.empirica/insights.jsonl`. Each line has `timestamp` field in ISO-8601. Include where `timestamp` >= session-start timestamp.
5. Check for active blueprint progress (`.claude/plans/*/state.json` with `updated` after session start).
6. Check `Ideas/` in vault for notes with `date:` matching today (these are `/vault-save` captures).

#### 2.5.4: Create Vault Notes

For each artifact, create a vault note using templates from `~/.claude/commands/templates/vault-notes/`. Read the template, replace all `{{key}}` placeholders with corresponding values. For conditional directives like `{{#if key}}...{{/if}}`, include the block only if the key has a value — otherwise omit the entire line. If a placeholder has no value, use sensible defaults (category: "insight", severity: "info"). **All filenames via vault_sanitize_slug()** (Bash: `echo "TITLE" | tr -cd '[:alnum:] ._-' | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | head -c 80`):

- Decisions → `Engineering/Decisions/YYYY-MM-DD-slug.md`
- Findings → `Engineering/Findings/YYYY-MM-DD-slug.md`
- Blueprint updates → `Engineering/Blueprints/YYYY-MM-DD-blueprint-name.md` (overwrite/snapshot semantics)
- Session summary → `Sessions/YYYY-MM-DD-HHMM-project-summary.md`

**Wiki-link rules:** Links ONLY between notes created in this export batch. Session summary links to decisions/findings. Decisions/findings link back to session. No speculative links.

**Session summary content:**
- Summary: 2-3 sentence overview (Claude-generated from conversation)
- Work Completed: Derived from artifact evidence (decisions, findings, blueprints, vault-saves) — NOT git diff
- Decisions Made: Wiki-links to decision notes in this batch
- Findings: Wiki-links to finding notes in this batch
- Blueprint Progress: Current stage/status if active
- Open Questions: Anything flagged unresolved

#### 2.5.5: Write Export Marker

```bash
touch "$VAULT_EXPORT_MARKER"
```

This tells the SessionEnd safety-net hook that export already happened.

#### 2.5.6: Present Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VAULT EXPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Exported to vault:
    [list of files written]

  Total: N notes (N new, N updated)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

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
  Vault:     [N notes exported / skipped (reason)]

  Type /exit to end the conversation.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Notes

- This command does NOT automatically exit — the user must type `/exit` after
- If no Empirica session is active, the command still works (just shows the exit prompt)
- The SessionEnd hook (`session-end-empirica.sh`) acts as a safety net for cases where `/end` wasn't used
- The SessionEnd hook (`session-end-vault.sh`) acts as a safety net for vault export when `/end` wasn't used
- Vault export uses templates from `~/.claude/commands/templates/vault-notes/`
- Pair with `/checkpoint` if you also want to save decision context for future sessions
