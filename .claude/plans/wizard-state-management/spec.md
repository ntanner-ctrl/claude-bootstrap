# Specification: wizard-state-management (Revision 1)

> **Revision 1** incorporates findings from Challenge (F1-F9), Edge Cases (G1-G5, A1-A5, M1-M3), and Pre-Mortem (PM1-PM7). Changes marked with `[Rn]` tags referencing the finding that motivated them.

## Summary

Add persistent state management to the 4 non-blueprint Workflow Wizards (`/prism`, `/review`, `/test`, `/clarify`) using a shared lightweight state schema extracted from blueprint's proven `state.json` pattern. Enables resume-on-compaction, stage enforcement via hooks, and vault checkpoints at key moments.

## Design Decisions

### D1: Storage Location — `.claude/wizards/`

Wizard state lives in `.claude/wizards/<wizard-name>-<id>/state.json`, NOT in `.claude/plans/`.

**Why:** `.claude/plans/` is blueprint-specific (contains spec.md, adversarial.md, work-graph.json, etc.). Wizard state is structurally different — it tracks ephemeral workflow progress, not persistent planning artifacts. Mixing them would confuse `state-index.json` and the `/blueprints` command.

**Convention:** `<wizard-name>-<id>` uses the wizard name + a timestamp with second precision for uniqueness. Example: `prism-20260324-235512`, `clarify-20260324-235530`. [A1] Second precision prevents same-minute collision on abandon+restart.

Only ONE active session per wizard type at a time (new invocation archives or replaces the previous). [A3] In monorepo setups, switching target paths requires abandoning the active session — active scope is per wizard type, not per target path.

Wizard state files are not surfaced by `/blueprints`, `/start`, or any other toolkit commands — they are read only by the wizard that created them. [M2]

### D2: No Manifest — State.json Only

Shorter wizards do NOT get a manifest.json. Blueprint's manifest exists because its 7-stage workflow generates 3-8K tokens of artifacts that need token-efficient recovery. Wizard state.json is self-contained — there's nothing to compress.

**Exception:** `/prism` MAY get a `findings-summary.json` if orchestrator context exceeds ~2,000 tokens before synthesis. [F8] This is a concrete trigger condition — if during implementation the accumulated output_summaries from steps context through quality exceed 2,000 tokens, add findings-summary.json as a compressed cache. Without this trigger, it is NOT needed.

### D3: Lightweight State Schema (Shared Core)

All wizards share a common schema core, with wizard-specific extensions. The core is a strict subset of blueprint's state.json — not a new invention.

### D4: Single Active Session Per Wizard

Only one session per wizard type can be active. When a wizard is re-invoked:
- If an active session exists (`status == "active"`) → prompt resume/abandon [A3: positive check]
- If an error session exists (`status == "error"`) → show error-specific prompt (see Error Semantics below) [G4]
- If the previous session completed or was abandoned → silently start a new one (trigger cleanup)

### D5: Vault Checkpoint Timing

| Wizard | Checkpoint Moments | What Gets Exported |
|--------|-------------------|--------------------|
| `/prism` | After Wave 1 completion, after report (Stage 7) | Paradigm summary, final report |
| `/review` | After compile (Step 3) | Review findings summary |
| `/test` | After generate_tests (Stage 2) | Test specifications |
| `/clarify` | After summary (Step 6) | Clarification outcomes |

Checkpoints are advisory — vault unavailability does not block wizard progress. When vault is not configured, wizard run history is available only through state.json files in `.claude/wizards/`. [F6]

### D6: Hook Integration — Future Enhancement [F5]

Stage gate hook integration for wizards is a future enhancement, out of scope for this implementation. When implemented, it will use a `wizard-stage-gate.sh` hook (not yet created) to verify wizard state consistency with warn-not-block behavior. The core value of this spec is resume-on-compaction, not enforcement.

### D7: Error Status Semantics [G4]

