---
description: Use when you need to search the Obsidian vault for past decisions, patterns, findings, or knowledge.
---

# Vault Query

Search the Obsidian vault for past decisions, patterns, findings, and session knowledge.

## Process

### Step 1: Source Vault Config

Use the Bash tool to source vault-config.sh and extract config values:

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo "VAULT_ENABLED=$VAULT_ENABLED" && echo "VAULT_PATH=$VAULT_PATH"
```

If vault is unavailable, check availability and inform the user:

```
Vault not available. Check that:
  1. ~/.claude/hooks/vault-config.sh exists (copy from vault-config.sh.example)
  2. VAULT_PATH is set to your Obsidian vault location
  3. VAULT_ENABLED=1
```

### Step 2: Get Search Query

If provided as argument (e.g., `/vault-query authentication`), use it. Otherwise ask what to search for.

Parse optional flags:
- `--type <type>` — Filter by note type (decision, finding, session, blueprint, idea, pattern)
- `--project <name>` — Filter by project name

### Step 3: Search Strategy

Execute searches in this order, combining results:

#### 3a: Frontmatter Search

Use Grep tool against `$VAULT_PATH` to search YAML frontmatter for matching tags, project names, or types:

```
Pattern: "^(type|project|tags):.*QUERY"
Path: $VAULT_PATH
```

If `--type` specified, filter: `"^type: TYPE"`
If `--project` specified, filter: `"^project: PROJECT"`

#### 3b: Content Search

Use Grep tool to search note content for keywords:

```
Pattern: "QUERY"
Path: $VAULT_PATH
Glob: "*.md"
```

Exclude infrastructure files: `.obsidian/`, `_Templates/`, `CLAUDE.md`.

#### 3c: Title Search

Use Glob tool to match filenames:

```
Pattern: "**/*QUERY*.md"
Path: $VAULT_PATH
```

### Step 4: Present Results

Deduplicate results across all three search strategies. Present as a ranked list:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VAULT QUERY: "authentication"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Found N notes:

  1. Engineering/Decisions/2026-02-15-auth-pattern-choice.md
     type: decision | project: my-app
     "Chose JWT over session cookies because..."

  2. Sessions/2026-02-15-1430-my-app-summary.md
     type: session | project: my-app
     "Implemented OAuth2 flow with..."

  3. Engineering/Findings/2026-02-14-token-refresh-edge-case.md
     type: finding | project: my-app
     "Token refresh fails silently when..."

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Ranking priority:
1. Frontmatter matches (most specific)
2. Title matches
3. Content matches

### Step 5: Offer Deep Dive

```
Enter a number to read the full note, or press Enter to continue.
```

If the user selects a note, read and display its full content.

## Examples

```
/vault-query authentication         # Search for auth-related knowledge
/vault-query --type decision api    # Search only decision notes for "api"
/vault-query --project bootstrap    # All notes for the bootstrap project
/vault-query hook patterns          # Find notes about hook patterns
```

## Notes

- Search uses the Grep tool (not MCP) for reliable, dependency-free operation
- No vector database or semantic search — wiki-links and tags provide structure for keyword search
- Results are capped at 20 to keep output manageable
- If the vault has an Obsidian Smart Connections plugin, it can provide semantic search independently
- All searches exclude `.obsidian/` internal files
