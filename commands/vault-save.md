---
description: Use when you want to capture knowledge, ideas, or findings to the Obsidian vault for future reference.
---

# Vault Save

Manual knowledge capture to the Obsidian vault. Creates a formatted note with YAML frontmatter and wiki-links.

## Process

### Step 1: Source Vault Config

Use the Bash tool to source vault-config.sh and extract config values:

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo "VAULT_ENABLED=$VAULT_ENABLED" && echo "VAULT_PATH=$VAULT_PATH"
```

If `VAULT_ENABLED=0` or vault path is unavailable, inform the user:

```
Vault not available. Check that:
  1. ~/.claude/hooks/vault-config.sh exists (copy from vault-config.sh.example)
  2. VAULT_PATH is set to your Obsidian vault location
  3. VAULT_ENABLED=1
```

### Step 2: Ensure Target Directory

```bash
mkdir -p "$VAULT_PATH/<target_subdir>"
```

The target subdirectory depends on the note type (determined in Step 3).

### Step 3: Determine Note Type

If the user provided a type argument (e.g., `/vault-save idea`), use it. Otherwise ask:

```
What type of note?
  [1] Idea — ad-hoc thought or concept (→ Ideas/)
  [2] Decision — architectural or process decision (→ Engineering/Decisions/)
  [3] Finding — discovery or insight (→ Engineering/Findings/)
  [4] Pattern — reusable technique or approach (→ Engineering/Patterns/)
  [5] Blueprint — planning snapshot (→ Engineering/Blueprints/)
```

| Type | Template | Target Directory |
|------|----------|-----------------|
| idea | vault-notes/idea.md | Ideas/ |
| decision | vault-notes/decision.md | Engineering/Decisions/ |
| finding | vault-notes/finding.md | Engineering/Findings/ |
| pattern | vault-notes/finding.md (adapted) | Engineering/Patterns/ |
| blueprint | vault-notes/blueprint-summary.md | Engineering/Blueprints/ |

**Blueprint auto-detection [F9]:** When `blueprint` type is selected:
1. Check `.claude/plans/*/state.json` for a plan with `status: "in_progress"` on any stage
2. If multiple in-progress plans, use most recently modified `state.json` (by mtime)
3. If none in-progress, use most recent `state.json` by mtime
4. If no plans found, prompt user for blueprint name and details manually
5. Auto-populate template fields from `manifest.json` (primary) with `state.json` fallback
6. Include `schema_version: 1` in frontmatter

### Step 4: Get Title

If provided as argument (e.g., `/vault-save idea webhook retry logic`), use the text after the type as the title. Otherwise ask for a descriptive title.

### Step 5: Get Content

If the conversation context makes the content obvious (e.g., a discussion about a specific topic), draft it. Otherwise ask the user what to capture.

### Step 6: Apply Template

Read the appropriate template from `~/.claude/commands/templates/vault-notes/`. Replace `{{placeholder}}` values:

- `{{date}}`: Today's date (YYYY-MM-DD)
- `{{project}}`: Current project name (from git repo basename)
- `{{title}}`: From Step 4
- `{{content}}` / `{{description}}` / etc.: From Step 5
- Other fields: Fill from context or leave as descriptive placeholder

### Step 7: Add Wiki-Links

Check the vault for **existing** notes that relate to this one. Search by:
- Matching project name in frontmatter
- Matching tags or type
- Keyword overlap in titles

Add `[[wiki-links]]` to existing notes only. Do NOT create speculative links to notes that don't exist yet.

### Step 8: Write Note

Construct the filename using vault_sanitize_slug (via Bash):

```bash
echo "TITLE_HERE" | tr -cd '[:alnum:] ._-' | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | head -c 80
```

Write to: `$VAULT_PATH/<target_subdir>/YYYY-MM-DD-slug.md`

Use the Write tool to create the file.

### Step 9: Confirm

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VAULT SAVE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Saved: Ideas/2026-02-18-webhook-retry-logic.md
  Type:  idea
  Links: [[2026-02-18-api-design-decision]]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Examples

```
/vault-save                              # Interactive — asks type, title, content
/vault-save idea webhook retry logic     # Quick: type=idea, title from args
/vault-save finding                      # Type=finding, asks for title and content
/vault-save pattern fail-open hooks      # Type=pattern, title from args
```

## Notes

- This command writes directly to the vault using the Write tool (no MCP dependency)
- Templates are in `~/.claude/commands/templates/vault-notes/`
- All filenames use vault_sanitize_slug() for NTFS safety
- Wiki-links point to existing notes only (no speculative links)
- The note will appear in the session summary when `/end` is used (Ideas/ notes with today's date are included)
