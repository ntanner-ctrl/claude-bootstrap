# Spec: vault-data-pipeline

## Overview

Three workstreams that unify project artifact flow into the Obsidian vault:

1. **Backfill** (local, one-time) — Migrate 19 blueprints + 24 Empirica findings to vault
2. **Pipeline** (distributed) — Auto-export new blueprints to vault at completion
3. **Preflight Capture** (distributed) — Capture preflight vectors to disk, pair with postflight in `/end`

All distributed changes guarded by `vault_is_available()` — non-vault users see zero change.

---

## Cross-Cutting Concerns (from Debate Chain)

### Vault Note Schema Versioning [FA]

All vault note templates MUST include `schema_version: 1` in frontmatter. This enables future migration detection. When templates are updated, increment the version and document the change in a migration note.

### Merge-Write Pattern [F2]

Any vault write that targets a file that may already exist MUST use the merge-write pattern:

1. Check if file exists at target path
2. If exists: Read existing file. Split at sentinel `<!-- user-content -->`.
   - **Above sentinel:** Overwrite with new generated content (frontmatter + body)
   - **Below sentinel:** Preserve as-is (user annotations, tags, links)
   - If no sentinel exists: Append sentinel + existing body below new generated content
3. If not exists: Write new file with sentinel at the end of generated content

This protects user annotations added in Obsidian from being destroyed by auto-exports.

### WSL Path Guard [FB]

`vault_is_available()` already checks directory existence and writability. Add to `vault-config.sh.example` a comment clarifying that `VAULT_PATH` MUST be a WSL-native path (e.g., `/mnt/c/Users/.../Helvault`), NOT a Windows path (e.g., `C:\Users\...`). The existing `[ -d "$VAULT_PATH" ]` check will fail on Windows paths, which is correct fail-safe behavior. No code change needed — documentation clarification only.

### Vault Write Failure Logging [F3, F4]

When `vault_is_available()` returns true but a subsequent Write tool call fails, OR when `vault_is_available()` returns false while `VAULT_ENABLED=1`:
- Claude should log the skip/failure inline: `"Vault write skipped: [reason]"`
- This is a behavioral instruction to Claude (in the command markdown), not a shell hook

### Dedup Strategy [F1]

Replace fuzzy dedup with deterministic slug match:
- Generate the target filename slug
- If a file matching `*-<slug>.md` exists in the target directory, skip
- Log: `"Skipped (exists): <filename>"`

### Hook Matcher Table [F11]

| MCP Tool | Hook | Output File |
|----------|------|-------------|
| `mcp__empirica__finding_log` | `empirica-insight-capture.sh` | `.empirica/insights.jsonl` |
| `mcp__empirica__mistake_log` | `empirica-insight-capture.sh` | `.empirica/insights.jsonl` |
| `mcp__empirica__deadend_log` | `empirica-insight-capture.sh` | `.empirica/insights.jsonl` |
| `mcp__empirica__submit_preflight_assessment` | `empirica-preflight-capture.sh` | `.empirica/preflight.jsonl` |
| `mcp__empirica__submit_postflight_assessment` | `empirica-postflight-capture.sh` | `.empirica/postflight.jsonl` |

### Delta Threshold Policy [F5]

The epistemic delta vault note is ALWAYS created when both preflight and postflight data exist (no minimum threshold to suppress). All 13 vectors are shown. The categorization labels (Significant gain / Moderate gain / Stable / Confidence decreased) are informational — they don't gate any behavior.

### Path Length Guard [F8, FF]

After constructing the full vault note path, check total length. If > 200 characters, truncate the slug portion further (to keep total under 200). Also strip leading/trailing hyphens from slug output.

### JSONL Export Lifecycle [Edge Case Discussion]

JSONL files (`.empirica/insights.jsonl`, `preflight.jsonl`, `postflight.jsonl`) are **staging areas**, not permanent stores. The vault is the permanent record.

