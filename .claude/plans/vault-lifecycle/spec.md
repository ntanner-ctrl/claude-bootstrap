# Change Specification: vault-lifecycle

## Summary

Improve the vault's knowledge lifecycle by fixing the read path (project-filtered notes at session start), adding vault awareness to key workflow commands, creating pattern infrastructure (template + promotion + guided save), and operationalizing curation cadence tracking.

## What Changes

### Files/Components Touched

| File | Nature of Change |
|------|------------------|
| `hooks/session-bootstrap.sh` | Modify — rewrite vault context section: project-filtered, no time cutoff, title excerpts, curation cadence check |
| `commands/blueprint.md` | Modify — add vault-query step to Stage 1 (Describe) |
| `commands/debug.md` | Modify — add vault-query step to Phase 1 (OBSERVE) |
| `commands/brainstorm.md` | Modify — add vault-query step to Phase 1 (Analysis) |
| `commands/templates/vault-notes/pattern.md` | Add — new template for pattern notes |
| `commands/vault-curate.md` | Modify — add pattern promotion action to Stage 4 (Synthesis) |
| `.claude/plans/vault-curate/spec.md` | Modify — add pattern promotion to Stage 4 |
| `commands/vault-save.md` | Modify — enhance pattern path with guided finding search |
| Vault `CLAUDE.md` (external) | Modify — document `_Templates` as Obsidian artifact, clarify `Engineering/Patterns/` |

### External Dependencies

- [x] None (all changes are markdown/shell within the toolkit)

### Database/State Changes

- [x] None

## Preservation Contract (What Must NOT Change)

- **session-bootstrap.sh must complete in <2 seconds.** The current vault section uses `timeout 2` on `find`. The replacement must respect this budget — WSL→NTFS is slow.
- **session-bootstrap.sh must fail-open.** If vault is unavailable, the hook must still produce valid output (no vault section, no error).
- **Commands must remain usable without a vault.** Vault-query steps in `/blueprint`, `/debug`, `/brainstorm` must be advisory ("if vault is available, search for..."), not blocking.
- **`/vault-curate` existing stages must not change behavior.** Pattern promotion is additive (new option in Stage 4 synthesis actions).
- **`/vault-save` existing paths must not change.** The pattern enhancement only adds a step when `type=pattern`, not for other types.

## Work Units

| ID | Description | Files | Dependencies | Complexity |
|----|-------------|-------|--------------|------------|
| WU1 | Rewrite vault context in session-bootstrap.sh — project-filtered, no time cutoff, title excerpts | `hooks/session-bootstrap.sh` | none | Medium |
| WU2 | Add curation cadence check to session-bootstrap.sh | `hooks/session-bootstrap.sh` | WU1 (same file, append after vault context) | Small |
| WU3 | Add vault-query step to /blueprint Stage 1 | `commands/blueprint.md` | none | Small |
| WU4 | Add vault-query step to /debug Phase 1 | `commands/debug.md` | none | Small |
| WU5 | Add vault-query step to /brainstorm Phase 1 | `commands/brainstorm.md` | none | Small |
| WU6 | Create pattern.md vault-note template | `commands/templates/vault-notes/pattern.md` | none | Small |
| WU7 | Add pattern promotion to /vault-curate Stage 4 | `commands/vault-curate.md`, `.claude/plans/vault-curate/spec.md` | WU6 (template must exist) | Medium |
| WU8 | Enhance /vault-save pattern path with guided finding search | `commands/vault-save.md` | WU6 (template must exist) | Small |
| WU9 | Document _Templates and Engineering/Patterns in vault CLAUDE.md | Vault `CLAUDE.md` (external) | none | Trivial |

## Design Details

### WU1: Session Bootstrap — Vault Read Path

Replace lines 173-194 of `session-bootstrap.sh`. The new logic:

1. Source vault config (same as now)
2. Get current project name: `basename $(git rev-parse --show-toplevel 2>/dev/null)`
3. Search for notes matching this project via frontmatter grep, sorted by mtime, limit 7:
   ```bash
   # Project-filtered: grep for project: <name> in frontmatter, take 7 most recent
   timeout 2 grep -rl "^project: ${PROJECT}" "$VAULT_PATH" --include="*.md" \
     -l 2>/dev/null | xargs ls -t 2>/dev/null | head -7
   ```
4. For each matched note, extract the `# Title` line (first H1):
   ```bash
   awk '/^# /{print; exit}' "$note" 2>/dev/null
   ```
5. If zero project-specific notes found, fall back to 7 most recently modified notes globally (current behavior minus time cutoff)
6. Display as:
   ```
   OBSIDIAN VAULT (project knowledge):
     Vault: /path/to/vault
     Recent for [project] (7 notes):
       Engineering/Findings/2026-03-06-example.md
         "Example Finding Title"
       ...
     Use /vault-query to search for specific topics.
     Use /vault-save to capture ideas or findings.
   ```

