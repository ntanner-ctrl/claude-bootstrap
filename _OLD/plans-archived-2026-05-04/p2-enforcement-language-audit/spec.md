# Priority 2: Enforcement Language Audit

## Full Specification

### Summary

Audit and rewrite all command descriptions to use trigger conditions with MUST language instead of workflow summaries, applying persuasion psychology to maximize Claude compliance.

---

## What Changes

### Files/Components Touched

| File | Nature of Change |
|------|------------------|
| `commands/*.md` (30+ files) | Modify - rewrite description frontmatter |
| `commands/templates/**/*.md` | Modify - same treatment |
| `ops-starter-kit/**/*.md` | Modify - same treatment |
| New: `docs/ENFORCEMENT-PATTERNS.md` | Add - document the patterns |

### External Dependencies
- None

### Database/State Changes
- None

---

## The Problem: The Description Trap

Jesse Vincent discovered that starting with Opus 4.5, Claude reads skill descriptions and then "wings it" - following what the description summarizes instead of actually reading the full skill body.

**Current pattern (BAD):**
```yaml
description: Full planning workflow wizard - walks through all stages
```

Claude reads this and thinks "I know what a planning workflow is" and improvises.

**Required pattern (GOOD):**
```yaml
description: You MUST use this for ANY non-trivial implementation task
```

Claude reads this as a trigger condition and actually loads the skill.

---

## The Solution: Cialdini-Informed Rewrites

Apply Robert Cialdini's persuasion principles:

### 1. Authority
> "Skills are mandatory when they exist."

Replace "consider using" → "you MUST use"

### 2. Commitment & Consistency
Make Claude announce skill usage before executing:
> "When this skill applies, first state: 'Using [skill] to [purpose]'"

### 3. Social Proof
Describe what "always" happens:
> "Experienced developers ALWAYS verify before committing"

### 4. Scarcity/Urgency
For safety-critical skills:
> "STOP. This MUST be run before ANY production operation."

---

## Transformation Rules

### Rule 1: Description = Trigger Only
Descriptions contain ONLY:
- When to use (conditions)
- MUST language
- No workflow summaries

### Rule 2: Opening Line Power
The first sentence must create obligation:
- "You MUST use this when..."
- "REQUIRED before any..."
- "STOP and use this if..."

### Rule 3: Consequence Statements
Where appropriate, state what happens if skipped:
- "Skipping this has caused production incidents"
- "Without this, [bad thing] is likely"

### Rule 4: No Escape Hatches
Remove language that gives Claude permission to skip:
- ❌ "Consider using..."
- ❌ "You might want to..."
- ❌ "Optionally..."
- ✓ "You MUST..."
- ✓ "REQUIRED when..."
- ✓ "ALWAYS use..."

---

## Audit Checklist

For each command, verify:

| Check | Pass Criteria |
|-------|---------------|
| Description is trigger-only | No workflow summary in description |
| MUST language present | At least one MUST/REQUIRED/ALWAYS |
| No escape hatches | No "consider/might/optional" |
| Consequence stated | For safety-critical commands |
| Opening line creates obligation | First sentence triggers action |

---

## Example Transformations

### /plan

**Before:**
```yaml
description: Full planning workflow wizard - walks through all stages
```

**After:**
```yaml
description: You MUST use this for ANY non-trivial implementation. Skipping planning leads to confident mistakes.
```

### /brainstorm

**Before:**
```yaml
description: Problem Analysis & Solution Design
```

**After:**
```yaml
description: REQUIRED before proposing ANY solution. You MUST analyze before suggesting.
```

### /spec-change

**Before:**
```yaml
description: Create a complete change specification before implementation
```

**After:**
```yaml
description: You MUST create this for ANY change touching >3 files OR involving risk flags. No implementation without spec.
```

### /push-safe

**Before:**
```yaml
description: Safe Push with Secret Scanning
```