After `/end` successfully exports a finding to the vault, mark the JSONL entry as exported:
- Add `"exported": true` to the JSON object
- Future `/end` runs skip entries where `exported == true`
- User can prune exported entries at will (e.g., `jq 'select(.exported != true)'` or delete entries older than N days)

This prevents duplication across vault + JSONL + Empirica DB while preserving the safety-net write-through pattern.

### Vault Subdirectory Creation [S-2]

Every vault write path MUST be preceded by `mkdir -p` for the target subdirectory. `vault_is_available()` only checks the root vault path, not subdirectories. First-run scenarios where `Engineering/Blueprints/` or `Sessions/` don't exist yet will fail silently without this.

### jq Dependency Check [T-4]

The backfill script MUST check `command -v jq` and exit with a clear error if missing. For hooks (which are fail-open), `session-bootstrap.sh` should warn once per session if `jq` is not available, since all JSONL capture hooks depend on it.

### Template Placeholder Fallback [CT-2]

When hydrating vault note templates, any `{{placeholder}}` with no available value MUST be replaced with an empty string or omitted, never left as raw mustache syntax. For YAML frontmatter, use `~` (YAML null). For body text, use empty string.

### Long Text in Note Body, Not Frontmatter [CT-3]

Finding descriptions, blueprint summaries, and other multi-line text MUST go in the note body (below `---` frontmatter fence), NOT in frontmatter fields. YAML frontmatter is for metadata only (date, project, tags, status, session_id). This prevents YAML parsing breakage from colons, dashes, and special characters in content.

### Cross-Project Slug Collision [CT-1]

For the backfill script (WU1), include project name in the slug to prevent cross-project collisions: `YYYY-MM-DD-<project>-<slug>.md`. For ongoing exports (WU3, WU6), the vault note is always scoped to the current project, so collisions are less likely but the same pattern should be used for consistency.

---

## Work Unit 1: Backfill Script

**Type:** Local script, NOT distributed in the repo
**File:** `scripts/backfill-vault.sh` (gitignored, or run-once and delete)

### 1a: Blueprint Backfill

**Input:** All `manifest.json` files found under:
- `/home/nick/claude-bootstrap/.claude/plans/*/manifest.json`
- `/home/nick/project_scout/.claude/plans/*/manifest.json`
- `/home/nick/.claude/plans/*/manifest.json`

**For each blueprint:**
1. Read `manifest.json` (primary) with `state.json` fallback for missing fields
2. Extract: name, current_stage, path_type, challenge_mode, decisions, work_units summary
3. Map stage number to name: 1=Describe, 2=Specify, 3=Challenge, 4=Edge Cases, 4.5=Pre-Mortem, 5=Review, 6=Test, 7=Execute
4. Read `adversarial.md` if it exists — extract top findings (first 5 bullet points or findings)
5. Hydrate `blueprint-summary.md` template
6. Set `project` from the git repo containing the blueprint (basename of repo root)
7. Set `date` from `state.json` `created` field (or file mtime as fallback)
8. Write to `$VAULT_PATH/Engineering/Blueprints/YYYY-MM-DD-blueprint-name.md`

**Dedup:** Generate slug from blueprint name. If `$VAULT_PATH/Engineering/Blueprints/*-<slug>.md` exists, skip with log message. [F1: deterministic slug match]

### 1b: Empirica Findings Backfill

**Input:** All `.empirica/insights.jsonl` files found under:
- `/home/nick/.empirica/insights.jsonl`
- `/home/nick/claude-bootstrap/.empirica/insights.jsonl`
- `/home/nick/project_scout/.empirica/insights.jsonl`

