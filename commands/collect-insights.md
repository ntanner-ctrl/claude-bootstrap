---
description: Use when you want to flush pending insights to Obsidian vault and Empirica. Captures ★ Insight blocks and orphaned disk findings.
---

# Collect Insights

Flush pending insights to both the Obsidian vault and Empirica. Reads orphaned disk findings from `.empirica/insights.jsonl`, captures any ★ Insight blocks from the current conversation, and dual-writes each to vault (as finding notes) and Empirica (as logged findings).

## Why This Exists

Insights accumulate in two places during a session: in-conversation ★ Insight blocks (ephemeral) and `.empirica/insights.jsonl` (disk safety net from the PostToolUse hook). Without explicit collection, these remain fragmented — vault has no record, and Empirica may have partial data. This command reconciles both stores.

## Process

### Step 1: Source Vault Config

Use the Bash tool to source vault-config.sh and extract config values:

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo "VAULT_ENABLED=$VAULT_ENABLED" && echo "VAULT_PATH=$VAULT_PATH"
```

Note the result. If vault is unavailable, continue anyway — Empirica writes can still proceed (fail-soft).

### Step 2: Check for Active Empirica Session

```bash
ACTIVE_SESSION_FILE=".empirica/active_session"
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -n "$GIT_ROOT" ] && [ -f "$GIT_ROOT/$ACTIVE_SESSION_FILE" ]; then
    cat "$GIT_ROOT/$ACTIVE_SESSION_FILE"
elif [ -f "$ACTIVE_SESSION_FILE" ]; then
    cat "$ACTIVE_SESSION_FILE"
else
    echo "NO_SESSION"
fi
```

Note the session ID. If no session, Empirica writes will be skipped (fail-soft).

### Step 3: Gather Insights from Disk

Read `.empirica/insights.jsonl` (at git root). Each line is a JSON object:

```json
{"timestamp": "ISO-8601", "type": "finding", "input": {"finding": "text", "category": "insight"}}
```

Parse each line. Collect all entries that have NOT already been synced (check for `"synced": true` field — unsynced entries lack this field).

### Step 4: Gather Insights from Conversation

Scan the current conversation for any ★ Insight blocks that were NOT already captured to disk or Empirica. These are blocks formatted like:

```
★ Insight: <title or summary>
<body text>
```

Deduplicate against the disk entries from Step 3 by comparing the finding text (fuzzy match on content — exact match not required, but the core insight should match).

### Step 5: Merge and Deduplicate

Combine disk insights (Step 3) and conversation insights (Step 4) into a single list. Remove duplicates. Each insight needs:

- **title**: Short descriptive title (extract from finding text or ★ Insight header)
- **description**: Full insight text
- **category**: From the JSON `category` field, or "insight" as default
- **severity**: From the JSON if present, or "info" as default
- **timestamp**: From the JSON `timestamp`, or current time for conversation-only insights
- **confidence**: From the JSON if present, or 0.7 as default for unassessed insights

### Step 6: Write to Obsidian Vault

If vault is available (Step 1):

1. Ensure target directory exists:

```bash
mkdir -p "$VAULT_PATH/Engineering/Findings"
```

2. Read the finding template from `~/.claude/commands/templates/vault-notes/finding.md`.

3. For each insight, create a vault note:

   - Get the project name: `basename $(git rev-parse --show-toplevel 2>/dev/null || echo "unknown")`
   - Generate slug via Bash: `echo "TITLE_HERE" | tr -cd '[:alnum:] ._-' | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | head -c 80`
   - Replace template placeholders:
     - `{{date}}`: Today's date (YYYY-MM-DD)
     - `{{project}}`: Project name
     - `{{category}}`: From insight data
     - `{{severity}}`: From insight data
     - `{{title}}`: Insight title
     - `{{description}}`: Full insight text
     - `{{session_link}}`: Session ID from Step 2 (or "no-session")
     - `{{implications}}`: Brief note on why this matters (Claude-generated from context)
   - Add Empirica confidence frontmatter (conditional fields — omit line entirely if no value):
     - `empirica_confidence`: From insight confidence value
     - `empirica_assessed`: Today's date (YYYY-MM-DD)
     - `empirica_session`: Session ID from Step 2
     - `empirica_status`: "active"
   - Write to: `$VAULT_PATH/Engineering/Findings/YYYY-MM-DD-slug.md`

4. Use the Write tool for each note. Do NOT use Obsidian MCP for writes.

If vault is unavailable, log: "Vault write skipped (vault disabled or not accessible). Empirica-only mode."

### Step 7: Write to Empirica

If an active Empirica session exists (Step 2):

For each insight, call `mcp__empirica__finding_log` with:
- `session_id`: Active session ID
- `finding`: The insight text
- `category`: "insight"

If no session exists, log: "Empirica write skipped (no active session). Vault-only mode."

### Step 8: Mark Disk Entries as Synced

Update `.empirica/insights.jsonl` to mark processed entries. For each processed line, add `"synced": true` to the JSON object. Write the updated file back.

If the file contained ONLY the entries that were just processed, the file can be cleared to an empty file to avoid unbounded growth.

### Step 9: Present Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  COLLECT INSIGHTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Sources:
    Disk (.empirica/insights.jsonl):  N entries
    Conversation (★ Insight blocks):  N entries
    Duplicates removed:               N

  Written:
    Vault:    N notes → Engineering/Findings/
    Empirica: N findings logged

  Skipped:
    [reason, if any — e.g., "Vault unavailable", "No active Empirica session"]

  Files:
    [list of vault note paths written]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Examples

```
/collect-insights                # Flush all pending insights
```

## Notes

- This command dual-writes: Obsidian vault is the primary data store, Empirica is the analytical layer
- Fail-soft: if vault is unavailable, Empirica writes still proceed (and vice versa)
- If BOTH vault and Empirica are unavailable, the command reports what it found but cannot write
- All vault writes use the Write tool (no Obsidian MCP dependency)
- Filenames use vault_sanitize_slug for NTFS safety
- The PostToolUse hook (`empirica-insight-capture.sh`) is the write-through safety net that populates insights.jsonl
- Pair with `/end` for full session closure, or use standalone mid-session to flush accumulated insights