`error` status is semi-terminal — it means the session encountered an unrecoverable step failure. On re-invocation:

```
Previous session errored at [step name].
  [1] Resume from last complete step
  [2] Abandon and start fresh
```

Do NOT re-run the failed step automatically. If the user chooses Resume, set `current_step` to the step AFTER the last complete step (which may be the errored step itself, giving the user a chance to retry with fresh context).

---

## Shared Wizard State Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["wizard", "version", "session_id", "status", "current_step", "steps", "created_at", "updated_at"],
  "properties": {
    "wizard": {
      "type": "string",
      "enum": ["prism", "review", "test", "clarify"],
      "description": "Which wizard owns this state"
    },
    "version": {
      "type": "integer",
      "const": 1,
      "description": "Schema version for future migration. If version does not match expected, treat as corrupt — abandon and start fresh. [M1]"
    },
    "session_id": {
      "type": "string",
      "description": "Unique session identifier (YYYYMMDD-HHMMSS format)"
    },
    "status": {
      "type": "string",
      "enum": ["active", "complete", "abandoned", "error"],
      "description": "Overall wizard status"
    },
    "current_step": {
      "type": ["string", "null"],
      "description": "Name of the step currently in progress. Set to null on completion. [G5]"
    },
    "steps": {
      "type": "object",
      "description": "Per-step status tracking. Keys are step names, values are step objects.",
      "additionalProperties": { "$ref": "#/$defs/step" }
    },
    "context": {
      "type": "object",
      "description": "Wizard-specific context data needed for resume. Required keys per wizard documented in Content Contracts section. [M3]",
      "additionalProperties": true
    },
    "vault_checkpoints": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "step": { "type": "string" },
          "exported_at": { "type": "string", "format": "date-time" },
          "vault_path": { "type": "string" }
        }
      }
    },
    "created_at": { "type": "string", "format": "date-time" },
    "updated_at": { "type": "string", "format": "date-time" }
  },
  "$defs": {
    "step": {
      "type": "object",
      "required": ["status"],
      "properties": {
        "status": {
          "type": "string",
          "enum": ["pending", "active", "complete", "skipped", "error"]
        },
        "started_at": { "type": "string", "format": "date-time" },
        "completed_at": { "type": "string", "format": "date-time" },
        "skip_reason": { "type": "string" },
        "output_summary": {
          "type": "string",
          "description": "Compressed summary per Content Contracts section. Budget: ~50-200 tokens for context/scope steps, ~200-300 tokens for analysis steps."
        },
        "substeps": {
          "type": "object",
          "description": "For steps with parallel or nested work (e.g., prism Wave 1 agents)",
          "additionalProperties": {
            "type": "object",
            "properties": {
              "status": { "type": "string", "enum": ["pending", "active", "complete", "skipped", "error"] },
              "completed_at": { "type": "string", "format": "date-time" }
            }
          }
        },
        "conditional": {
          "type": "boolean",
          "default": false,
          "description": "If true, this step may be skipped based on prior step results"
        }
      }
    }
  }
}
```

---

## Content Contracts [F1/G1/M3]

Content contracts define WHAT each `output_summary` and `context` must contain. Without these, resume produces structurally valid but semantically useless context. This is the load-bearing wall of the entire feature — confirmed critical by three independent review lenses (Challenge, Edge Cases, Pre-Mortem).

### Prism Content Contract

**Required context keys:** `target_path`, `scope_files`, `paradigm_summary` (null until wave1 completes), `cf_detected`

| Step | output_summary MUST include | Budget |
|------|----------------------------|--------|
| context | Project name, stack, file counts (commands/agents/hooks) | ~50 tokens |
| scope | File count in scope, filters applied, scope warnings if any | ~50 tokens |
| wave1 | Issue count PER paradigm (DRY: N, YAGNI: N, ...), top 3 critical findings with affected files, pattern-level diagnosis | ~300 tokens |
| architecture | Finding count, top concerns with severity, cross-cutting themes | ~200 tokens |
| cloudformation | Finding count, top concerns (or "skipped: no CF detected") | ~50 tokens |
| security | Finding count, top concerns with severity | ~200 tokens |
| performance | Finding count, top concerns with severity | ~200 tokens |
| quality | Finding count, top concerns with severity | ~150 tokens |
| synthesis | Theme count, remediation priorities, confidence score | ~200 tokens |
| report | Export status, vault path if exported | ~50 tokens |

**Total prism resume budget:** ~1,450 tokens max (realistically ~800-1,000 as early steps are shorter).

### Review Content Contract

**Required context keys:** `target_type` (blueprint/implementation/idea), `target_description`, `blueprint_name` (null if not blueprint-linked)

| Step | output_summary MUST include | Budget |
|------|----------------------------|--------|
| vault_check | Prior review count found, relevant finding titles | ~50 tokens |
| identify_target | Target type, target description, scope | ~50 tokens |
| devils_advocate | Finding count with severity breakdown, top 2 findings | ~150 tokens |
| simplify | Simplification count, top opportunity | ~100 tokens |
| edge_cases | Unhandled edge case count, top 2 boundaries | ~150 tokens |
| external_review | Included/skipped, finding count if included | ~50 tokens |
| deep_analysis | Plugin findings count, top concerns | ~100 tokens |
| compile | Total findings, critical count, action items | ~100 tokens |

**Total review resume budget:** ~750 tokens max.

### Test Content Contract

**Required context keys:** `spec_source` (blueprint/file/described), `blueprint_name` (null if not blueprint), `tdd_active`

| Step | output_summary MUST include | Budget |
|------|----------------------------|--------|
| tdd_check | TDD active (yes/no), phase if active | ~30 tokens |
| spec_review | Spec source, work unit count, testability verdict | ~100 tokens |
| generate_tests | Test count generated, coverage areas, anti-tautology results | ~150 tokens |
| verify | Tests run (yes/no), pass/fail counts | ~50 tokens |

**Total test resume budget:** ~330 tokens max.

### Clarify Content Contract

**Required context keys:** `topic`, `selected_paths` (array of A/B/C/D), `vault_findings` (array of finding slugs)

| Step | output_summary MUST include | Budget |
|------|----------------------------|--------|
| vault_check | Related finding count, relevant titles | ~50 tokens |
| assess | Which paths selected (A/B/C/D) and one-sentence rationale for each | ~100 tokens |
| brainstorm | Approach count, recommended approach, key trade-off | ~150 tokens |
| requirements | Requirement count, ambiguity count, key gaps | ~150 tokens |
| design_check | Prerequisites met/missing, key concern | ~100 tokens |
| prior_art | Recommendation (adopt/adapt/inform/build), top candidate | ~100 tokens |
| summary | Key outcomes, recommended next action | ~100 tokens |

**Total clarify resume budget:** ~750 tokens max (but conditional steps reduce actual usage to ~300-500).

---

## Per-Wizard State Specifications

### Prism (`/prism`)

**Steps (derived from command):** `context`, `scope`, `wave1`, `architecture`, `cloudformation`, `security`, `performance`, `quality`, `synthesis`, `report`

These map to the command's actual stages: Stage 0 (context), Stage 1 (scope), Wave 1 (wave1), Stage 2 (architecture), Stage 2.5 (cloudformation), Stage 3 (security), Stage 4 (performance), Stage 5 (quality), Stage 6 (synthesis), Stage 7 (report). [F2]

**Progression:** Linear with parallel substeps (wave1) and conditional step (cloudformation).

```json
{
  "wizard": "prism",
  "version": 1,
  "session_id": "prism-20260324-235512",
  "status": "active",
  "current_step": "wave1",
  "steps": {
    "context": {
      "status": "complete",
      "output_summary": "Project: claude-sail, Stack: bash/markdown, 63 commands, 12 agents, 19 hooks"
    },
    "scope": {
      "status": "complete",
      "output_summary": "142 files in scope, filtered to commands/*.md + agents/*.md + hooks/*.sh"
    },
    "wave1": {
      "status": "active",
      "substeps": {
        "dry-lens": { "status": "complete" },
        "yagni-lens": { "status": "complete" },
        "kiss-lens": { "status": "active" },
        "consistency-lens": { "status": "pending" },
        "cohesion-lens": { "status": "pending" },
        "coupling-lens": { "status": "pending" }
      }
    },
    "architecture": { "status": "pending" },
    "cloudformation": { "status": "pending", "conditional": true },
    "security": { "status": "pending" },
    "performance": { "status": "pending" },
    "quality": { "status": "pending" },
    "synthesis": { "status": "pending" },
    "report": { "status": "pending" }
  },
  "context": {
    "target_path": ".",
    "scope_files": ["commands/*.md", "agents/*.md", "hooks/*.sh"],
    "paradigm_summary": null,
    "cf_detected": false
  }
}
```

### Review (`/review`) [F2]

**Steps (derived from command):** `vault_check`, `identify_target`, `devils_advocate`, `simplify`, `edge_cases`, `external_review`, `deep_analysis`, `compile`

These map to the command's actual structure: Vault Check (pre-step), Step 1 (identify_target), Stage 1 (devils_advocate), Stage 2 (simplify), Stage 3 (edge_cases), Stage 4 (external_review), Stage 5 (deep_analysis), Step 3 (compile).

**Progression:** Linear with optional tail (external_review, deep_analysis).

```json
{
  "wizard": "review",
  "version": 1,
  "session_id": "review-20260324-235530",
  "status": "active",
  "current_step": "edge_cases",
  "steps": {
    "vault_check": { "status": "complete", "output_summary": "No prior reviews found for this topic" },
    "identify_target": { "status": "complete", "output_summary": "Target: implementation, auth middleware, no blueprint link" },
    "devils_advocate": { "status": "complete", "output_summary": "3 findings: F1 session fixation (high), F2 missing rate limit (medium), F3 verbose errors (low)" },
    "simplify": { "status": "complete", "output_summary": "1 simplification: middleware chain has 3 redundant header checks" },
    "edge_cases": { "status": "active" },
    "external_review": { "status": "pending", "conditional": true },
    "deep_analysis": { "status": "pending", "conditional": true },
    "compile": { "status": "pending" }
  },
  "context": {
    "target_type": "implementation",
    "target_description": "auth middleware",
    "blueprint_name": null
  }
}
```

### Test (`/test`) [F2]

**Steps (derived from command):** `tdd_check`, `spec_review`, `generate_tests`, `verify`

These map to: Pre-check (tdd_check), Stage 1 (spec_review), Stage 2 (generate_tests), Stage 3 (verify).

**Progression:** Linear with conditional skip (tdd_check may skip to verify).

```json
{
  "wizard": "test",
  "version": 1,
  "session_id": "test-20260324-235545",
  "status": "active",
  "current_step": "generate_tests",
  "steps": {
    "tdd_check": { "status": "complete", "output_summary": "No active TDD session" },
    "spec_review": { "status": "complete", "output_summary": "Spec from blueprint wizard-state-management, 8 WUs, testability: high" },
    "generate_tests": { "status": "active" },
    "verify": { "status": "pending" }
  },
  "context": {
    "spec_source": "blueprint",
    "blueprint_name": "wizard-state-management",
    "tdd_active": false
  }
}
```

### Clarify (`/clarify`) [F2]

**Steps (derived from command):** `vault_check`, `assess`, `brainstorm`, `requirements`, `design_check`, `prior_art`, `summary`

These map to: Vault Check (pre-step), Step 1 (assess), Step 2 (brainstorm), Step 3 (requirements), Step 4 (design_check), Step 5 (prior_art), Step 6 (summary).

**Progression:** Conditional branching — `assess` determines which of `brainstorm`/`requirements`/`design_check`/`prior_art` run.

```json
{
  "wizard": "clarify",
  "version": 1,
  "session_id": "clarify-20260324-235600",
  "status": "active",
  "current_step": "brainstorm",
  "steps": {
    "vault_check": { "status": "complete", "output_summary": "Found 2 related findings: prism-context-exhaustion, serial-context-compression" },
    "assess": { "status": "complete", "output_summary": "Selected [A] Approaches (multiple viable designs), [B] Requirements (state schema shape unclear)" },
    "brainstorm": { "status": "active", "conditional": true },
    "requirements": { "status": "pending", "conditional": true },
    "design_check": { "status": "skipped", "conditional": true, "skip_reason": "Not selected in assessment" },
    "prior_art": { "status": "skipped", "conditional": true, "skip_reason": "Not selected in assessment" },
    "summary": { "status": "pending" }
  },
  "context": {
    "topic": "wizard state management",
    "selected_paths": ["A", "B"],
    "vault_findings": ["2026-03-22-prism-context-exhaustion"]
  }
}
```

---

## Stage Progression Display

All 4 wizards get a consistent status header, matching blueprint's `✓/→/○` pattern:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PRISM │ Stage: Wave 1 — Paradigm Lenses
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✓ Context Brief
  ✓ Scope Detection
  → Wave 1: Paradigm Lenses  [4/6 agents complete]
  ○ Architecture Review
  ○ Security Review
  ○ Performance Review
  ○ Quality Review
  ○ Synthesis
  ○ Report & Export

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

For conditional steps, use `—` (dash) for skipped-by-condition:

```
  ✓ Assess
  → Brainstorm
  ○ Requirements
  — Design Check  (not selected)
  — Prior Art     (not selected)
  ○ Summary
