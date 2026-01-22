---
description: REQUIRED after completing a plan on the Full path. External perspective catches what familiarity blinds you to.
arguments:
  - name: target
    description: Plan name, file path, or 'current' for active context
    required: false
---

# Review

Focused adversarial review workflow. Use this when you have a plan or implementation and want to systematically challenge it without going through full planning stages.

## Overview

```
Stage 1: Devil's Advocate  → Challenge assumptions
Stage 2: Simplify          → Question complexity
Stage 3: Edge Cases        → Probe boundaries
Stage 4: External (opt)    → GPT review for blind spots
```

## Process

### Step 1: Identify Target

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 1 of 4: Setup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

What are you reviewing?

  [1] An existing plan (provide name or path)
  [2] Current implementation (describe scope)
  [3] An idea or approach (describe it)

>
```

### Step 2: Run Adversarial Stages

**Stage 1: Devil's Advocate**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 1 of 4: Devil's Advocate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Challenging assumptions...
```

Run `/devils-advocate` on the target.

**Stage 2: Simplify**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 2 of 4: Simplify
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Questioning complexity...
```

Run `/simplify-this` on the target.

**Stage 3: Edge Cases**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 3 of 4: Edge Cases
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Probing boundaries...
```

Run `/edge-cases` on the target.

**Stage 4: External Review (Optional)**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 4 of 4: External Review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Would you like an external perspective via /gpt-review?
This can catch blind spots that local review missed.

  [1] Yes - run external review
  [2] No - skip, local review is sufficient

>
```

If yes, run `/gpt-review` with all local findings included.

### Step 3: Compile Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Review Summary: [target]

### Devil's Advocate
- Gaps found: [N]
- Critical: [list]

### Simplify
- Simplification opportunities: [N]
- Recommended: [list]

### Edge Cases
- Unhandled: [N]
- High-risk: [list]

### External Review
[Included / Skipped]
[If included, key novel findings]

## Overall Verdict

- [ ] Ready to proceed
- [ ] Address [N] issues first
- [ ] Needs significant rethinking

## Recommended Actions

1. [action]
2. [action]
3. [action]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Quick Mode

For faster review focusing on one dimension:

```
/review --quick devils-advocate [target]
/review --quick simplify [target]
/review --quick edge-cases [target]
```

Runs only the specified stage.

## Output Format

```markdown
# Adversarial Review: [target]

## Executive Summary

| Dimension | Issues | Critical? |
|-----------|--------|-----------|
| Assumptions | [N] gaps | [Yes/No] |
| Complexity | [N] opportunities | [Yes/No] |
| Edge Cases | [N] unhandled | [Yes/No] |
| External | [included/skipped] | — |

## Detailed Findings

### Assumptions (Devil's Advocate)
[findings]

### Complexity (Simplify This)
[findings]

### Boundaries (Edge Cases)
[findings]

### External Perspective
[findings if included]

## Recommended Actions

1. [prioritized action]
2. [prioritized action]
...

## Verdict

[Ready / Needs Work / Rethink]
```

## Integration

- **Standalone:** Can be run on any plan, implementation, or idea
- **After /plan:** Provides deeper adversarial review post-planning
- **Before /push-safe:** Final check before shipping
