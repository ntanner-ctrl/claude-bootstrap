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

### Step 1.5: Reconcile Orphaned Insights

Reconcile insights that exist on disk but not in vault, or vice versa. This closes the gap between the write-through cache and the vault.

1. **Read insights.jsonl**: Read `.empirica/insights.jsonl` from the project root. If the file doesn't exist or is empty, skip this step.

2. **Read vault findings**: List files in `$VAULT_PATH/Engineering/Findings/` that match this project (check `project:` frontmatter). Source vault config first:
   ```bash
   source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo "VAULT_PATH=$VAULT_PATH"
   ```
   If vault is not accessible, skip vault-side reconciliation but still report disk-only insights.

3. **Match entries**: For each insights.jsonl entry, check if a corresponding vault note exists by matching:
   - Finding text similarity (the `finding` field in insights.jsonl vs the note body)
   - Timestamp proximity (same calendar day)

4. **Reconcile disk → vault**: For insights.jsonl entries with NO matching vault note:
   - Create a vault note using the finding template (`~/.claude/commands/templates/vault-notes/finding.md`)
   - Populate Empirica fields: `empirica_confidence: 0.5` (default — not yet assessed), `empirica_assessed: today`, `empirica_session: SESSION_ID`, `empirica_status: active`
   - Use vault_sanitize_slug for the filename

5. **Reconcile vault → Empirica**: For vault finding notes (created this session via `/vault-save`) with NO matching insights.jsonl entry:
   - Call `mcp__empirica__finding_log` with the finding text and category from the vault note

6. **Report**:
   ```
   Reconciled N orphaned insights (M→vault, K→Empirica)
   ```
   If nothing to reconcile, report: "No orphaned insights found."

**Fail-soft**: If any reconciliation step fails, log the error and continue. Never block session closure.

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

### Step 2.75: Confidence Writeback

After postflight vectors are submitted, write Empirica confidence data back to vault findings. This closes the loop between epistemic self-assessment and persistent knowledge.

1. **Gather session findings**: Collect all findings logged this session from `.empirica/insights.jsonl` (filtered by session-start timestamp, same as Step 2.5.3).

2. **Update new findings**: For each finding that was exported to vault THIS session (created in Step 1.5 or Step 2.5.4):
   - Read the vault note
   - Update frontmatter with:
     ```yaml
     empirica_confidence: <confidence from postflight — use the `know` vector as proxy>
     empirica_assessed: <today's date YYYY-MM-DD>
     empirica_session: <SESSION_ID>
     empirica_status: active
     ```
   - Write the updated note back using the Edit tool

3. **Update confirmed findings**: For existing vault findings (pre-session) that were referenced or used successfully this session:
   - Update frontmatter: `empirica_status: confirmed`, `empirica_assessed: <today>`
   - This indicates the finding was re-validated in practice

4. **Update contradicted findings**: For existing vault findings that were found to be wrong or outdated this session:
   - Update frontmatter: `empirica_status: contradicted`, `empirica_assessed: <today>`
   - Add a note in the Implications section: `> Contradicted in session [[SESSION_LINK]] — [brief reason]`

5. **Report**:
   ```
   Confidence writeback: N findings updated (M active, K confirmed, J contradicted)
   ```

**Fail-soft**: If vault is inaccessible or frontmatter parsing fails, skip writeback with note and continue.

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

#### 2.5.6: Detect Stale Findings

After export, scan vault findings for staleness. A finding is stale if its `empirica_assessed` date is more than 30 days old.

1. **Scan vault findings**: Read all files in `$VAULT_PATH/Engineering/Findings/` that have `project:` matching the current project.

2. **Check freshness**: For each finding with an `empirica_assessed` frontmatter field:
   - Parse the date (YYYY-MM-DD format)
   - If >30 days old, mark as stale

3. **Update stale findings**: For each stale finding:
   - Update frontmatter: `empirica_status: stale`
   - Do NOT change `empirica_assessed` (preserve the last-assessed date for audit trail)

4. **Report stale findings** in the session summary:
   ```
   Stale findings (>30 days since last verification):
     - [[finding-name-1]] (last assessed: YYYY-MM-DD)
     - [[finding-name-2]] (last assessed: YYYY-MM-DD)
   ```
   If no stale findings, omit this section.

**Fail-soft**: If vault scanning fails, skip with note and continue to summary.

#### 2.5.7: Present Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VAULT EXPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Exported to vault:
    [list of files written]

  Total: N notes (N new, N updated)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 3: Collect Remaining Insights

This is your last chance to capture session knowledge. Do NOT skip this step.

1. **Scan conversation for unlogged `★ Insight` blocks**: Search your own output in this session for any `★ Insight` blocks. For each one, check if a corresponding `finding_log` call followed it (look for a finding_log tool call within ~2 messages after the insight).

2. **For each unlogged insight**: Call `mcp__empirica__finding_log` with `category: "insight"` and the insight text. This is the safety net for the behavioral gap where insights get generated as text but never recorded.

3. **Final reflection**: Beyond `★ Insight` blocks, did you learn something significant that wasn't captured anywhere? If so, log it now.

4. **Report**:
   ```
   Insight sweep: N ★ Insight blocks found, M already logged, K newly captured
   ```

**Why this matters**: Soft instructions to "log insights as you go" have a ~50% compliance rate in practice. This step catches the other 50% before the session closes and the knowledge is lost.

### Step 4: Confirm and Prompt Exit

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SESSION CLOSED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Empirica:     [session_id or "no active session"]
  Postflight:   [completed / skipped]
  Reconciled:   [N orphaned insights (M→vault, K→Empirica) / skipped]
  Confidence:   [N findings updated / skipped]
  Insights:     [N ★ blocks found, M already logged, K swept / skipped]
  Findings:     [N logged this session (total)]
  Vault:        [N notes exported / skipped (reason)]
  Stale:        [N findings need re-verification / none]

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