```

The display is generated FROM state.json — it reads the steps object and renders based on status values.

---

## Resume Protocol

When a wizard is invoked and an active session exists:

1. **Read** `.claude/wizards/<wizard>-<id>/state.json`
2. **Validate** version field matches expected (if not, treat as corrupt — start fresh) [M1]
3. **Display** the stage progression header with session age [A5: "Previous session from 2 hours ago"]
4. **Prompt** resume/abandon (or error-specific prompt if `status == "error"`) [G4]
5. **Reconstruct context** from `output_summary` fields of completed steps + `context` object
6. **Resume** from `current_step`

**Partial-step resume:** [G2] A substep with `status: active` at resume time is treated as `pending` — re-run it. Partial agent output without a committed `output_summary` is unusable; retrying is always safe for read-only analysis agents.

**Token budget:** [F9/A4] Resume context varies by wizard:
- Short wizards (clarify, test, review): ~300-750 tokens
- Prism: ~800-1,450 tokens (10 steps with tiered summary lengths)
These are significantly cheaper than re-reading full artifacts or re-running completed steps.

**Compaction recovery:** The disk state file is the recovery mechanism — identical to how blueprint uses manifest.json, but lightweight. On re-invocation after compaction, the wizard reads state.json and reconstructs context from `output_summary` fields + `context` object.

**Resume freshness:** [PM6] The resume prompt should display the session's `created_at` timestamp. Sessions older than 4 hours (short wizards) or 24 hours (prism) should prominently note staleness to help the user decide whether to resume or start fresh.

**Completion terminal state:** [G5] On completion, set `current_step` to `null` and `status` to `"complete"`. This creates an unambiguous terminal state.

---

## File System Layout

```
.claude/
├── plans/                      # Blueprint artifacts (unchanged)
│   └── ...
├── wizards/                    # NEW: Wizard state directory
│   ├── prism-20260324-235512/
│   │   └── state.json
│   ├── review-20260324-235530/
│   │   └── state.json
│   ├── _archive/               # Archived completed sessions [G3]
│   │   └── prism-20260320-120000/
│   │       └── state.json
│   └── ...
└── settings.json
```

**Glob exclusion note:** [G3] The active-session glob (`<wizard>-*/state.json`) implicitly excludes `_archive/` because archive paths follow the pattern `_archive/<wizard>-<id>/state.json`, not `<wizard>-<id>/state.json` at the top level. If the glob implementation uses a wildcard that could match nested paths, filter explicitly.

---

## Cleanup (W9) [A2/F4]

On new session creation, archive sessions older than 7 days:

```
# At wizard entry, after creating new session:
1. List all .claude/wizards/<wizard>-*/state.json
2. For each: read created_at, compute age
3. If age > 7 days AND status in (complete, abandoned, error):
   Move directory to .claude/wizards/_archive/
