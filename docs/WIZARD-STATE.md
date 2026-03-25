# Wizard State Storage

How Claude Sail stores wizard workflow state.

> **Note:** Wizard state lives in `.claude/wizards/` (not `.claude/plans/`).
> Blueprint artifacts and wizard state are structurally distinct — do not mix them.
> See `docs/PLANNING-STORAGE.md` for blueprint state schemas.

---

## Overview

Wizard state tracks ephemeral workflow progress for the four non-blueprint Workflow Wizards: `/prism`, `/review`, `/test`, `/clarify`. It enables resume-on-compaction, vault checkpoints at key moments, and consistent stage progression display.

**Differs from blueprint state in these ways:**

| Dimension | Blueprint (`state.json`) | Wizard (`state.json`) |
|-----------|--------------------------|----------------------|
| Location | `.claude/plans/<name>/` | `.claude/wizards/<wizard>-<id>/` |
| Manifest | `manifest.json` (required) | None (state.json is self-contained) |
| Artifacts | `spec.md`, `adversarial.md`, etc. | None (output summaries inline in state) |
| Surfaced by | `/blueprints`, `/start` | Not surfaced — read only by the wizard that created it |
| Sessions | One per blueprint name | One active per wizard type |

Wizard state files are not surfaced by `/blueprints`, `/start`, or any other toolkit commands.

---

## Directory Structure

```
.claude/
├── plans/                      # Blueprint artifacts (unchanged)
│   └── ...
├── wizards/                    # Wizard state directory
│   ├── prism-20260324-235512/
│   │   └── state.json
│   ├── review-20260324-235530/
│   │   └── state.json
│   ├── _archive/               # Archived completed sessions
│   │   └── prism-20260320-120000/
│   │       └── state.json
│   └── ...
└── settings.json
```

**Session ID format:** `<wizard-name>-<YYYYMMDD-HHMMSS>`. Second precision prevents same-minute collision on abandon+restart.

**Glob exclusion note:** The active-session glob (`<wizard>-*/state.json`) implicitly excludes `_archive/` because archive paths follow the pattern `_archive/<wizard>-<id>/state.json`, not `<wizard>-<id>/state.json` at the top level. If the glob implementation uses a wildcard that could match nested paths, filter explicitly.

---

## Shared Wizard State Schema