**For each JSONL entry where `type == "finding"`:**
1. Parse JSON: extract `timestamp`, `input.finding`, `input.impact`, `input.session_id`, `input.category`
2. Skip entries where `type` is `postflight` or `preflight` (metadata, not findings)
3. Generate title from first sentence of `finding` text (truncated to 60 chars)
4. Hydrate `finding.md` template:
   - `date`: from `timestamp` (YYYY-MM-DD)
   - `project`: from the directory containing the insights.jsonl (git repo basename, or "global" for `~/.empirica/`)
   - `category`: from `input.category` or "insight"
   - `severity`: "info" (default for backfill — not assessed)
   - `empirica_confidence`: from `input.impact` if present, else 0.5
   - `empirica_session`: from `input.session_id` if present
   - `empirica_status`: "active"
   - `description`: full `input.finding` text
   - `implications`: "Imported from pre-vault Empirica disk cache. Review and assess."
5. Write to `$VAULT_PATH/Engineering/Findings/YYYY-MM-DD-slug.md`

**Dedup:** Generate slug from finding title. If `$VAULT_PATH/Engineering/Findings/*-<slug>.md` exists, skip with log message. [F1: deterministic slug match, replaces fuzzy 80% threshold]

### 1c: Script Structure

```bash
#!/usr/bin/env bash
# backfill-vault.sh — One-time migration of orphaned artifacts to Obsidian vault
# Run once, then delete. NOT part of the distributed toolkit.
set +e

source ~/.claude/hooks/vault-config.sh 2>/dev/null
vault_is_available || { echo "Vault not available"; exit 1; }

# ... blueprint scan + hydrate loop ...
# ... findings scan + hydrate loop ...

echo "Backfill complete: $BP_COUNT blueprints, $FN_COUNT findings"
```

**Template updates:** Both `blueprint-summary.md` and `finding.md` templates must include `schema_version: 1` in frontmatter [FA] and end with `<!-- user-content -->` sentinel [F2].

**Complexity:** Medium (jq for JSON parsing, template hydration, dedup logic)
**Risk:** Low (creates new files only, never modifies existing)

---

## Work Unit 2: Add `blueprint` Type to `/vault-save`

**File:** `commands/vault-save.md`

### Changes

1. Add `blueprint` to the type selection menu (Step 3):

```
What type of note?
  [1] Idea — ad-hoc thought or concept (→ Ideas/)
  [2] Decision — architectural or process decision (→ Engineering/Decisions/)
  [3] Finding — discovery or insight (→ Engineering/Findings/)
  [4] Pattern — reusable technique or approach (→ Engineering/Patterns/)
  [5] Blueprint — planning snapshot (→ Engineering/Blueprints/)
```

2. Add to the type routing table:

| Type | Template | Target Directory |
|------|----------|-----------------|
| blueprint | vault-notes/blueprint-summary.md | Engineering/Blueprints/ |

3. When `blueprint` type is selected:
   - **Detection priority [F9]:** (1) Check `.claude/plans/*/state.json` for `status: "in_progress"`, (2) if multiple, use most-recently-modified, (3) if none in-progress, check for most recent `state.json` by mtime, (4) if none found, prompt user for blueprint name
   - Auto-populate from manifest/state when detected
   - Hydrate `blueprint-summary.md` template using the same extraction logic as WU1a
   - Include `schema_version: 1` in frontmatter [FA]

**Complexity:** Low (extending existing command)
**Risk:** Low (additive change to existing type list)

---

## Work Unit 3: Auto-Export at Blueprint Completion

**File:** `commands/blueprint.md` (Stage 7 completion section)

### Changes

Add vault export step to the completion block (after "Ready to implement. Artifacts saved for reference."):