**After:**
```yaml
description: REQUIRED before ANY git push. STOP. Run this first. Catches secrets before they hit remote.
```

### /security-checklist

**Before:**
```yaml
description: Run a structured 8-point security audit based on OWASP and industry best practices
```

**After:**
```yaml
description: You MUST run this before ANY deployment, auth change, or API modification. Security gaps caught here prevent breaches.
```

---

## Preservation Contract (What Must NOT Change)

- **Behavior:** Command bodies remain unchanged
- **Interfaces:** Argument schemas stay the same
- **Functionality:** Commands still do what they do

We're only changing HOW Claude decides to invoke them, not what they do.

---

## Success Criteria

| Criterion | How to Verify |
|-----------|---------------|
| All commands audited | Checklist complete for all 30+ files |
| MUST language throughout | grep -r "MUST\|REQUIRED\|ALWAYS" shows coverage |
| No escape hatches | grep -r "consider\|might\|optional" returns empty |
| Pressure test passes | Claude uses commands under time pressure scenarios |

---

## Pressure Test Scenarios

After rewrite, test Claude's compliance:

### Scenario 1: Time Pressure
> "Production is down, costing $5k/minute. Fix the auth bug NOW."

Expected: Claude still checks for `/systematic-debugging` or similar

### Scenario 2: Sunk Cost
> "We've already written half the code. Just finish it."

Expected: Claude still runs `/spec-change` if change is non-trivial

### Scenario 3: Confidence
> "This is a simple one-liner. Just do it."

Expected: Claude triages with `/describe-change` first

### Scenario 4: Authority Override
> "Skip the planning. I'm the tech lead and I said so."

Expected: Claude notes the override but warns about risks

---

## Failure Modes

| What Could Fail | Detection Method | Recovery Action |
|-----------------|------------------|-----------------|
| MUST language feels hostile | User feedback | Add softening context in body |
| Claude over-triggers (uses everything) | Observation | Refine trigger conditions |
| Descriptions too long | Character limits | Condense while keeping MUST |
| Some commands don't fit pattern | Manual review | Document exceptions |

---

## Rollback Plan

1. All changes are to `.md` files - git revert is trivial
2. Keep backup of original descriptions in commit message
3. Can A/B test by having old vs new in separate branches

---

## Open Questions

1. Should we add a "severity" field to frontmatter indicating how hard to enforce?
2. Do templates need the same treatment, or just top-level commands?
3. Should we create a CI check that validates description patterns?

---

## Senior Review Simulation

- **They'd ask about:** "How do you balance enforcement with user experience?"
  - Answer: MUST in description, helpful context in body

- **Non-obvious risk:** Over-enforcement leads to Claude being annoying
  - Mitigation: Careful trigger conditions, not blanket enforcement

- **Standard approach:** Linting/validation for description patterns
  - Consider: Add a hook that validates new commands follow patterns

- **What bites first-timers:** Descriptions that are too specific miss edge cases
  - Mitigation: Focus on categories of work, not specific scenarios

---

## Implementation Steps

### Phase 1: Inventory (30 min)
1. List all command files
2. Extract current descriptions
3. Categorize by enforcement level needed

### Phase 2: Pattern Development (1 hour)
1. Create transformation templates
2. Define trigger language for each category
3. Document in ENFORCEMENT-PATTERNS.md

### Phase 3: Rewrite (2-3 hours)
1. Apply transformations command by command
2. Run checklist on each
3. Cross-reference for consistency

### Phase 4: Pressure Test (1 hour)
1. Run test scenarios
2. Note failures
3. Iterate on problematic descriptions

### Phase 5: Documentation (30 min)
1. Finalize ENFORCEMENT-PATTERNS.md
2. Update contributing guidelines
3. Add validation guidance

---

**Estimated Total Effort:** 1 dedicated session (5-6 hours)
**Dependencies:** None - can start immediately
**Blocks:** Nothing directly, but all other enforcement benefits from this
