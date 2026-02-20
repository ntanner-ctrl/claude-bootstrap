# Specification: /vault-curate (Revision 2)

> **Revision 2** — addresses 24 findings from debate challenge (2 critical, 5 high, 12 medium, 5 low).
> See `adversarial.md` for full findings list and `spec.md.revision-1.bak` for previous version.

## Overview

Interactive, multi-stage knowledge triage workflow for the Obsidian vault. Covers all vault content types (findings, blueprints, ideas, sessions, decisions, patterns). Integrates Empirica calibration data when available. Self-tuning frequency recommendations.

Subsumes `/review-findings`, which becomes a deprecated alias pointing to `/vault-curate --quick --section findings`.

## Command Signature

```
/vault-curate                                    # Full 6-stage interactive workflow
/vault-curate --quick                            # Quick pass: Inventory + Triage (findings only) + Report
/vault-curate --section findings|blueprints|ideas|sessions|decisions|patterns
                                                 # Deep dive on one vault area
/vault-curate --project NAME                     # Filter to one project
/vault-curate --skip-health                      # Skip Stage 2 (Health Check)
/vault-curate --skip-synthesis                   # Skip Stage 4 (Synthesis)
```

Flags are composable: `--quick --project claude-bootstrap` works.

## YAML Frontmatter

```yaml
---
description: Use when you need to review, triage, and maintain the Obsidian vault. Covers all content types (findings, blueprints, ideas, sessions, decisions, patterns) for staleness, contradictions, and synthesis. Modifies vault notes — always previews changes before applying.
---
```

## Vault Content Types

The command covers 6 content types, each with type-specific health signals.

**Type authority**: The note's **directory** is authoritative for type classification, not the `type` frontmatter field. A file in `Engineering/Findings/` is always treated as a Finding regardless of its `type` field. If the frontmatter `type` contradicts the directory, log a warning during triage but use the directory-based type for all processing.

| Type | Directory | Health Signals |
|------|-----------|----------------|
| Finding | `Engineering/Findings/` | `empirica_status`, `empirica_confidence`, `empirica_assessed` age |
| Blueprint | `Engineering/Blueprints/` | Linked plan still exists? Execute stage reached? Age vs. project activity |
| Idea | `Ideas/` | Age without action (>30 days = cold), linked to any blueprint? |
| Session | `Sessions/` | Has findings? Has open questions? Links to other notes? |
| Decision | `Engineering/Decisions/` | Referenced by later work? Superseded by newer decisions? |
| Pattern | `Engineering/Patterns/` | Still seen in codebase? Referenced by findings? |

## Stage 1: Inventory

**Always runs. Not skippable.**

### Process

1. **Source vault config and anchor date:**
   ```bash
   source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo "VAULT_ENABLED=$VAULT_ENABLED" && echo "VAULT_PATH=$VAULT_PATH"
   TODAY=$(date +%Y-%m-%d)
   echo "TODAY=$TODAY"
   ```
   If vault unavailable, stop: `"Vault not available. /vault-curate requires an accessible Obsidian vault."`
   Use `$TODAY` as the reference date for all age calculations throughout the session.

2. **Check vault write access** (early detection):
   ```bash
   touch "$VAULT_PATH/.vault-curate-writetest" 2>/dev/null && rm "$VAULT_PATH/.vault-curate-writetest" && echo "WRITABLE" || echo "READ_ONLY"
   ```
   If read-only, warn immediately:
   ```
   ⚠️ Vault is read-only. Running in review-only mode — Stages 1-4 will work normally but Stage 5 (Prune) will be skipped.
   ```

