---
description: Review override patterns - when plans deviated from recommendations
---

# Overrides

Review override history to identify patterns in how planning recommendations are being bypassed. This enables retrospective learning: were the overrides justified, or did skipped planning cause problems?

## Purpose

Track when users:
- Downgrade from Full → Standard → Light paths
- Skip stages in the planning workflow
- Override triage recommendations

This isn't about enforcement—it's about learning. Patterns in overrides reveal:
- If the triage is too aggressive (always overridden → calibrate)
- If shortcuts cause problems (overridden plans fail more → tighten)
- If certain change types need different defaults

## Process

### Step 1: Load Override Data

Read from `.claude/overrides.json`:

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
    }
  ],
  "summary": {
    "total": 5,
    "by_direction": {
      "full_to_standard": 3,
      "standard_to_light": 2
    }
  }
}
```

### Step 2: Display Override History

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                     OVERRIDE HISTORY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Last 30 days: [N] overrides

  2025-01-15  feature-x      full → standard
              Reason: "Time-sensitive, will backfill tests"
              Outcome: [unknown / succeeded / had issues]

  2025-01-12  quick-patch    standard → light
              Reason: "Truly trivial, just a typo fix"
              Outcome: succeeded

  2025-01-10  api-update     full → standard
              Reason: "Already reviewed externally"
              Outcome: had issues (missing edge case)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 3: Pattern Analysis

```
Pattern Analysis:
━━━━━━━━━━━━━━━━

Override Frequency:
  Full → Standard:  3 times (60%)
  Standard → Light: 2 times (40%)
  Light → Higher:   0 times (0%)

Common Reasons:
  "Time-sensitive":  3 occurrences
  "Already reviewed": 1 occurrence
  "Trivial change":  1 occurrence

Outcomes (where known):
  Succeeded: 2
  Had issues: 1
  Unknown: 2

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 4: Retrospective Prompts

```
Retrospective Questions:
━━━━━━━━━━━━━━━━━━━━━━━━

1. "Time-sensitive" was used 3 times to skip planning.
   → Were those deadlines real, or perceived urgency?
   → Did skipping planning actually save time overall?

2. api-update had issues after downgrading.
   → What did full planning would have caught?
   → Should similar changes stay at full?

3. No plans were upgraded (light → standard/full).
   → Is triage too aggressive, or are upgrades just rare?

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Recording Outcomes

When viewing an override with unknown outcome, offer to record:

```
Override: feature-x (full → standard)

Outcome is unknown. How did this turn out?

  [1] Succeeded - no issues from reduced planning
  [2] Had issues - problems that planning might have caught
  [3] Skip - don't know yet

>
```

Update `overrides.json` with outcome.

## Output Format

```markdown
# Override Review

## Summary (Last 30 Days)

| Metric | Value |
|--------|-------|
| Total overrides | [N] |
| Full → Standard | [N] |
| Standard → Light | [N] |
| Success rate | [%] |
| Issue rate | [%] |

## Override Log

| Date | Plan | Override | Reason | Outcome |
|------|------|----------|--------|---------|
| ... | ... | ... | ... | ... |

## Patterns

### Common Reasons
1. "[reason]" - [N] times
2. "[reason]" - [N] times

### Outcomes
- Succeeded: [N]
- Had issues: [N]
- Unknown: [N]

## Retrospective

[Generated questions based on patterns]

## Recommendations

Based on patterns:
- [recommendation]
- [recommendation]
```

## Empty State

If no overrides exist:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                     OVERRIDE HISTORY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

No overrides recorded.

This means either:
  - All plans followed recommended paths
  - Override tracking isn't enabled

To enable: overrides are automatically logged when you
choose a different path than /describe-change recommends.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Integration

- **Read from:** `.claude/overrides.json`
- **Written by:** `/describe-change`, `/plan` (when path differs from recommended)
- **Linked from:** `/plans`, `/status`
