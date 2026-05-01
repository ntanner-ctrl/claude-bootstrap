# Specification: Meta-Blueprint Coordination

## Overview

Three components that add lifecycle completion and cross-blueprint coordination to claude-sail:

1. **Debrief Stage** — Mandatory Stage 8 in the blueprint workflow
2. **`/link-blueprint` Command** — Parent/child relationship declaration
3. **Commit-Time Signal** — Plugin-enhancer integration for blueprint-aware commits

## Component 1: Debrief Stage

### Position in Blueprint Lifecycle

Debrief is Stage 8, after Execute (Stage 7). It uses `"skippable": false` in the stage schema as a semantic signal, and Stage 7 completion displays a regression-warning prompt surfacing the pending debrief. This is tier 2.5 enforcement (stronger than prose, weaker than a shell hook) — honest about what the toolkit can enforce without adding dependencies.

> **Enforcement tier honesty**: We do NOT claim debrief is "mandatory" (that implies hook enforcement). We claim it is "structurally expected" — the `completed:true` flag is only valid when `stages.debrief.status === "complete"`, and Stage 7 completion actively prompts the user to proceed to debrief.

```
Stage 7: Execute    → Implementation
Stage 8: Debrief    → Completion ceremony (NEW)
```

The existing post-implementation reflection (currently inline in Stage 7 completion) is absorbed into debrief. Reflection becomes a sub-step of debrief, not a standalone prompt.

### Debrief Flow

