---
description: "DEPRECATED: Use /vault-curate instead. For equivalent behavior, use /vault-curate --quick --section findings."
---

# Review Findings (Deprecated)

This command has been replaced by `/vault-curate`.

## Migration

| Old Command | New Equivalent |
|-------------|----------------|
| `/review-findings` | `/vault-curate --quick --section findings` |
| `/review-findings --all` | `/vault-curate --quick` |
| `/review-findings --critical-only` | `/vault-curate --quick --section findings` (triage sorts by severity) |
| `/review-findings --project NAME` | `/vault-curate --quick --section findings --project NAME` |

## Why

`/vault-curate` extends the original findings-only review to cover all 6 vault content types (findings, blueprints, ideas, sessions, decisions, patterns) with type-specific health signals, synthesis, and self-tuning frequency recommendations.

The `--quick` flag provides the same focused findings review that `/review-findings` offered.