```markdown
### Vault Export (Automatic)

After presenting the completion summary, if vault is available:

1. Source vault config:
   ```bash
   source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo "VAULT_ENABLED=$VAULT_ENABLED" && echo "VAULT_PATH=$VAULT_PATH"
   ```

2. If `vault_is_available()` returns true:
   a. Read `manifest.json` for the completed blueprint
   b. Read `adversarial.md` for top findings (if exists)
   c. Hydrate `blueprint-summary.md` template (same logic as WU1a/WU2)
   d. Write to `$VAULT_PATH/Engineering/Blueprints/YYYY-MM-DD-blueprint-name.md`
   e. If file already exists: use **merge-write pattern** [F2] — preserve user content below `<!-- user-content -->` sentinel, overwrite generated content above it
   f. Include `schema_version: 1` in frontmatter [FA]
   g. Report:
      ```
      Vault: Blueprint summary exported to Engineering/Blueprints/
      ```

3. If vault is NOT available but `VAULT_ENABLED=1`: report `"Vault write skipped: directory not accessible"` [F3]
4. If vault is NOT available and `VAULT_ENABLED=0`: silently skip
```

**Guard:** Entire block wrapped in vault availability check. Non-vault users see no difference.

**Complexity:** Low (template hydration at a single trigger point)
**Risk:** Low (additive, guarded, write-only)

---

## Work Unit 4: Preflight Vector Capture Hook

**File:** `hooks/empirica-preflight-capture.sh` (NEW)

### Design

Mirrors `empirica-insight-capture.sh` exactly, but for `submit_preflight_assessment`:

```bash
#!/usr/bin/env bash
# empirica-preflight-capture.sh — Capture preflight vectors to disk
#
# PostToolUse hook matched on mcp__empirica__submit_preflight_assessment.
# Persists the 13 epistemic vectors to .empirica/preflight.jsonl so /end
# can pair them with postflight for delta calculation.
#
# Exit codes: Always 0 (fail-open)

set +e

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
tool_input=$(echo "$input" | jq -r '.tool_input // empty' 2>/dev/null)

[ -z "$tool_input" ] && exit 0

# Resolve data dir (same as insight-capture)
if [ -n "$EMPIRICA_DATA_DIR" ]; then
    EMPIRICA_DIR="$EMPIRICA_DATA_DIR"
else
    GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    EMPIRICA_DIR="$GIT_ROOT/.empirica"
fi
mkdir -p "$EMPIRICA_DIR" 2>/dev/null

PREFLIGHT_FILE="$EMPIRICA_DIR/preflight.jsonl"

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

entry=$(jq -n \
    --arg ts "$timestamp" \
    --argjson input "$tool_input" \
    '{timestamp: $ts, type: "preflight", input: $input}' 2>/dev/null)

if [ -n "$entry" ]; then
    echo "$entry" >> "$PREFLIGHT_FILE" 2>/dev/null
fi

exit 0
```

### Hook Wiring

Add to `settings-example.json` under `PostToolUse`:

```json
{
  "matcher": "mcp__empirica__submit_preflight_assessment",
  "hooks": [
    {
      "type": "command",
      "command": "~/.claude/hooks/empirica-preflight-capture.sh"
    }
  ]
}
```

**Complexity:** Low (clone of existing pattern)
**Risk:** Low (fail-open, append-only, no side effects)

---

## Work Unit 5: Postflight Capture Hook

**File:** `hooks/empirica-postflight-capture.sh` (NEW)

### Design

Same pattern, captures postflight vectors for delta pairing:

```bash
#!/usr/bin/env bash
# empirica-postflight-capture.sh — Capture postflight vectors to disk
#
# PostToolUse hook matched on mcp__empirica__submit_postflight_assessment.
# Persists the 13 epistemic vectors to .empirica/postflight.jsonl so /end
# can pair them with preflight for delta calculation and vault export.
#
# Exit codes: Always 0 (fail-open)

set +e

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
tool_input=$(echo "$input" | jq -r '.tool_input // empty' 2>/dev/null)

[ -z "$tool_input" ] && exit 0

if [ -n "$EMPIRICA_DATA_DIR" ]; then
    EMPIRICA_DIR="$EMPIRICA_DATA_DIR"
else
    GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    EMPIRICA_DIR="$GIT_ROOT/.empirica"
fi
mkdir -p "$EMPIRICA_DIR" 2>/dev/null

POSTFLIGHT_FILE="$EMPIRICA_DIR/postflight.jsonl"

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

entry=$(jq -n \
    --arg ts "$timestamp" \
    --argjson input "$tool_input" \
    '{timestamp: $ts, type: "postflight", input: $input}' 2>/dev/null)

if [ -n "$entry" ]; then
    echo "$entry" >> "$POSTFLIGHT_FILE" 2>/dev/null
fi

exit 0
```

