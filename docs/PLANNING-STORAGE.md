# Planning Storage Structure

How Claude Bootstrap stores planning state and artifacts.

---

## Directory Structure

```
.claude/
├── plans/                      # Per-change planning artifacts
│   ├── feature-x/
│   │   ├── state.json          # Progress tracking
│   │   ├── describe.md         # Triage output
│   │   ├── spec.md             # Full specification
│   │   ├── adversarial.md      # Challenge findings
│   │   ├── preflight.md        # Pre-flight checklist
│   │   └── tests.md            # Generated test specs
│   └── bugfix-y/
│       └── ...
├── overrides.json              # Project-level override history
└── settings.json               # Existing Claude Code config
```

---

## state.json Schema

Tracks progress through the planning workflow.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["name", "created", "recommended_path", "current_stage", "stages"],
  "properties": {
    "name": {
      "type": "string",
      "description": "Plan identifier (matches directory name)"
    },
    "created": {
      "type": "string",
      "format": "date-time",
      "description": "When the plan was created"
    },
    "updated": {
      "type": "string",
      "format": "date-time",
      "description": "Last modification timestamp"
    },
    "recommended_path": {
      "type": "string",
      "enum": ["light", "standard", "full"],
      "description": "Path recommended by /describe-change triage"
    },
    "chosen_path": {
      "type": "string",
      "enum": ["light", "standard", "full"],
      "description": "Path actually chosen (may differ if overridden)"
    },
    "current_stage": {
      "type": "integer",
      "minimum": 1,
      "maximum": 7,
      "description": "Current stage number (1-7)"
    },
    "stages": {
      "type": "object",
      "properties": {
        "describe": { "$ref": "#/$defs/stage" },
        "specify": { "$ref": "#/$defs/stage" },
        "challenge": { "$ref": "#/$defs/stage" },
        "edge_cases": { "$ref": "#/$defs/stage" },
        "review": { "$ref": "#/$defs/stage" },
        "test": { "$ref": "#/$defs/stage" },
        "execute": { "$ref": "#/$defs/stage" }
      }
    },
    "skipped": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "stage": { "type": "string" },
          "reason": { "type": "string" },
          "timestamp": { "type": "string", "format": "date-time" }
        }
      },
      "description": "Stages that were skipped with reasons"
    },
    "notes": {
      "type": "string",
      "description": "Free-form notes about this plan"
    }
  },
  "$defs": {
    "stage": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "enum": ["pending", "in_progress", "complete", "skipped", "blocked"]
        },
        "started": {
          "type": "string",
          "format": "date-time"
        },
        "completed": {
          "type": "string",
          "format": "date-time"
        },
        "skippable": {
          "type": "boolean",
          "default": false
        }
      }
    }
  }
}
```

### Example state.json

```json
{
  "name": "feature-x",
  "created": "2025-01-15T10:30:00Z",
  "updated": "2025-01-16T14:22:00Z",
  "recommended_path": "full",
  "chosen_path": "full",
  "current_stage": 3,
  "stages": {
    "describe": { "status": "complete", "completed": "2025-01-15T10:45:00Z" },
    "specify": { "status": "complete", "completed": "2025-01-15T11:30:00Z" },
    "challenge": { "status": "in_progress", "started": "2025-01-16T14:00:00Z" },
    "edge_cases": { "status": "pending", "skippable": true },
    "review": { "status": "pending", "skippable": true },
    "test": { "status": "pending", "skippable": true },
    "execute": { "status": "blocked" }
  },
  "skipped": [],
  "notes": ""
}
```

---

## overrides.json Schema

Project-level tracking of when users override recommended planning depth.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "overrides": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["plan", "date", "recommended", "chosen", "reason"],
        "properties": {
          "plan": {
            "type": "string",
            "description": "Plan name that was overridden"
          },
          "date": {
            "type": "string",
            "format": "date-time"
          },
          "recommended": {
            "type": "string",
            "enum": ["light", "standard", "full"]
          },
          "chosen": {
            "type": "string",
            "enum": ["light", "standard", "full"]
          },
          "reason": {
            "type": "string",
            "description": "User's stated reason for override"
          },
          "stage_at_override": {
            "type": "string",
            "description": "Which stage the override happened at"
          }
        }
      }
    },
    "summary": {
      "type": "object",
      "properties": {
        "total": { "type": "integer" },
        "by_direction": {
          "type": "object",
          "properties": {
            "full_to_standard": { "type": "integer" },
            "full_to_light": { "type": "integer" },
            "standard_to_light": { "type": "integer" },
            "light_to_standard": { "type": "integer" },
            "standard_to_full": { "type": "integer" },
            "light_to_full": { "type": "integer" }
          }
        }
      }
    }
  }
}
```

### Example overrides.json

```json
{
  "overrides": [
    {
      "plan": "feature-x",
      "date": "2025-01-15T10:30:00Z",
      "recommended": "full",
      "chosen": "standard",
      "reason": "Time-sensitive, will backfill tests",
      "stage_at_override": "describe"
    },
    {
      "plan": "quick-patch",
      "date": "2025-01-12T09:15:00Z",
      "recommended": "standard",
      "chosen": "light",
      "reason": "Truly trivial, just a typo fix",
      "stage_at_override": "describe"
    }
  ],
  "summary": {
    "total": 2,
    "by_direction": {
      "full_to_standard": 1,
      "full_to_light": 0,
      "standard_to_light": 1,
      "light_to_standard": 0,
      "standard_to_full": 0,
      "light_to_full": 0
    }
  }
}
```

---

## Stage Mapping

| Stage # | Stage Name | Command | Skippable | Required For |
|---------|------------|---------|-----------|--------------|
| 1 | Describe | `/describe-change` | No | All paths |
| 2 | Specify | `/spec-change` | Light path auto-skips | Standard, Full |
| 3 | Challenge | `/devils-advocate` | Yes (with reason) | Full |
| 4 | Edge Cases | `/edge-cases` | Yes (with reason) | Full |
| 5 | Review | `/gpt-review` | Yes (optional) | None |
| 6 | Test | `/spec-to-tests` | Yes (with reason) | Full |
| 7 | Execute | Implementation | No | All paths |

---

## Path Requirements

### Light Path
- Stage 1: Describe (required)
- Stage 7: Execute
- Preflight recommended but not tracked

### Standard Path
- Stage 1: Describe (required)
- Stage 2: Specify (required)
- Stage 7: Execute
- Other stages optional

### Full Path
- All stages available
- Stage 1, 2 required
- Stages 3-6 recommended, tracked if skipped
- Stage 5 (External Review) always optional

---

## File Naming Conventions

| Artifact | Filename | Created By |
|----------|----------|------------|
| Triage output | `describe.md` | `/describe-change` |
| Specification | `spec.md` | `/spec-change` |
| Pre-flight check | `preflight.md` | `/preflight` |
| Adversarial findings | `adversarial.md` | `/devils-advocate`, `/simplify-this`, `/edge-cases` |
| External review | `review.md` | `/gpt-review` |
| Test specifications | `tests.md` | `/spec-to-tests` |
| Decision records | `decisions/[name].md` | `/decision` |

---

## Cleanup

Plans can be cleaned up after completion:

```bash
# Archive completed plan
mv .claude/plans/feature-x .claude/plans/_archive/feature-x

# Or delete if not needed
rm -rf .claude/plans/feature-x
```

The `/plans` command shows active plans and flags stale ones (no activity > 7 days).