3. **Bulk scan vault directories using bash** (scale-safe):
   Instead of reading each file individually, use a single bash command to extract frontmatter from all notes:
   ```bash
   for dir in "$VAULT_PATH/Engineering/Findings" "$VAULT_PATH/Engineering/Blueprints" "$VAULT_PATH/Engineering/Decisions" "$VAULT_PATH/Engineering/Patterns" "$VAULT_PATH/Ideas" "$VAULT_PATH/Sessions"; do
     for f in "$dir"/*.md 2>/dev/null; do
       [ -f "$f" ] || continue
       echo "=== FILE: $f ==="
       awk '/^---$/{if(c++) exit} c{print}' "$f" 2>/dev/null || echo "PARSE_ERROR"
     done
   done
   ```
   This extracts all YAML frontmatter blocks in a single bash call, avoiding per-file Read tool overhead.

   **Malformed or missing YAML handling**: If a note's frontmatter fails to parse (missing closing `---`, syntax errors, awk outputs `PARSE_ERROR`) OR produces empty output (no `---` delimiters at all), treat the note as **Unassessed** with type inferred from its directory. Do not attempt to infer field values from malformed or absent data. Log: `"Skipping malformed/missing frontmatter: [filename]"`

4. **Filter archived notes**: Exclude any note whose frontmatter contains `archived: true` from all subsequent processing. Count them separately for reporting:
   ```
   Archived (excluded): N notes
   ```

5. **Check for active Empirica session:**
   ```bash
   GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
   if [ -n "$GIT_ROOT" ]; then
     cat "$GIT_ROOT/.empirica/active_session" 2>/dev/null || echo "NO_SESSION"
   else
     echo "NO_SESSION"
   fi
   ```
   If session available, query `mcp__empirica__get_calibration_report` for calibration data.

6. **Apply `--project` filter** (if set): Match notes where the `project` frontmatter field, after lowercasing, exactly equals the lowercased flag value. Notes with no `project` field are **excluded** when `--project` is specified. If zero notes match, report:
   ```
   No notes found for project "[NAME]". Available projects: [list from scan]
   ```
   and exit.

7. **Apply `--section` filter** (if set): Restrict processing to only the specified content type's directory. This filter applies to all stages (Inventory, Health Check, Triage, Synthesis). If zero notes match the section filter, report:
   ```
   No [type] notes found in vault. Available sections with content: [list non-empty types]
   ```
   and exit.

8. **Compute age distribution** using `$TODAY` as reference: notes by age bucket (0-7 days, 8-30 days, 31-90 days, 90+ days).

9. **Compute project distribution**: notes by project name.

10. **Scale warning** (if total active notes > 100):
    ```
    ⚠️ Large vault (N notes). Full curation may take 60-90 minutes.
    Consider: --section [type] or --quick for a shorter session.
    ```

### Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VAULT INVENTORY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Total notes: N
  Empirica session: [session_id or "none — proceeding without calibration"]

  By type:
    Findings:    N
    Blueprints:  N
    Ideas:       N
    Sessions:    N
    Decisions:   N
    Patterns:    N

  By project:
    claude-bootstrap:  N
    project-scout:     N
    [other]:           N

  By age:
    Fresh (0-7d):      N
    Recent (8-30d):    N
    Aging (31-90d):    N
    Old (90+d):        N

  Calibration: [adjustment note or "no Empirica data"]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Stage 2: Health Check

**Skippable with `--skip-health`. Skipped in `--quick` mode.**

**`--section` scoping**: When `--section` is set, only assess health for the specified content type. Skip other type sections entirely.

### Process

For each note (not archived), assess health using type-specific signals:

#### Findings Health

| Status | Criteria |
|--------|----------|
| **Contradicted** | `empirica_status: contradicted` |
| **Stale** | `empirica_status: stale` OR `empirica_assessed` > 30 days ago |
| **Low confidence** | `empirica_confidence` < 0.6 |
| **Partially assessed** | Has SOME but not ALL `empirica_*` fields (e.g., `empirica_assessed` but no `empirica_status`). Treat as **Unassessed** for health scoring (neutral weight) but flag in triage as "incomplete assessment — needs full review." |
| **Unassessed** | No `empirica_*` fields at all |
| **Healthy** | `empirica_status: confirmed` AND confidence >= 0.7 AND assessed < 30 days |