**Performance budget:** The entire vault section must complete within `timeout 2`. Use a single `grep -rl` piped through `xargs ls -t` rather than per-file reads. Title extraction is a fast `awk` per file (7 files max).

### WU2: Curation Cadence Check

After the vault context block in session-bootstrap.sh, add:

```bash
# Check curation cadence
LAST_CURATED=""
if [ -f "$VAULT_PATH/.vault-last-curated" ]; then
    LAST_CURATED=$(cat "$VAULT_PATH/.vault-last-curated" 2>/dev/null)
fi
if [ -z "$LAST_CURATED" ]; then
    VAULT_CONTEXT="${VAULT_CONTEXT}\n  Vault maintenance: Never curated. Consider /vault-curate --quick."
else
    DAYS_SINCE=$(( ($(date +%s) - $(date -d "$LAST_CURATED" +%s 2>/dev/null || echo 0)) / 86400 ))
    if [ "$DAYS_SINCE" -gt 30 ]; then
        VAULT_CONTEXT="${VAULT_CONTEXT}\n  Vault maintenance: Last curated ${DAYS_SINCE} days ago. Consider /vault-curate."
    fi
fi
```

Also update `/vault-curate` Stage 6 (Report) to write the marker:
```bash
echo "$(date +%Y-%m-%d)" > "$VAULT_PATH/.vault-last-curated"
```

### WU3-5: Vault-Query Integration in Commands

Each command gets a new subsection inserted at the appropriate point:

**WU3 — `/blueprint` Stage 1 (Pre-Stage, after the existing suggestions block):**
```markdown
### Vault Awareness (if vault available)

Before starting Stage 1, search the vault for prior knowledge:

1. Source vault config:
   ```bash
   source ~/.claude/hooks/vault-config.sh 2>/dev/null
   ```
2. If vault available, search for notes related to the blueprint topic:
   - Grep vault for the blueprint name and key terms in findings, decisions, patterns
   - Present any matches: "Vault has N notes that may be relevant to this work:"
   - List matches with titles and 1-line summaries
3. If vault unavailable, skip silently (fail-open)

This is advisory — it surfaces context, not gates progress.
```

**WU4 — `/debug` Phase 1 (OBSERVE), appended after the existing observation checklist:**
```markdown
#### Vault Check (if vault available)

Before hypothesizing, check if this issue has been seen before:

1. Source vault config and search for findings related to the error message, component name, or behavior described
2. If matches found: "Vault has prior findings that may be relevant:" with titles
3. This can immediately shortcut debugging if the issue was previously documented

Skip silently if vault unavailable.
```

**WU5 — `/brainstorm` Phase 1 (Analysis), in the Context Review substep:**
```markdown
#### Vault Check (if vault available)

Search the vault for existing knowledge on this problem space:

1. Source vault config and search for findings, decisions, and patterns matching the topic
2. If matches found: "The vault already contains knowledge on this topic:" with titles
3. Read relevant notes to inform the analysis — avoid re-discovering what's already known

Skip silently if vault unavailable.
```

### WU6: Pattern Template

New file `commands/templates/vault-notes/pattern.md`:

```yaml
---
type: pattern
date: {{date}}
project: {{project}}
tags: [pattern]
extracted_from:
  - "[[{{source_finding_1}}]]"
applicability: {{applicability}}
---

# {{title}}

## Pattern

{{description}}

## When to Use

{{when_to_use}}

## Example

{{example}}

## Source Findings

{{source_findings_list}}

## Trade-offs

{{tradeoffs}}
```

### WU7: Pattern Promotion in vault-curate

In Stage 4 (Synthesis), add to the "Proposed action" options in the Synthesis Trellis:

```
[5] Promote to pattern — extract the reusable principle into Engineering/Patterns/
```

When selected:
1. Present the pattern extraction preview:
   ```
   Promoting cluster to pattern:
     Source findings:
       - [[finding-1]]: "Title 1"
       - [[finding-2]]: "Title 2"

     Proposed pattern title: "[extracted principle]"
     Applicability: "[when this pattern applies]"
     Proceed? [Y/n]
   ```
2. Create pattern note using the template (WU6) at `$VAULT_PATH/Engineering/Patterns/YYYY-MM-DD-slug.md`
3. Update source findings to link to the new pattern (add `pattern_link: "[[pattern-name]]"` to frontmatter)
4. Confirm: "Pattern created: [[pattern-name]]. N source findings linked."

Also update vault-curate Stage 6 to write the cadence marker file.

### WU8: Enhanced vault-save Pattern Path

In `/vault-save` Step 5 (Get Content), when `type=pattern`:

```markdown
### Pattern-Specific: Guided Finding Search

When type is `pattern`, before asking for content:

1. Source vault config
2. Ask: "What is the core principle or technique?" (1-2 sentences)
3. Search vault findings for related notes using the principle as search terms
4. If matches found, present: "Found N findings that may relate to this pattern:"
   - List with titles
   - Ask: "Which of these are source examples of this pattern? (comma-separated numbers, or 'none')"
5. Selected findings become `extracted_from` links in the pattern template
6. If no matches or user says 'none', proceed without source links

This guided search helps connect patterns to their evidence base at creation time.
```