4. If age > 7 days AND status == "active":
   Log warning but do NOT auto-archive (may be a long-running session)
```

This runs only on new session creation — not on resume or every invocation. The 7-day window preserves recent results for reference while preventing indefinite accumulation.

**Active session selection:** [Edge Cases #28] If multiple active sessions exist for the same wizard type (e.g., from a prior race condition), select the most recent by `created_at` timestamp. Archive all others.

---

## Command Modifications

Each wizard command gets these additions:

### 1. State Initialization (Start of Wizard)

```
# At wizard entry:
1. Ensure .claude/wizards/ exists (mkdir -p)
2. Check for active session: ls .claude/wizards/<wizard>-*/state.json
   - If multiple matches: select most recent by timestamp, archive others
3. If active session found (status == "active"):
   - Display age + progress header
   - Prompt: [1] Resume, [2] Abandon and start fresh
4. If error session found (status == "error"):
   - Display error prompt per D7
5. If no active/error session → create new directory + state.json
6. Run cleanup (W9): archive sessions older than 7 days
7. Display stage progression header
```

### 2. Step Transitions (Between Steps)

```
# After each step completes:
1. Update state.json: mark step complete, write output_summary per Content Contract
2. Set current_step to next step
3. Display updated stage progression header
4. If vault checkpoint configured for this step → export (fail-open)
```

### 3. Completion (End of Wizard)

```
# At wizard completion:
1. Set status: "complete", current_step: null [G5]
2. Final vault checkpoint if configured
3. Display completion summary with all steps
```

### 4. Resume (Re-invocation)

```
# On re-invocation with active session:
1. Read state.json, validate version [M1]
2. Display progress header with session age [A5]
3. Present resume/abandon choice (or error prompt) [G4]
4. On resume: reconstruct context from output_summaries + context
5. For current_step with substeps: re-run any substep with status "active" or "pending" [G2]
6. Continue from current_step
```

---

## Test Additions (test.sh)

Add to Category 6 (JSON validation):

```bash
# Validate wizard state.json files if any exist
# Note: This validates JSON syntax only. Schema structure validation
# (required fields, enum values) relies on the Content Contracts.
for f in .claude/wizards/*/state.json; do
  [ -f "$f" ] && jq . "$f" > /dev/null 2>&1 || echo "FAIL: invalid JSON: $f"
done
```

Add to Category 4 (Enforcement lint):

```bash
# Check all wizard commands reference state management
for wizard in prism review test clarify; do
  grep -q "wizards/" "commands/${wizard}.md" || echo "WARN: ${wizard}.md missing wizard state reference"
done

# Check all wizard commands have stage progression display
for wizard in prism review test clarify; do
  grep -q '✓' "commands/${wizard}.md" && grep -q '→' "commands/${wizard}.md" && grep -q '○' "commands/${wizard}.md" \
    || echo "WARN: ${wizard}.md missing stage progression markers"
done

# Check all wizard commands have resume protocol
for wizard in prism review test clarify; do
  grep -q 'Resume' "commands/${wizard}.md" && grep -q 'Abandon' "commands/${wizard}.md" \
    || echo "WARN: ${wizard}.md missing resume/abandon protocol"
done
```

---

## Success Criteria

1. **Resume works:** Each wizard can be interrupted and resumed from disk state
2. **Resume quality:** Resumed wizards reference prior step constraints (not cold-start) [PM1]
3. **State is valid JSON:** `jq . state.json` passes for all wizard states
4. **Progress displays:** All 4 wizards show `✓/→/○` stage progression headers
5. **Vault checkpoints fire:** At configured moments, findings export to vault (when available)
6. **Single active session:** Re-invoking with active session prompts resume/abandon
7. **Error handling:** Error sessions show error-specific prompt, not generic resume [G4]
8. **Cleanup works:** Sessions older than 7 days archived on new session creation [W9]
9. **test.sh passes:** New wizard state checks integrated into existing test suite
10. **No blueprint breakage:** `.claude/plans/` behavior unchanged, `/blueprints` unaffected

## Preservation Contract

- Blueprint's state.json schema — unchanged
- Blueprint's manifest.json — unchanged
- `.claude/plans/` directory structure — unchanged
- Existing wizard command behavior (when no state exists) — unchanged
- `test.sh` existing checks — all still pass

## Failure Modes

| Failure | Impact | Recovery |
|---------|--------|----------|
| state.json write fails | Cannot resume | Wizard continues without state (fail-open) |
| state.json corrupt on read | Cannot resume | Abandon state, start fresh |
| state.json version mismatch | Cannot resume | Treat as corrupt, start fresh [M1] |
| Vault checkpoint fails | Findings not exported | Log warning, continue (fail-open) |
| `.claude/wizards/` doesn't exist | Cannot create state | Auto-create with mkdir -p (idempotent) |
| Multiple active sessions (race) | Confusion | Select most recent, archive others [#28] |
| Step reaches `error` status | Step failed | Error-specific prompt on re-invocation [D7] |

---

## Work Units

| ID | Description | Files | Dependencies | Complexity | TDD |
|----|-------------|-------|--------------|------------|-----|
| W1 | Design & document shared wizard state schema + content contracts | `docs/WIZARD-STATE.md` | — | Medium | false |
| W2 | Add state management to `/prism` | `commands/prism.md` | W1 | High | false |
| W3 | Add state management to `/review` | `commands/review.md` | W1 | Medium | false |
| W4 | Add state management to `/test` | `commands/test.md` | W1 | Low | false |
| W5 | Add state management to `/clarify` | `commands/clarify.md` | W1 | Medium | false |
| W6 | Add stage progression display to all 4 wizards | `commands/{prism,review,test,clarify}.md` | W2, W3, W4, W5 | Low | false |
| W7 | Update test.sh with wizard state validation | `test.sh` | W1 | Low | false |
| W8 | Update CLAUDE.md and READMEs | `CLAUDE.md`, `README.md`, `commands/README.md` | W6, W7, W9 | Low | false |
| W9 | Add cleanup logic to wizard command modifications | `commands/{prism,review,test,clarify}.md` | W2, W3, W4, W5 | Low | false |

**TDD rationale:** All work units modify markdown command files, not executable code. TDD doesn't apply to markdown authoring — the validation is in test.sh's structural checks (W7).

### Work Graph

```
W1 ──→ W2 ──┐
  ├──→ W3 ──┤
  ├──→ W4 ──├──→ W6 ──┐
  └──→ W5 ──┤         ├──→ W8
             └──→ W9 ──┘
W7 ──────────────────────┘
```

**Parallelization:** W2-W5 can run in parallel after W1. W7 is independent. W6 and W9 depend on W2-W5. W8 is the final documentation sweep.

**Width:** 5 (W2-W5 + W7 parallel)
**Critical path:** W1 → W2 → W6 → W8 (4 steps)