#### Blueprints Health

| Status | Criteria |
|--------|----------|
| **Orphaned** | Blueprint note references a plan directory (look for `.claude/plans/` paths in content) that does not exist at the path specified. If the path is relative or unclear, check the current project's `.claude/plans/` directory. If the plan path cannot be resolved, classify as **Unknown** rather than Orphaned. |
| **Incomplete** | Blueprint summary shows execute stage not reached |
| **Stale** | Blueprint > 60 days old AND no recent session references it |
| **Healthy** | Execute complete, linked plan exists or age < 60 days |

#### Ideas Health

| Status | Criteria |
|--------|----------|
| **Cold** | > 30 days old with no linked blueprint or session referencing it |
| **Acted on** | Has a linked blueprint or referenced in a session log |
| **Fresh** | < 30 days old |

#### Sessions Health

| Status | Criteria |
|--------|----------|
| **Sparse** | No findings, no open questions, no links |
| **Rich** | Has findings AND links to other notes |
| **Isolated** | No backlinks from other notes |

#### Decisions Health

| Status | Criteria |
|--------|----------|
| **Superseded** | Claude identifies a newer decision addressing the same topic based on semantic similarity of titles, overlapping tags, and same `component` frontmatter field (if present). When proposing "superseded", Claude MUST state its reasoning: "This decision appears superseded because [newer decision] also addresses [topic] and is dated [N] days later." |
| **Unreferenced** | No other notes link to this decision |
| **Active** | Referenced by findings or blueprints within last 90 days |

#### Patterns Health

| Status | Criteria |
|--------|----------|
| **Unused** | No findings or sessions reference this pattern |
| **Active** | Referenced by recent work |

### Vault Health Score

Compute an overall health score (0-100) using weighted status categories:

```
healthy_weight    = 1.0   (confirmed, active, fresh, rich, acted_on)
neutral_weight    = 0.5   (unassessed, incomplete, unreferenced, isolated)
unhealthy_weight  = 0.0   (contradicted, stale, orphaned, cold, superseded, sparse, unused)

if total_count == 0:
    score = "N/A"  # no active notes to assess
else:
    weighted_sum = (healthy_count * 1.0) + (neutral_count * 0.5) + (unhealthy_count * 0.0)
    score = round(100 * weighted_sum / total_count)
```

When `total_count == 0` (empty vault or all archived), skip the health score and display `"Health score: N/A (no active notes)"`. Also skip the frequency recommendation in Stage 6.

This gives useful gradients at all vault sizes:
- A vault of 100% unassessed notes scores 50 (neutral, not zero)
- A vault of 100% healthy notes scores 100
- A vault of 50% healthy + 50% unhealthy scores 50
- A vault with mostly unassessed + some healthy scores 50-75

### Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VAULT HEALTH CHECK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Overall health: NN/100

  Needs attention:
    Findings:
      🔴 Contradicted: N
      🟠 Stale: N
      🟡 Low confidence: N
      ⚪ Unassessed: N

    Blueprints:
      🔴 Orphaned: N
      🟠 Stale: N
      🟡 Incomplete: N

    Ideas:
      🟠 Cold (>30d, no action): N

    Sessions:
      🟡 Sparse: N
      ⚪ Isolated: N

    Decisions:
      🟠 Superseded: N
      ⚪ Unreferenced: N

    Patterns:
      ⚪ Unused: N

  Healthy notes: N/N total (X%)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Stage 3: Triage

**Always runs (core stage). In `--quick` mode, only processes findings.**

### Grouping Strategy

Notes needing attention are grouped for efficient batch review. Grouping order:

1. **By project** (primary grouping) — review all notes for one project together
2. **By type** (secondary grouping within project) — findings first, then blueprints, ideas, etc.
3. **By severity** (tertiary) — contradicted/orphaned first, then stale, then unassessed