All four wizards share this schema. Wizard-specific extensions are in the `context` and `steps` objects.

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
      "description": "Schema version for future migration. If version does not match expected, treat as corrupt — abandon and start fresh."
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
      "description": "Name of the step currently in progress. Set to null on completion."
    },
    "steps": {
      "type": "object",
      "description": "Per-step status tracking. Keys are step names, values are step objects.",
      "additionalProperties": { "$ref": "#/$defs/step" }
    },
    "context": {
      "type": "object",
      "description": "Wizard-specific context data needed for resume. Required keys per wizard documented in Content Contracts section.",
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

## Content Contracts

Content contracts define what each `output_summary` and `context` object MUST contain. Without these, resume produces structurally valid but semantically useless context.

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

## Per-Wizard Step Mappings

### Prism (`/prism`)

**Steps:** `context`, `scope`, `wave1`, `architecture`, `cloudformation`, `security`, `performance`, `quality`, `synthesis`, `report`

**Command stage mapping:**

| Step name | Command stage |
|-----------|--------------|
| context | Stage 0 (Context Brief) |
| scope | Stage 1 (Scope Detection) |
| wave1 | Wave 1 (Paradigm Lenses) — parallel substeps |
| architecture | Stage 2 (Architecture Review) |
| cloudformation | Stage 2.5 (CloudFormation Review) — conditional |
| security | Stage 3 (Security Review) |
| performance | Stage 4 (Performance Review) |
| quality | Stage 5 (Quality Review) |
| synthesis | Stage 6 (Synthesis) |
| report | Stage 7 (Report & Export) |

**Progression:** Linear with parallel substeps (`wave1`) and one conditional step (`cloudformation`).

**Example state.json:**

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

---

### Review (`/review`)

**Steps:** `vault_check`, `identify_target`, `devils_advocate`, `simplify`, `edge_cases`, `external_review`, `deep_analysis`, `compile`

**Command stage mapping:**

| Step name | Command stage |
|-----------|--------------|
| vault_check | Vault Check (pre-step) |
| identify_target | Step 1 |
| devils_advocate | Stage 1 |
| simplify | Stage 2 |
| edge_cases | Stage 3 |
| external_review | Stage 4 — conditional |
| deep_analysis | Stage 5 — conditional |
| compile | Step 3 |

**Progression:** Linear with optional tail (`external_review`, `deep_analysis`).

**Example state.json:**

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

---

### Test (`/test`)

**Steps:** `tdd_check`, `spec_review`, `generate_tests`, `verify`

**Command stage mapping:**

| Step name | Command stage |
|-----------|--------------|
| tdd_check | Pre-check |
| spec_review | Stage 1 |
| generate_tests | Stage 2 |
| verify | Stage 3 |

**Progression:** Linear with conditional skip (`tdd_check` may skip to `verify`).

**Example state.json:**

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

---

### Clarify (`/clarify`)

**Steps:** `vault_check`, `assess`, `brainstorm`, `requirements`, `design_check`, `prior_art`, `summary`

**Command stage mapping:**

| Step name | Command stage |
|-----------|--------------|
| vault_check | Vault Check (pre-step) |
| assess | Step 1 |
| brainstorm | Step 2 — conditional |
| requirements | Step 3 — conditional |
| design_check | Step 4 — conditional |
| prior_art | Step 5 — conditional |
| summary | Step 6 |

**Progression:** Conditional branching — `assess` determines which of `brainstorm`/`requirements`/`design_check`/`prior_art` run.

**Example state.json:**

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

All four wizards render a consistent status header from `state.json`, using the `✓/→/○` pattern:

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

For steps skipped by condition, use `—`:

```
  ✓ Assess
  → Brainstorm
  ○ Requirements
  — Design Check  (not selected)
  — Prior Art     (not selected)
  ○ Summary
```

The display is generated from `state.json` — it reads the `steps` object and renders based on `status` values.

---

## Resume Protocol

When a wizard is invoked and an active session exists:

1. **Read** `.claude/wizards/<wizard>-<id>/state.json`
2. **Validate** `version` field matches expected — if not, treat as corrupt and start fresh
3. **Display** the stage progression header with session age (e.g., "Previous session from 2 hours ago")
4. **Prompt** resume/abandon — or the error-specific prompt if `status == "error"` (see Error Semantics)
5. **Reconstruct context** from `output_summary` fields of completed steps + `context` object
6. **Resume** from `current_step`

**Partial-substep handling:** A substep with `status: active` at resume time is treated as `pending` — re-run it. Partial agent output without a committed `output_summary` is unusable; retrying is always safe for read-only analysis agents.

**Freshness heuristic:** The resume prompt MUST display the session's `created_at` timestamp. Sessions older than 4 hours (short wizards: clarify, test, review) or 24 hours (prism) should prominently note staleness to help the user decide whether to resume or start fresh.

**Completion terminal state:** On completion, set `current_step` to `null` and `status` to `"complete"`. This creates an unambiguous terminal state.

**Token budget:**

| Wizard | Resume budget |
|--------|--------------|
| test | ~330 tokens max |
| review | ~750 tokens max |
| clarify | ~750 tokens max (~300-500 with conditional steps) |
| prism | ~800-1,450 tokens max |

---

## Error Semantics

`error` status is semi-terminal — it means the session encountered an unrecoverable step failure.

On re-invocation with an error session:

```
Previous session errored at [step name].
  [1] Resume from last complete step
  [2] Abandon and start fresh
```

Do NOT re-run the failed step automatically. If the user chooses Resume, set `current_step` to the step AFTER the last complete step (which may be the errored step itself, giving the user a chance to retry with fresh context).

**Status transitions:**

| Trigger | Status transition |
|---------|-----------------|
| New invocation, no prior session | — → active |
| New invocation, prior session complete/abandoned | — → active (silent cleanup) |
| User chooses Resume | active (preserved) |
| User chooses Abandon | active → abandoned |
| Step fails unrecoverably | active → error |
| All steps complete | active → complete |

---

## Vault Checkpoints

Vault checkpoints are advisory — vault unavailability does not block wizard progress. When vault is not configured, run history is available only through state.json files in `.claude/wizards/`.

| Wizard | Checkpoint moment | What gets exported |
|--------|------------------|-------------------|
| `/prism` | After wave1 completion, after report (Stage 7) | Paradigm summary, final report |
| `/review` | After compile (Step 3) | Review findings summary |
| `/test` | After generate_tests (Stage 2) | Test specifications |
| `/clarify` | After summary (Step 6) | Clarification outcomes |

On vault checkpoint failure: log warning, continue (fail-open). Record successful checkpoints in the `vault_checkpoints` array on the root state object.

---

## Cleanup (W9)

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

This runs only on new session creation — not on resume or every invocation.

**Multiple active sessions:** If multiple active sessions exist for the same wizard type (e.g., from a prior race condition), select the most recent by `created_at` timestamp. Archive all others.

---

## Single Active Session Behavior

Only one session per wizard type can be active at a time. On re-invocation:

| Prior session status | Behavior |
|---------------------|----------|
| `active` | Display age + progress header, prompt resume/abandon |
| `error` | Display error prompt (see Error Semantics) |
| `complete` or `abandoned` | Silently start new session (trigger cleanup) |
| None | Create new session directory and state.json |

In monorepo setups, switching target paths requires abandoning the active session. Active scope is per wizard type, not per target path.

---

## Failure Modes

| Failure | Impact | Recovery |
|---------|--------|----------|
| state.json write fails | Cannot resume | Wizard continues without state (fail-open) |
| state.json corrupt on read | Cannot resume | Abandon state, start fresh |
| state.json version mismatch | Cannot resume | Treat as corrupt, start fresh |
| Vault checkpoint fails | Findings not exported | Log warning, continue (fail-open) |
| `.claude/wizards/` doesn't exist | Cannot create state | Auto-create with `mkdir -p` (idempotent) |
| Multiple active sessions (race) | Confusion | Select most recent, archive others |
| Step reaches `error` status | Step failed | Error-specific prompt on re-invocation |
