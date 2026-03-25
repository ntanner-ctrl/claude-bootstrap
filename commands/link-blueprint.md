---
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
---

# Link Blueprint

Declares parent/child relationships between blueprints for meta-coordination. All relationships are explicit and user-initiated — no auto-detection.

## Modes

This command operates in three modes based on arguments:

| Mode | Invocation | Purpose |
|------|-----------|---------|
| **Link** | `/link-blueprint [name] --parent [parent]` | Create parent/child relationship |
| **Show** | `/link-blueprint --show [name]` | Display relationships |
| **Unlink** | `/link-blueprint [name] --unlink` | Remove parent relationship |

---

## Mode 1: Link

### Input Validation

Run ALL validation checks BEFORE writing ANY state. If ANY check fails, abort with the specified error and write nothing.

1. **Non-empty name**: `$name` MUST be non-empty and non-whitespace. Error: "Blueprint name is required."
2. **Non-empty parent**: `--parent` MUST be non-empty and non-whitespace. Error: "Parent blueprint name is required."
3. **No self-reference**: `$name` MUST NOT equal `$parent`. Error: "A blueprint cannot be its own parent."
4. **Child exists**: `.claude/plans/$name/state.json` MUST exist. Error: "Blueprint '$name' not found in .claude/plans/"
5. **Parent exists**: `.claude/plans/$parent/state.json` MUST exist. Error: "Parent blueprint '$parent' not found in .claude/plans/"
6. **Parent not completed**: Parent's state.json MUST NOT have `"completed": true`. Error: "Parent '$parent' is completed — its debrief is already written. Cannot add children to a completed blueprint."
7. **Child complete warning**: If child's state.json has `"completed": true`, display warning but DO NOT block: "Warning: '$name' is already completed. Linking retroactively for documentation purposes."
8. **Transitive cycle detection (DFS)**: Walk the ancestor chain starting from `$parent`. At each step, read `parent.blueprint` from that ancestor's state.json. If ANY ancestor in the chain equals `$name`, error: "Cycle detected: linking '$name' under '$parent' would create a circular dependency." If ANY ancestor's state.json is unreadable, treat the chain as terminated at that point (fail-open) and log: "Warning: ancestor '[ancestor]' state.json unreadable — cycle check truncated."

### Write Operations

After ALL validation passes, perform BOTH writes:

**Step 1: Update child's state.json**

Add or replace the `parent` field at the root level:

```json
{
  "parent": {
    "blueprint": "$parent",
    "unit_id": "$unit"
  }
}
```

If `--unit` was not provided, set `unit_id` to `null`.

**Step 2: Update parent's state.json**

Add or update the `meta_units` object at the root level. Create `meta_units` if it does not exist.

```json
{
  "meta_units": {
    "$name": {
      "unit_id": "$unit",
      "status": "in_progress",
      "linked_at": "ISO-8601 timestamp",
      "discoveries": [],
      "ship_commit": null
    }
  }
}
```

If `--unit` was not provided, set `unit_id` to `null`.

Derive `status` from child's current state:
- If child has `"completed": true` → `"complete"`
- Otherwise → `"in_progress"`

### Confirmation Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BLUEPRINT LINKED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Child:   $name
  Parent:  $parent
  Unit:    $unit (or "none")

  Bidirectional references written to:
    - .claude/plans/$name/state.json     (parent field)
    - .claude/plans/$parent/state.json   (meta_units entry)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Mode 2: Show

### Input

`/link-blueprint --show [name]` where `name` is the blueprint to inspect.

**Validation**: `$name` MUST be non-empty. `.claude/plans/$name/state.json` MUST exist.

### Display Logic

Read the blueprint's state.json.

**If `meta_units` key is absent or empty (no children):**

```
No linked children for $name. Use `/link-blueprint [child] --parent $name` to add one.
```

**If `meta_units` has entries:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  META-BLUEPRINT: $name
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Units:
    $unit_id  $child_name    ● complete     (shipped: $ship_commit)
    $unit_id  $child_name    ◐ in_progress
    —         $child_name    ○ not started

  Discoveries surfaced:
    - $child_name: "$discovery_text"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Status icons:
- `●` = complete
- `◐` = in_progress
- `○` = not started (or any other status)

For `unit_id`, display `—` if null.

For `ship_commit`, only display the `(shipped: ...)` suffix when status is `complete` and `ship_commit` is non-null.

For the "Discoveries surfaced" section, collect ALL non-empty `discoveries` arrays across ALL children. If no discoveries exist across any child, omit the "Discoveries surfaced" section entirely.

### Half-Linked State Detection

While building the show display, also check for consistency:

For each child in `meta_units`, read the child's state.json and verify it has a `parent.blueprint` field pointing back to `$name`.

If a child's state.json does NOT reference `$name` as parent (or the child's state.json is missing):

```
⚠ Half-linked state detected: '$child' is listed in $name's meta_units
  but $child's state.json does not reference $name as parent.

  Repair? This will add the parent reference to $child's state.json.
  [Ask user to confirm before repairing]
```

On user confirmation, write the `parent` field to the child's state.json with the `unit_id` from the parent's `meta_units` entry.

Similarly, if a blueprint has a `parent` field but the parent's `meta_units` does not list it — surface this when showing EITHER blueprint and offer repair.

---

## Mode 3: Unlink

### Input

`/link-blueprint [name] --unlink` removes the parent relationship from `$name`.

### Validation

1. **Non-empty name**: `$name` MUST be non-empty. Error: "Blueprint name is required."
2. **Blueprint exists**: `.claude/plans/$name/state.json` MUST exist. Error: "Blueprint '$name' not found."
3. **Has parent**: Child's state.json MUST have a `parent` field. Error: "'$name' has no parent relationship to remove."
4. **Completion block**: If EITHER the child OR the parent has `"completed": true`, block the unlink. Error: "Cannot unlink '$name' — either it or its parent '$parent' is completed. Use `--force` to override."
5. **Force override**: If `--force` is provided alongside `--unlink`, skip the completion block. Log: "Force-unlinking '$name' from completed blueprint. This may leave stale references in debrief artifacts."

### Write Operations

**Step 1:** Read the `parent.blueprint` value from child's state.json to identify the parent.

**Step 2:** Remove the `parent` field from child's state.json.

**Step 3:** Remove child's entry from parent's `meta_units` in parent's state.json. If `meta_units` becomes empty after removal, remove the `meta_units` key entirely.

If parent's state.json is unreadable (deleted, corrupted), skip Step 3 with warning: "Parent '$parent' state.json is unreadable — removed child reference only."

### Confirmation Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BLUEPRINT UNLINKED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Child:   $name
  Parent:  $parent (removed)

  References cleaned from:
    - .claude/plans/$name/state.json     (parent field removed)
    - .claude/plans/$parent/state.json   (meta_units entry removed)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Error Handling

- ALL state reads use fail-open semantics: if a state.json is unreadable, warn and continue where possible
- NEVER write partial state: if the child write succeeds but the parent write fails, immediately attempt to roll back the child write and report: "Link failed: parent state.json could not be updated. Child state.json has been rolled back."
- JSON parsing errors: "Failed to parse .claude/plans/$name/state.json — file may be corrupted."

## Notes

- Relationships are project-scoped (`.claude/plans/` in the current working directory)
- Concurrent linking to the same parent from multiple sessions is NOT safe — run link operations sequentially
- The debrief stage (Stage 8) reads `parent` to determine whether to run the sibling-impact and meta-update steps
- This command does NOT create blueprints — both parent and child MUST already exist via `/blueprint`