When Stage 7 (Execute) is marked complete, blueprint transitions to Stage 8 automatically:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BLUEPRINT: [name] │ Stage 8 of 8: Debrief
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Completing this blueprint. Capturing final state.

  1. SHIP REFERENCE
     Commit hash(es) that delivered this work:
     > [auto-detected from commits.jsonl if available,
        otherwise prompt user]

  2. SPEC DELTA
     What changed from the original specification?
     [Auto-diff: read spec.diff.md if it exists (created
      on regression), otherwise summarize regression_log
      entries from state.json. If neither exists, mark
      as "no tracked changes — spec stable through
      implementation."]
     > [presented for user confirmation/amendment]

  3. DEFERRED ITEMS
     What was explicitly punted and why?
     > [user input — list items with reasons]

  4. DISCOVERIES
     What did this blueprint reveal that wasn't anticipated?
     > [user input — things learned during implementation]

  5. REFLECTION (absorbed from existing post-implementation)
     - What assumption was wrong?
     - What was harder/easier than expected?
     - What would you tell the next planner?

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Debrief for Linked Blueprints (Meta-Aware)

When `state.json` has a `parent` field (this is a sub-blueprint), debrief adds:

```
  6. SIBLING IMPACT
     Do any sibling blueprints need to know about your discoveries?
     [List siblings from parent's meta_units map]
     > [user selects affected siblings + describes impact]

  7. META UPDATE
     Updating parent blueprint manifest...
     [Auto-update parent's meta_units with:
       - this blueprint's status → complete
       - ship_commit from step 1
       - discoveries from step 4
       - sibling impacts from step 6]

     Before attempting parent update, verify bidirectional
     consistency. If half-linked (child has parent ref but
     parent's meta_units doesn't list this child), repair
     the link first, then proceed with the update.

     If parent blueprint's state.json is unreachable or parent
     has `completed: true`, META UPDATE is skipped with warning:
       "Parent [name] is unreachable/completed — update recorded
        locally in debrief.md but parent was not modified."
```

### Debrief Prerequisites

Debrief (Stage 8) is only accessible after execute completes:
- **Gate:** `stages.execute.status === "complete"` must be true before debrief can start
- **Invariant (updated):** `completed: true` requires BOTH `stages.execute.status === "complete"` AND `stages.debrief.status === "complete"`
- If debrief is attempted on an un-executed blueprint, display: "Debrief requires Stage 7 (Execute) to be complete. Current status: [execute.status]"

### Session Recovery for Debrief

On blueprint resume (`/blueprint [name]`), if `stages.execute.status === "complete"` and (`stages.debrief` is absent OR `stages.debrief.status !== "complete"`), display the Stage 7→8 transition prompt as if Stage 7 had just completed. This ensures session breaks between execute and debrief are recoverable.

Additionally: when writing Stage 7 completion to state.json, also write `stages.debrief: { "status": "pending" }` to create a persistent breadcrumb that survives session breaks.

### Debrief Output

Written to `.claude/plans/[name]/debrief.md`:

```markdown
# Debrief: [blueprint name]

## Ship Reference
- Commit(s): [hash list]
- Date: [completion date]

## Spec Delta
[Summary of what changed from original spec]
- Revisions: [count]
- Key changes: [list]

## Deferred Items
- [item]: [reason]

## Discoveries
- [discovery]

## Reflection
### Wrong Assumptions
- [list]

### Difficulty Calibration
- Harder: [list]
- Easier: [list]

### Advice for Next Planner
- [guidance]

## Sibling Impact (if linked)
- [sibling]: [impact description]
```

### State Transitions on Debrief

1. `stages.debrief.status` → `"complete"`
2. `stages.debrief.completed_at` → timestamp
3. Blueprint overall status: add `"completed": true` and `"completed_at"` to state.json root
4. If linked: update parent's `meta_units[this_blueprint].status` → `"complete"`

**Invariant:** `completed: true` is ONLY valid when `stages.debrief.status === "complete"`. Any other write path that sets `completed: true` is a schema violation. This is the derivation rule that backs the debrief gate — even though enforcement is behavioral (tier 2.5), the invariant is structural.

### Context-Aware Debrief

If the session has been through >5 blueprint stages, prefer manual input over auto-detection for debrief steps 1-2 (ship reference, spec delta). Ask the user to provide commit hashes and spec delta directly rather than attempting to auto-read and synthesize from files that may have been compacted. Auto-detection is a convenience, not a requirement — manual fallbacks are first-class.

### Stage 7 → Stage 8 Transition Prompt

The debrief prompt must be visually SEPARATE from the existing completion ceremony (implementation options, TDD guidance, etc.). It should appear AFTER a clear break, not appended to the dense completion block. Stage 7 completes → completion options shown → clear separator → debrief transition prompt.

When Stage 7 (Execute) completes, display (AFTER implementation options):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Implementation complete. Debrief pending.

  Blueprint [name] has completed execution but is
  not yet closed. Run debrief to:
    - Record ship references
    - Capture spec delta and discoveries
    - Mark blueprint complete
    [If linked: - Update parent blueprint status]

  Proceeding to Stage 8: Debrief...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Re-opening Completed Blueprints

There is no `--reopen` mechanism. If a completed blueprint's assumptions change, create a new blueprint and link it as a successor via `/link-blueprint`. This is intentional — the problem this spec solves is blueprints that never close, not ones that close too early.

### Vault Export on Debrief

After debrief completes, export to vault (extends existing vault export):
- Blueprint summary note (existing pattern) now includes debrief data
- Debrief discoveries exported as individual findings if significant

### Backward Compatibility

- New `debrief` stage added to state.json `stages` object
- Existing blueprints without `debrief` stage: treated as pre-debrief
- No migration needed — debrief only applies to blueprints reaching Stage 8

## Component 2: `/link-blueprint` Command

### Purpose

Declares parent/child relationships between blueprints within the same project. User-initiated, explicit — no auto-detection.

### Usage

```bash
# Declare a sub-blueprint relationship
/link-blueprint scanner-refactor --parent march-roadmap

# Declare with work-unit ID from parent's spec
/link-blueprint scanner-refactor --parent march-roadmap --unit WU-2

# View relationships for a blueprint
/link-blueprint --show march-roadmap

# Unlink (if declared in error)
/link-blueprint scanner-refactor --unlink
```

### Behavior

**On link:**
1. Validate both blueprints exist in `.claude/plans/`
2. Add `parent` field to child's state.json:
   ```json
   {
     "parent": {
       "blueprint": "march-roadmap",
       "unit_id": "WU-2"
     }
   }
   ```
3. Add/update `meta_units` in parent's state.json:
   ```json
   {
     "meta_units": {
       "scanner-refactor": {
         "unit_id": "WU-2",
         "status": "in_progress",
         "linked_at": "2026-03-25T13:00:00Z",
         "discoveries": [],
         "ship_commit": null
       }
     }
   }
   ```
4. Display confirmation with relationship summary

**On show:**

If `meta_units` key is absent or empty, display: "No linked children for [name]. Use `/link-blueprint [child] --parent [name]` to add one."

Otherwise:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  META-BLUEPRINT: march-roadmap
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Units:
    WU-2  scanner-refactor    ● complete   (shipped: 9a894c5)
    WU-3  heartbeat-settings  ● complete   (shipped: 7f1f722)
    WU-4  openvas-integration ◐ in_progress
    WU-5  credential-delivery ○ not started

  Discoveries surfaced:
    - scanner-refactor: "stdlib constraint lifted"
    - heartbeat-settings: "fetch-write-clear pattern confirmed"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**On unlink:**
1. Remove `parent` from child's state.json
2. Remove child's entry from parent's `meta_units`
3. Display confirmation

### Validation Rules

- Blueprint name argument must be non-empty; reject with error if missing or whitespace-only
- Cannot link a blueprint to itself
- Cannot create cycles in the parent chain — checked transitively by traversing all ancestors (DFS), not just pairwise
- If any ancestor's state.json is unreadable during cycle detection, treat traversal as complete at that point (fail-open) and log warning
- Parent blueprint must exist
- Child blueprint must exist
- Parent blueprint must NOT have `completed: true` (block — completed parent's debrief is already written)
- Warn (don't block) if child blueprint is already complete (retroactive documentation is valid)
- Unlink is blocked when either party has `completed: true` — use `--force` to override (logged)

### Half-Linked State Recovery

If `/link-blueprint` partially fails (child updated but parent not, or vice versa):
- Detected at `/link-blueprint --show` or blueprint resume time
- Surface: "Half-linked state detected: [child] references parent [parent] but parent's meta_units doesn't include [child]"
- Offer repair: re-run the missing write

### Command Frontmatter

```yaml
description: Use when a blueprint is part of a larger coordinated plan. Declares parent/child relationships between blueprints for meta-coordination.
arguments:
  - name: name
    description: "Blueprint name to link (the child)"
    required: false
  - name: parent
    description: "Parent blueprint name"
    required: false
  - name: unit
    description: "Work unit ID from parent's spec (e.g., WU-2)"
    required: false
  - name: show
    description: "Show relationships for a blueprint"
    required: false
  - name: unlink
    description: "Remove parent relationship"
    required: false
```

## Component 3: Commit-Time Blueprint Signal

### Design Decision: Plugin-Enhancer Pattern

`/commit` is provided by the `commit-commands` plugin, not sail core. The signal is implemented as a plugin-enhancer capability slot, not a direct modification.

### New Capability Slot

Add to `plugin-enhancers.md` Section 2:

| Slot | What It Provides | Phase | Used At |
|------|-----------------|-------|---------|
| `lifecycle:commit-signal` | Blueprint-aware commit enhancement | Phase 2 | `/commit` (commit-commands plugin) |

### Plugin-to-Slot Mapping

Add to `plugin-enhancers.md` Section 3:

```
### commit-commands (Phase 2 — lifecycle only)

**Fills:** `lifecycle:commit-signal`
**Detection:** Check installed_plugins.json for key with prefix "commit-commands"

**Enhancement:**
When commit-commands plugin is detected AND the session-level flag `SAIL_BLUEPRINT_ACTIVE` is set:

The commit signal uses a **session-flag opt-in** model, not universal polling. This avoids prompt fatigue from interrupting every commit (10-20 per sprint) which trains users to dismiss reflexively.

**Activation:** User sets `SAIL_BLUEPRINT_ACTIVE=blueprint-name` at session start (or blueprint's execute stage suggests it). The flag is session-scoped — it does not persist across sessions.

1. After commit executes successfully:
   - Read `SAIL_BLUEPRINT_ACTIVE` environment variable
   - If set, append to `.claude/plans/[name]/commits.jsonl`:
     ```json
     {"hash": "<commit-hash>", "message": "<first-line>", "timestamp": "<ISO-8601>", "work_units": []}
     ```
   - Optionally prompt for work unit IDs if the commit message doesn't contain them

2. If `SAIL_BLUEPRINT_ACTIVE` is not set: no prompt, no logging, zero friction

**Deduplication:** On read (during debrief), deduplicate entries by commit hash before presenting. If commits.jsonl exists but is empty or contains unparseable lines, treat as missing (fall back to manual commit hash entry). Unparseable lines are silently skipped.

**Directory validation:** If `.claude/plans/$SAIL_BLUEPRINT_ACTIVE/` does not exist when the commit signal fires, log a warning and skip the append. Do not create the directory. Blueprint's execute stage should suggest unsetting the variable on completion/abandonment.

**Graceful degradation:** If commit-commands plugin is not installed, this enhancement
is silently skipped. Blueprint debrief will fall back to asking for commit hashes manually.
```

### commits.jsonl Format

```json
{"hash": "abc1234", "message": "feat: add scanner base class", "timestamp": "2026-03-20T10:00:00Z", "work_units": ["WU-2"]}
{"hash": "def5678", "message": "feat: implement 18 scanner subclasses", "timestamp": "2026-03-20T14:00:00Z", "work_units": ["WU-2"]}
```

One line per commit. Read by debrief to auto-populate ship references.

### Fallback When Plugin Not Available

If commit-commands plugin is not installed:
- No commit-time prompt (silently skipped)
- Debrief (Stage 8) asks user for commit hashes directly
- No degradation in coordination functionality — just less automation

## Schema Changes

### state.json Extensions

New optional fields at root level:

```json
{
  "parent": {
    "blueprint": "parent-name",
    "unit_id": "WU-2"
  },
  "meta_units": {
    "child-name": {
      "unit_id": "WU-2",
      "status": "in_progress",
      "linked_at": "2026-03-25T13:00:00Z",
      "discoveries": [],
      "ship_commit": null
    }
  },
  "completed": false,
  "completed_at": null
}
```

New stage in `stages` object:

```json
{
  "stages": {
    "debrief": {
      "status": "pending",
      "completed_at": null,
      "confidence": null,
      "confidence_note": null,
      "ship_commits": [],
      "spec_delta_summary": null,
      "deferred_items": [],
      "discoveries": [],
      "sibling_impacts": []
    }
  }
}
```

### docs/PLANNING-STORAGE.md Extensions

- **Fix `current_stage` type**: Change from `"type": "integer"` to `"type": "string"` (matching actual usage across all live state.json files — current_stage has always been a stage name string like "execute", "challenge", not an integer). Add `"debrief"` to the enum of valid values. Remove `minimum`/`maximum` constraints. This is a pre-existing documentation drift correction, not a new change.
- Add `debrief` to the stage schema `$defs` with `"skippable": false`
- Add `parent`, `meta_units`, `completed`, `completed_at` to root properties
- Add `commits.jsonl` schema to file naming conventions (with field types: hash string required, message string required, timestamp ISO-8601 required, work_units string array optional)
- Add `debrief.md` to artifact table
- Add invariant note: `completed: true` requires `stages.debrief.status === "complete"`
- Grep codebase for hardcoded "7" stage references that need updating to "8"

### manifest.json Extensions

Add `debrief_digest` section:

```json
{
  "debrief_digest": {
    "ship_commits": ["abc1234"],
    "spec_revisions": 2,
    "deferred_count": 3,
    "discovery_count": 2,
    "sibling_impacts": ["child-2"]
  }
}
```

## Preservation Contract

These MUST NOT change:
- Existing state.json fields and their meanings
- Existing blueprint stages 1-7 behavior
- Existing vault export pattern (extended, not replaced)
- Existing 23 plan directories (new fields are optional)
- Plugin-enhancers detection protocol
- `/commit` command behavior when no active blueprints exist

## Acceptance Criteria

1. **AC-1**: Running a blueprint through execute → debrief marks state.json `completed: true`
2. **AC-2**: A blueprint without debrief stage cannot be marked complete (structural gate)
3. **AC-3**: `/link-blueprint child --parent meta` creates bidirectional references in both state.json files
4. **AC-4**: `/link-blueprint --show meta` displays all linked children with status
5. **AC-5**: Sub-blueprint debrief updates parent's `meta_units` map
6. **AC-6**: Commit-time signal prompts when active blueprints exist (plugin-enhancer)
7. **AC-7**: `commits.jsonl` is read by debrief to auto-populate ship references
8. **AC-8**: Existing blueprints without debrief stage are unaffected
9. **AC-9**: `test.sh` passes with updated counts and new validations
10. **AC-10**: Debrief vault export includes discoveries and spec delta

## Work Units

| ID | Description | Files | Dependencies | Complexity | TDD |
|----|-------------|-------|--------------|------------|-----|
| W1 | Add debrief stage to blueprint.md | `commands/blueprint.md` | None | High | false |
| W2 | Update PLANNING-STORAGE.md schemas | `docs/PLANNING-STORAGE.md` | W1 | Medium | false |
| W3 | Create /link-blueprint command | `commands/link-blueprint.md` | W2 | Medium | false |
| W4 | Add commit-time signal to plugin-enhancers | `commands/plugin-enhancers.md` | None | Low | false |
| W5 | Update test.sh with new counts and validations | `test.sh` | W1, W2, W3, W4 | Medium | false |
| W6 | Update README.md, commands/README.md, and all "7 stages" references | `README.md`, `commands/README.md`, grep codebase | W1, W3 | Low | false |

### Work Graph

```
W1 (debrief stage) ─────┐
                         ├──→ W5 (tests) ──→ W6 (docs)
W2 (schema docs) ───────┤
                         │
W3 (link-blueprint) ─────┤
                         │
W4 (commit signal) ──────┘
```

- **W1** and **W4** can start in parallel (independent)
- **W2** depends on W1 (schema follows implementation)
- **W3** depends on W2 (needs schema to reference)
- **W5** depends on W1, W2, W3, W4 (validates everything)
- **W6** depends on W1, W3 (documents new features)

**Max parallel width:** 2 (W1 + W4)
**Critical path:** W1 → W2 → W3 → W5 → W6 (5 steps)

## Known Limitations (from Challenge Stage)

1. **Debrief enforcement is behavioral (tier 2.5), not mechanical (tier 1)**. No shell hook blocks `completed:true` without debrief. The `skippable: false` flag and regression-warning prompt are the highest enforcement available without adding a jq dependency.

2. **Sibling impact is passive**. Debrief records impacts but doesn't push-notify siblings. Future enhancement: when a sibling blueprint resumes, read parent's manifest for completed siblings' discoveries. Documented path, not current scope.

3. **Context exhaustion risk at Stage 8**. Debrief runs in a session that has already been through 7 stages. Auto-detection features (commits.jsonl parsing, spec delta) should degrade gracefully — manual fallbacks are first-class, not afterthoughts.

4. **Plugin slot single-occupancy assumption**. The `lifecycle:commit-signal` slot assumes only commit-commands fills it. This inherits the known fragility of the hand-maintained plugin-enhancers registry (flagged in the original plugin-enhancers blueprint).

5. **Concurrent linking is not safe**. Multiple sessions linking children to the same parent simultaneously can produce last-write-wins data loss. Run link operations sequentially.

## Edge Case Amendments Applied (Rev 1.1 → Rev 1.2)

| Finding | Amendment |
|---------|-----------|
| B1: Empty name argument | Added non-empty validation to /link-blueprint rules |
| B3: current_stage schema drift | W2 corrects type to string; debrief uses "debrief" not 8 |
| B5: Parent orphan in debrief | Added fallback when parent unreachable during META UPDATE |
| B8: Debrief on un-executed blueprint | Added execute-complete as debrief prerequisite |
| B9: Session break Stage 7→8 | Added resume-time recovery check + persistent breadcrumb |
| B11: --show with no meta_units | Added explicit "no children" display |
| B2: Path traversal | Documented implicit protection via directory existence |
| B4: Empty commits.jsonl | Documented treat-as-missing behavior |
| B7: SAIL_BLUEPRINT_ACTIVE ghost | Added directory validation + unset suggestion |
| B10: DFS on corrupt ancestor | Documented fail-open truncation |

## Challenge Amendments Applied (Rev 1 → Rev 1.1)

| Finding | Amendment |
|---------|-----------|
| F1: current_stage max:7 | W2 explicitly updates maximum to 8 |
| F2: Commit signal friction | Redesigned to session-flag opt-in |
| F3: .bak file doesn't exist | Replaced with spec.diff.md + regression_log |
| F4: Circular detection pairwise | Upgraded to ancestor DFS traversal |
| F5: Unlink of complete | Changed to block with --force |
| F6: completed:true invariant | Added explicit derivation rule |
| F7: Parent-complete link | Added block rule |
| F8: Half-linked state | Added detection + repair |
| F9: commits.jsonl idempotency | Added dedup-on-read |
| Tension A: jq dependency | Resolved NO — tier 2.5 enforcement |
| Tension B: Commit signal value | Resolved YES with session-flag |
| Tension C: No --reopen | Resolved — use supersession instead |