### Hook Wiring

Add to `settings-example.json` under `PostToolUse`:

```json
{
  "matcher": "mcp__empirica__submit_postflight_assessment",
  "hooks": [
    {
      "type": "command",
      "command": "~/.claude/hooks/empirica-postflight-capture.sh"
    }
  ]
}
```

**Complexity:** Low (clone of existing pattern)
**Risk:** Low

---

## Work Unit 6: Modify `/end` to Export Preflight-Postflight Delta

**File:** `commands/end.md`

### Changes

Add new Step 2.6 (after Step 2.5 Vault Export, before Step 3 Insight Sweep):

```markdown
### Step 2.6: Export Epistemic Delta to Vault

Pair preflight and postflight vectors and export the learning delta.

1. **Read preflight vectors**: Read `.empirica/preflight.jsonl`. Find the most recent entry
   matching the current session_id (from `input.session_id`). If no match, find the most
   recent entry by timestamp. If file missing or empty, skip with note.

2. **Read postflight vectors**: Read `.empirica/postflight.jsonl`. Find the most recent entry.
   If file missing (postflight just submitted and hook hasn't fired yet), extract vectors from
   the postflight call made in Step 2.

3. **Calculate delta**: For each of the 13 vectors, compute `postflight - preflight`.
   Categorize:
   - Delta > +0.2: "Significant learning gain"
   - Delta > +0.1: "Moderate gain"
   - Delta -0.1 to +0.1: "Stable"
   - Delta < -0.1: "Confidence decreased" (not a bad thing — recalibration)

4. **Create vault note**: Write to `$VAULT_PATH/Sessions/YYYY-MM-DD-epistemic-delta-project.md`:

   ```yaml
   ---
   type: session-epistemic
   date: YYYY-MM-DD
   project: project-name
   session: SESSION_ID
   tags: [epistemic, session]
   ---
   ```

   Body includes:
   - Table of all 13 vectors: preflight → postflight → delta → category
   - Summary: top 3 biggest deltas (positive or negative)
   - Link to session summary note (if created in Step 2.5)

5. **Path resolution [F14]**: Explicitly resolve and display the `.empirica/` path being read:
   `"Reading epistemic data from: /home/nick/project/.empirica/"`

6. **Guard**: Only create if vault is available AND both preflight and postflight data exist.
   If either is missing, log reason: `"Epistemic delta skipped: [preflight|postflight] data not found"` [F15]

7. **Mark as exported**: After successful vault write, update the JSONL entries used:
   - For each preflight/postflight entry consumed, add `"exported": true`
   - For insights.jsonl entries exported in Step 1.5/2.5, add `"exported": true`
   - Implementation: read file, update matching entries via jq, write back
   - If marking fails: log warning, do not block session closure (fail-soft)
```

### Vault Note Template

Create new template: `commands/templates/vault-notes/epistemic-delta.md`

```yaml
---
type: session-epistemic
schema_version: 1
date: {{date}}
project: {{project}}
session: {{session_id}}
tags: [epistemic, session]
---

# Epistemic Delta: {{project}} — {{date}}

## Vectors

| Dimension | Pre | Post | Delta | Assessment |
|-----------|-----|------|-------|------------|
{{vector_rows}}

## Key Movements
{{key_movements}}

## Session Context
- Session: [[{{session_link}}]]
{{#if blueprint_link}}- Blueprint: [[{{blueprint_link}}]]{{/if}}

<!-- user-content -->
```