### WU9: Vault CLAUDE.md Updates

Add to the vault's `CLAUDE.md` under Structure:

```markdown
- `_Templates/` — Obsidian Templates plugin directory (Obsidian-native, not populated by Claude workflows)
```

Update the Patterns entry:

```markdown
- `Engineering/Patterns/` — Reusable patterns extracted from findings (populated via `/vault-curate` pattern promotion or `/vault-save pattern`)
```

## Success Criteria

| Criterion | How to Verify |
|-----------|---------------|
| Session bootstrap shows project-filtered vault notes | Start new session in a project with vault notes; see project-relevant notes with titles in startup output |
| Session bootstrap shows curation reminder | Start session with no `.vault-last-curated` file; see "Never curated" message |
| Bootstrap completes within 2s even with vault | Time the hook: `time bash hooks/session-bootstrap.sh` |
| Bootstrap works without vault | Unset VAULT_PATH, run hook; no errors, no vault section |
| `/blueprint` searches vault at Stage 1 | Start a blueprint; see vault search results before Stage 1 |
| `/debug` searches vault at Phase 1 | Start debug; see vault check output |
| `/brainstorm` searches vault at Phase 1 | Start brainstorm; see vault check in Context Review |
| Pattern template exists and is valid | File exists at `commands/templates/vault-notes/pattern.md` with expected placeholders |
| `/vault-curate` Stage 4 offers pattern promotion | Run vault-curate; in synthesis, see `[5] Promote to pattern` option |
| `/vault-save pattern` offers guided finding search | Run `/vault-save pattern`; see guided finding search before content capture |
| Vault CLAUDE.md documents both directories | Read vault CLAUDE.md; see `_Templates` and `Engineering/Patterns` documented |

## Failure Modes

| What Could Fail | Detection Method | Recovery Action |
|-----------------|------------------|-----------------|
| Bootstrap vault grep is too slow on WSL→NTFS | Hook output missing vault section (timeout hit) | Reduce grep scope (limit to specific directories, not full vault tree) |
| Project name doesn't match vault `project:` field exactly | Zero project-filtered results despite notes existing | Fall back to global recent (already designed) |
| Pattern template placeholders don't match vault-save/vault-curate hydration | Template renders with `{{raw}}` placeholders visible | Fix placeholder names to match consumers |

## Rollback Plan

1. `git checkout -- hooks/session-bootstrap.sh` (restores original hook)
2. `git checkout -- commands/blueprint.md commands/debug.md commands/brainstorm.md` (restores original commands)
3. `git checkout -- commands/vault-curate.md commands/vault-save.md` (restores original commands)
4. `rm commands/templates/vault-notes/pattern.md` (removes new template)
5. All changes are to source files in this repo; `bash install.sh` propagates the rollback

No state cleanup needed — no persistent state is created by these changes.

## Dependencies (Preconditions)

- [x] Vault is accessible (for testing WU1-2, WU9)
- [x] Existing vault-curate command is complete (it is)
- [x] At least some findings exist in vault with `project:` frontmatter (72 exist)

## Open Questions

- **Project name matching:** The vault uses various `project:` values (`claude-bootstrap`, `project_scout`, `CloudFormation Project`, `s4-docs`). The bootstrap hook uses `basename $(git rev-parse --show-toplevel)`. Do we need fuzzy matching or a project-name alias map? For now, exact match with global fallback seems sufficient.

## Senior Review Simulation

- **They'd ask about:** The 2-second timeout. `grep -rl` across a vault on WSL→NTFS could be slow. Consider caching the project-to-notes mapping in a temp file that refreshes periodically rather than grepping every session start.
- **Non-obvious risk:** Adding vault-query steps to `/brainstorm`, `/debug`, `/blueprint` increases their context footprint. If the vault grows large, these searches could return too many results and add noise. Need result limits (already planned: top 5-7 matches).
- **Standard approach I might be missing:** Obsidian has a JSON index (`.obsidian/cache/`) that could be faster than grep for searching. But that's an Obsidian implementation detail and may not be stable.
- **What bites first-timers:** The `project:` field inconsistency across vault notes. Some use repo basename, some use display names. A normalization step during `/vault-save` and `/end` export would prevent drift.

## Work Graph

```
WU1 ──→ WU2
WU3 (independent)
WU4 (independent)
WU5 (independent)
WU6 ──→ WU7
WU6 ──→ WU8
WU9 (independent)
```

Parallel batches:
- Batch 1: WU1, WU3, WU4, WU5, WU6, WU9 (all independent)
- Batch 2: WU2, WU7, WU8 (depend on batch 1)

Max parallel width: 6
Critical path: WU1 → WU2 or WU6 → WU7