### Interactive Flow

For each group, present the group header:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Reviewing: [project] / [type] (N notes)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

For each note in the group:

1. **Show the note**: Display title, date, project, current status, and a 2-3 line summary of content
2. **Show context**:
   - For findings: search codebase for related code, check recent git history
   - For blueprints: check if linked plan directory exists, check execute status
   - For ideas: check if any blueprint or session references it
   - For decisions: check if newer decisions exist for same topic
   - For sessions: check finding count, link count
   - For patterns: check codebase for usage
3. **Assess**: Propose an updated status with reasoning:
   - "This finding appears **still valid** — code at X:Y confirms it"
   - "This blueprint is **orphaned** — `.claude/plans/auth-redesign/` no longer exists"
   - "This idea has been **acted on** — blueprint `vault-data-pipeline` implements it"
4. **Offer verdict** (type-appropriate):

**Findings verdict options:**
```
  [1] Confirm — mark as confirmed, update confidence
  [2] Update — edit content, then confirm
  [3] Contradict — mark as contradicted, add note
  [4] Stale — needs deeper investigation later
  [5] Skip — leave as-is (adds last_reviewed date to frontmatter)
  [6] Archive — flag as archived (remains in place)
```

**Note on Skip**: Even when skipping, add `last_reviewed: YYYY-MM-DD` to frontmatter so future runs can distinguish "never triaged" from "deliberately skipped." This applies to all content types, not just findings.

**Blueprints verdict options:**
```
  [1] Current — blueprint is still relevant
  [2] Completed — work was done, mark as complete
  [3] Abandoned — mark as abandoned with reason
  [4] Skip — leave as-is
  [5] Archive — flag as archived
```

**Ideas verdict options:**
```
  [1] Still relevant — keep, update if needed
  [2] Acted on — link to blueprint/finding that implements it
  [3] Superseded — another approach was taken
  [4] Skip — leave as-is
  [5] Archive — flag as archived
```

**Sessions verdict options:**
```
  [1] Enriched — add missing links or findings references
  [2] Complete — no action needed
  [3] Skip — leave as-is
  [4] Archive — flag as archived (old, sparse sessions)
```

**Decisions verdict options:**
```
  [1] Still active — decision is current
  [2] Superseded — link to newer decision
  [3] Skip — leave as-is
  [4] Archive — flag as archived
```

**Patterns verdict options:**
```
  [1] Active — still in use
  [2] Evolved — update to reflect current practice
  [3] Skip — leave as-is
  [4] Archive — flag as archived
```

### Batch Operations

After presenting each group, offer batch option:

```
Group summary: N notes reviewed
  Batch options:
    [B1] Confirm all remaining in this group
    [B2] Skip all remaining in this group
    [B3] Continue one-by-one
```

This prevents fatigue when many notes in a group are clearly healthy.

### Triage Checkpoint (Persistence)

Verdicts are persisted incrementally to prevent loss on session interruption. After each verdict is given:

1. Write the verdict to a checkpoint file using the Bash tool. Use the vault path if writable, otherwise fall back to the project directory. Escape note paths for valid JSON (replace `\` with `\\` and `"` with `\"`):
   ```bash
   CHECKPOINT_DIR="$VAULT_PATH"
   [ -w "$VAULT_PATH" ] || CHECKPOINT_DIR="${GIT_ROOT:-.}/.claude"
   SAFE_PATH=$(echo '[note_path]' | sed 's/\\/\\\\/g; s/"/\\"/g')
   echo "{\"path\":\"$SAFE_PATH\",\"verdict\":\"[verdict]\",\"confidence\":[value],\"timestamp\":\"[ISO-8601]\"}" >> "$CHECKPOINT_DIR/.vault-curate-checkpoint.jsonl"
   ```

2. On next `/vault-curate` invocation, check for an existing checkpoint:
   ```bash
   if [ -f "$VAULT_PATH/.vault-curate-checkpoint.jsonl" ]; then
     AGE=$(( ($(date +%s) - $(stat -c %Y "$VAULT_PATH/.vault-curate-checkpoint.jsonl")) / 3600 ))
     echo "CHECKPOINT_EXISTS age_hours=$AGE"
   fi
   ```

3. If checkpoint exists, check age and offer appropriate action:

   **If less than 24 hours old**, offer to resume:
   ```
   Found checkpoint from [N] hours ago with [N] verdicts.
     [1] Resume — skip already-triaged notes, continue from where you left off
     [2] Start fresh — discard checkpoint and begin new curation
   ```

   **If 24 hours or older**, warn and offer to discard:
   ```
   Found stale checkpoint from [N] hours ago with [N] verdicts.
   This checkpoint is too old to resume reliably.
     [1] Discard and start fresh
     [2] Resume anyway (verdicts may not match current vault state)
   ```

4. When Stage 5 (Prune) completes successfully, delete the checkpoint file.

### Conversation Mode

Unlike the current `/review-findings` which is strictly checklist-based, triage encourages discussion:

- After showing context, pause for user input before proposing a verdict
- If the user says "tell me more about this" — expand: show full note content, deeper codebase search, related notes
- If the user says "what else is related?" — search vault for notes with overlapping tags, project, or keywords
- If the user proposes a different interpretation — adapt the verdict accordingly

**Verdict closure protocol**: After any open-ended discussion about a note, Claude MUST re-present the numbered verdict options explicitly. A note's triage is only complete when the user selects a numbered option (or says "skip"). Conversational statements like "yeah, archive it" should be confirmed: "Understood — selecting [6] Archive. Correct?"

This is the "back-and-forth" that makes this a curation *conversation* rather than a checklist.

## Stage 4: Synthesis

**Skippable with `--skip-synthesis`. Skipped in `--quick` mode.**

### Process

After triage, Claude analyzes the **full vault state** — not just notes acted on in this session. Notes that were skipped in Stage 3 retain their prior status and are included in synthesis based on existing frontmatter. This prevents false gaps from incomplete triage.

**Caveat when triage was partial**: If >50% of notes were skipped or batch-skipped in Stage 3, prepend synthesis output with: `"Note: Synthesis is based on partial triage (N% of notes were skipped). Gap detection may reflect triage coverage rather than actual knowledge gaps."`

Claude analyzes confirmed/updated findings looking for higher-level patterns:

1. **Cluster detection**: Group confirmed findings by overlapping tags, keywords, and project. Identify clusters of 3+ findings that share a theme.

2. **Cross-project patterns**: Look for findings from different projects that describe the same underlying pattern or principle. Example: "fail-open hook design" appearing in both `claude-bootstrap` and `project-scout`.

3. **Contradiction detection**: Identify findings that contradict each other (e.g., one says "always use X" and another says "X causes problems in context Y").

4. **Gap detection**: Based on the distribution of findings across projects and topics, identify areas with suspiciously few findings. Example: "You have 15 findings about hooks but zero about agent design — is that intentional or a blind spot?"

5. **Trend analysis**: If multiple curation sessions have occurred, compare: are certain topics accumulating stale findings faster? Are some projects generating findings at a higher rate?

### Synthesis Trellis

For each synthesis observation, Claude presents it within a structured frame:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SYNTHESIS OBSERVATION [N of M]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Type: [Cluster | Cross-Project | Contradiction | Gap | Trend]

  Observation: [2-3 sentence description]

  Evidence:
    - [[finding-1]] (project-a)
    - [[finding-2]] (project-b)
    - [N more related notes]

  Proposed action:
    [1] Create meta-finding — capture this as a new finding note
    [2] Merge findings — combine N findings into one consolidated note
    [3] Note and continue — interesting but no action needed
    [4] Dismiss — not actually a meaningful pattern

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Meta-Finding Creation

When the user selects "Create meta-finding", create a new finding note directly (inline, not via `/vault-save`):

- **Location**: `$VAULT_PATH/Engineering/Findings/YYYY-MM-DD-[slug].md`
- **Title**: synthesis-derived (e.g., "Fail-open pattern is universal across hook designs")
- **Frontmatter**:
  ```yaml
  type: finding
  date: YYYY-MM-DD
  project: [primary project, or "cross-project" if multi-project]
  category: synthesis
  tags: [synthesis, source project tags]
  empirica_confidence: 0.7
  empirica_status: active
  synthesis_source: true
  synthesized_from:
    - "[[source-finding-1]]"
    - "[[source-finding-2]]"
  ```
- **Content**: the observation text + evidence links as wiki-links
- **Template**: Use the standard finding note structure (title, content, Source section, Implications section)

### Merge Findings

When the user selects "Merge findings — combine N findings into one consolidated note":

**IMPORTANT: Merge NEVER deletes source notes.** Source notes are archived in place.

#### Merge Process

1. **Present merge preview** listing all source notes:
   ```
   Merging N findings into one consolidated note:
     Sources:
       - [[finding-1]]: "Title 1" (project-a, confidence: 0.8)
       - [[finding-2]]: "Title 2" (project-a, confidence: 0.7)
       - [[finding-3]]: "Title 3" (project-b, confidence: 0.6)

     Proposed merged title: "[synthesized title]"
     Proceed? [Y/n]
   ```
   If the user answers **n**, cancel the merge and return to the synthesis observation frame, re-presenting the four action options.

2. **Create the merged note** at `$VAULT_PATH/Engineering/Findings/YYYY-MM-DD-[slug].md`:
   ```yaml
   type: finding
   date: YYYY-MM-DD
   project: [primary project, or "cross-project"]
   category: synthesis
   tags: [union of all source tags, plus "merged"]
   empirica_confidence: [average of source confidences]
   empirica_status: active
   synthesis_source: true
   merged_from:
     - "[[source-finding-1]]"
     - "[[source-finding-2]]"
     - "[[source-finding-3]]"
   ```
   Content: consolidated text incorporating key points from all sources, with wiki-links back to each source.

3. **Archive each source note** (do NOT delete): Add to each source's frontmatter:
   ```yaml
   archived: true
   archived_date: YYYY-MM-DD
   archived_reason: "Merged into [[merged-note-title]]"
   merged_into: "[[merged-note-title]]"
   ```

4. **Confirm**: `"Merged N findings → [[merged-note-title]]. Source notes archived (not deleted)."`

## Stage 5: Prune

**Always runs. Applies decisions from Stages 3-4.**

### Process

For each note with a verdict from triage or synthesis:

1. **Confirmed/Active/Current** — Update frontmatter:
   ```yaml
   empirica_assessed: YYYY-MM-DD
   empirica_status: confirmed
   empirica_confidence: [updated value]
   empirica_session: [current session ID]
   ```

2. **Updated/Enriched/Evolved** — Edit note content as discussed during triage, then update frontmatter as above.

3. **Contradicted** — Update frontmatter:
   ```yaml
   empirica_status: contradicted
   empirica_confidence: [low value]
   empirica_assessed: YYYY-MM-DD
   ```
   Add note to Implications section:
   ```markdown
   > ⚠️ Contradicted during vault curation on YYYY-MM-DD — [brief reason]
   ```

4. **Archived** — Add frontmatter flag:
   ```yaml
   archived: true
   archived_date: YYYY-MM-DD
   archived_reason: [reason from verdict]
   ```
   Note remains in its original location. Future inventory scans exclude notes with `archived: true`.

5. **Acted on (ideas)** — Update frontmatter:
   ```yaml
   acted_on: true
   acted_on_date: YYYY-MM-DD
   acted_on_link: "[[linked-blueprint-or-finding]]"
   ```

6. **Superseded (decisions)** — Update frontmatter:
   ```yaml
   superseded: true
   superseded_by: "[[newer-decision]]"
   superseded_date: YYYY-MM-DD
   ```

7. **Log to Empirica** (if session active): Call `mcp__empirica__finding_log` for each updated note. For archived notes, call `mcp__empirica__finding_log` with `category: "archived"` and the archive reason (NOT `deadend_log` — archiving is curation, not a dead end).

### Interruption Recovery

If the session is interrupted during Stage 5 (partial apply):
- Notes already updated are in a **better** state than before (each update is independent and self-contained)
- Notes not yet updated remain unchanged — they are NOT corrupted
- The triage checkpoint file (`$VAULT_PATH/.vault-curate-checkpoint.jsonl`) still exists, so the next `/vault-curate` run can resume
- Stage 6 (Report) should still render if possible, showing how many changes were applied vs. planned

There is no rollback mechanism because partial application is not harmful — each note is independent.

### Dry-Run Preview

Before applying changes, present a summary:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PRUNE PREVIEW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Changes to apply:

    Update frontmatter:     N notes
    Edit content:           N notes
    Archive (flag):         N notes
    Create meta-findings:   N notes

  [1] Apply all
  [2] Review changes one-by-one
  [3] Cancel (no changes applied)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Stage 6: Report

**Always runs. Not skippable.**

### Process

1. Compute final statistics
2. Compare vault health before vs. after (using Stage 2 baseline, if available)
3. Estimate next recommended curation date

### Frequency Recommendation

Calculate based on observed decay rate. Skip entirely if `total_count == 0`:

```
if total_count == 0:
    skip frequency recommendation; display "N/A (no active notes)"
    return

decay_rate = (stale_count + contradicted_count) / total_count

# Use MEDIAN of empirica_assessed dates (not most recent) to avoid
# single-note bias. Only consider notes that have the field.
assessed_notes = [n for n in notes if n.empirica_assessed exists]
fraction_never_assessed = 1 - (len(assessed_notes) / total_count)

if assessed_notes:
    median_assessed_date = median(assessed_notes.empirica_assessed)
    days_since_median_curation = TODAY - median_assessed_date
else:
    days_since_median_curation = 999  # never curated

if decay_rate > 0.3:
    recommend = "1-2 weeks"
elif decay_rate > 0.15:
    recommend = "2-4 weeks"
elif decay_rate > 0.05:
    recommend = "monthly"
else:
    recommend = "quarterly"

# Adjust for vault growth rate
# notes_created_since_last_curation = count of notes whose `date` field
# is after median_assessed_date (or all notes if no assessed dates exist).
# This approximates how many notes entered the vault since the last curation pass.
notes_created_since_last_curation = count(notes where date > median_assessed_date)

if notes_created_since_last_curation > 20:
    if recommend == "quarterly":
        recommend = "monthly"
    elif recommend == "monthly":
        recommend = "2-4 weeks"
    elif recommend == "2-4 weeks":
        recommend = "1-2 weeks"
    # "1-2 weeks" is already the minimum — no change

# Adjust for high fraction never assessed
if fraction_never_assessed > 0.5:
    # Apply same tier bump — lots of unreviewed content needs attention
    if recommend == "quarterly":
        recommend = "monthly"
    elif recommend == "monthly":
        recommend = "2-4 weeks"
    elif recommend == "2-4 weeks":
        recommend = "1-2 weeks"
```

### Output

**Health comparison**: Only show "Before/After" when Stage 2 ran. When Stage 2 was skipped (`--skip-health` or `--quick`), omit the health comparison section entirely.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CURATION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Session summary:
    Notes reviewed:     N
    Confirmed:          N
    Updated:            N
    Contradicted:       N
    Archived:           N
    Merged:             N (source notes archived)
    Skipped:            N
    Meta-findings:      N (new synthesis notes)

  [If Stage 2 ran:]
  Vault health:
    Before: NN/100
    After:  NN/100 (+NN)

  [If Stage 4 ran:]
  Synthesis:
    Clusters found:     N
    Cross-project:      N
    Contradictions:     N
    Gaps identified:    N

  Next curation:
    Recommended in ~N weeks (based on N% decay rate)
    Suggested date: YYYY-MM-DD
    [If fraction_never_assessed > 0.3:]
    Note: N% of vault has never been assessed — consider a focused
    --section pass to build baseline coverage.

  Time spent: ~N minutes

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Log to Empirica

If session active, call `mcp__empirica__finding_log` with:
- finding: "Vault curation complete: N notes reviewed, health NN→NN, next curation ~YYYY-MM-DD"
- category: "vault-curation"

## Quick Mode (`--quick`)

When `--quick` is passed:

1. **Inventory** runs (always)
2. **Health Check** skipped
3. **Triage** runs but ONLY for findings (same behavior as current `/review-findings`)
4. **Synthesis** skipped
5. **Prune** runs (applies triage decisions)
6. **Report** runs (abbreviated — no health comparison, no synthesis section)

This provides similar functionality to the original `/review-findings` command, though with an added Inventory stage and updated Report format. The deprecated `/review-findings` redirects here.

## Fail-Soft Behavior

- **No vault**: Stop immediately with helpful error
- **No Empirica session**: Proceed without calibration data. Skip calibration-dependent features (confidence adjustment, session logging). Note in inventory: "No Empirica session — proceeding without calibration data"
- **Vault on unreachable path**: Stop with error (e.g., NTFS path not mounted in WSL)
- **Read-only vault**: Detected at Stage 1 (write test). Allow inventory, health check, triage, and synthesis in review-only mode. Skip Stage 5 (Prune) entirely with: "Vault is read-only — changes were not applied. Verdicts are saved in the checkpoint file for when write access is restored."
- **Individual note read failure**: Skip note, log warning, continue with remaining notes
- **Empirica call failure mid-session**: Log warning, continue without Empirica for remainder

## Deprecation: /review-findings

The existing `commands/review-findings.md` is replaced with a deprecation notice:

```yaml
---
description: "DEPRECATED: Use /vault-curate instead. For equivalent behavior, use /vault-curate --quick --section findings."
---
```

Body: brief redirect message explaining the migration.

## Work Units

### WU1: Create `commands/vault-curate.md`
The main command file implementing all 6 stages. This is the bulk of the work.
**Depends on:** nothing
**Estimated size:** ~300-400 lines of markdown

### WU2: Deprecate `commands/review-findings.md`
Replace content with deprecation notice and redirect.
**Depends on:** WU1 (new command must exist first)
**Estimated size:** ~15 lines

### WU3: Update `commands/README.md`
Add vault-curate entry, mark review-findings as deprecated.
**Depends on:** WU1
**Estimated size:** ~5 lines changed

### WU4: Update `README.md`
Add vault-curate to Commands at a Glance, update command count (45→46).
**Depends on:** WU1
**Estimated size:** ~5 lines changed

### WU5: Update `.claude/CLAUDE.md`
Update command count (45→46).
**Depends on:** WU1
**Estimated size:** ~2 lines changed

### WU6: Update `install.sh`
Update command count in output message.
**Depends on:** WU1
**Estimated size:** ~2 lines changed

### WU7: Update cross-references
Any commands that reference `/review-findings` should reference `/vault-curate` instead (or note both).
**Depends on:** WU1, WU2
**Estimated size:** ~5-10 lines across 2-3 files

## Work Graph

```
WU1 ─┬─→ WU2
     ├─→ WU3
     ├─→ WU4
     ├─→ WU5
     ├─→ WU6
     └─→ WU7 (also depends on WU2)
```

WU1 is the critical path. WU2-WU6 can be parallelized after WU1 completes. WU7 depends on both WU1 and WU2.

Width: 5 (WU2-WU6 parallel)
Critical path length: 2 (WU1 → WU7)