**Complexity:** Medium (JSONL parsing, delta calculation, template hydration)
**Risk:** Low (creates new file, guarded, no modification of existing data)

---

## Work Unit 7: Update `settings-example.json`

**File:** `settings-example.json`

### Changes

Add two new PostToolUse matcher entries:

```json
{
  "matcher": "mcp__empirica__submit_preflight_assessment",
  "hooks": [
    {
      "type": "command",
      "command": "~/.claude/hooks/empirica-preflight-capture.sh"
    }
  ]
},
{
  "matcher": "mcp__empirica__submit_postflight_assessment",
  "hooks": [
    {
      "type": "command",
      "command": "~/.claude/hooks/empirica-postflight-capture.sh"
    }
  ]
}
```

These go in the `PostToolUse` array alongside the existing `empirica-insight-capture.sh` entry.

**Complexity:** Trivial
**Risk:** Low

---

## Work Unit 8: Update Counts and Documentation

**Files:** `install.sh`, `README.md`, `commands/README.md`, `CLAUDE.md`

### Changes

1. **Hook count**: 17 → 19 (adding preflight-capture + postflight-capture)
2. **README.md**: Update hook count in overview section
3. **commands/README.md**: Add `blueprint` type to vault-save description if documented
4. **CLAUDE.md**: Update hook count reference
5. **install.sh**: Update output message hook count

**Complexity:** Trivial
**Risk:** Low (documentation-only)

---

## File Change Summary

| File | Action | Work Unit |
|------|--------|-----------|
| `scripts/backfill-vault.sh` | CREATE (local, not distributed) | WU1 |
| `commands/vault-save.md` | MODIFY (add blueprint type) | WU2 |
| `commands/blueprint.md` | MODIFY (add vault export at completion) | WU3 |
| `hooks/empirica-preflight-capture.sh` | CREATE | WU4 |
| `hooks/empirica-postflight-capture.sh` | CREATE | WU5 |
| `commands/end.md` | MODIFY (add epistemic delta export) | WU6 |
| `commands/templates/vault-notes/epistemic-delta.md` | CREATE | WU6 |
| `settings-example.json` | MODIFY (add hook wiring) | WU7 |
| `install.sh` | MODIFY (update counts) | WU8 |
| `README.md` | MODIFY (update counts) | WU8 |
| `commands/README.md` | MODIFY (update counts) | WU8 |
| `.claude/CLAUDE.md` | MODIFY (update counts) | WU8 |

**Total: 12 files (4 new, 8 modified)**

---

## Dependency Graph

```
WU1 (backfill) ────────────────────── independent (local script)
WU2 (vault-save blueprint type) ───── independent
WU3 (blueprint auto-export) ────────── depends on WU2 (uses same template logic)
WU4 (preflight capture hook) ──────── independent
WU5 (postflight capture hook) ─────── independent
WU6 (/end delta export) ───────────── depends on WU4, WU5 (reads their output files)
WU7 (settings wiring) ────────────── depends on WU4, WU5 (references new hooks)
WU8 (documentation) ──────────────── depends on WU4, WU5 (updates counts)
```

**Parallelizable:** WU1, WU2, WU4, WU5 can all run in parallel.
**Sequential:** WU3 after WU2. WU6 after WU4+WU5. WU7 after WU4+WU5. WU8 last.

---

## Backward Compatibility

Every distributed change (WU2-WU8) is guarded:
- `/vault-save`: Blueprint type only appears in menu — no behavior change for existing types
- `/blueprint`: Vault export wrapped in `vault_is_available()` — skips silently if no vault
- `/end`: Epistemic delta export guarded by vault availability AND data existence
- Hooks: PostToolUse hooks only fire if Empirica MCP tools are called — no effect without Empirica
- `settings-example.json`: Users without Empirica won't have these MCP tools, so matchers never fire
