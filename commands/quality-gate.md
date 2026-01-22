---
description: You MUST pass this before completing ANY significant implementation. Blocks below-threshold work.
arguments:
  - name: threshold
    description: Minimum score to pass (default 85)
    required: false
---

# Quality Gate

Score implementation against a structured rubric. Work below threshold is BLOCKED from completion.

Inspired by Turkey-Build's 98/100 quality gate. This ensures every significant piece of work meets a minimum standard before being considered complete.

## When to Use

- After completing a feature implementation
- Before creating a commit for significant work
- Before marking a `/plan` as complete
- When the user asks "is this ready?"

## Rubric (100 points)

| Category | Max Points | What to Evaluate |
|----------|------------|------------------|
| **Functionality** | 25 | All acceptance criteria met, correct behavior |
| **Tests** | 20 | Tests exist, pass, cover edge cases and failures |
| **Security** | 20 | Input validation, no injection, auth checks, OWASP |
| **Code Quality** | 15 | Readable, follows project conventions, DRY |
| **Documentation** | 10 | Comments where needed, README updated if applicable |
| **Performance** | 10 | No obvious bottlenecks, appropriate data structures |

## Process

### Step 1: Gather Evidence

For each category, collect concrete evidence:

**Functionality:**
- List each acceptance criterion
- Verify each is implemented
- Check edge cases are handled

**Tests:**
- List test files created/modified
- Note coverage of success paths
- Note coverage of failure paths
- Check for trivial/tautological tests

**Security:**
- Check input validation at boundaries
- Look for injection vectors (SQL, XSS, command)
- Verify auth/authz where applicable
- Check for leaked secrets or sensitive data

**Code Quality:**
- Check naming conventions
- Look for code duplication
- Verify consistent style
- Check error handling

**Documentation:**
- Are complex sections commented?
- Is README updated if needed?
- Are API changes documented?

**Performance:**
- Check for N+1 queries or unnecessary loops
- Verify appropriate data structures
- Look for obvious memory leaks

### Step 2: Score

Rate each category honestly. Be strict - this is the quality gate.

Scoring guide per category:
- **Full marks**: Exceptional, no issues
- **75%+ marks**: Good, minor issues only
- **50% marks**: Adequate, notable gaps
- **<50% marks**: Insufficient, must address

### Step 3: Report

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  QUALITY GATE                          Threshold: [threshold]/100
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Functionality:  [XX]/25  [████████████████████████░░░░]
  Tests:          [XX]/20  [████████████████████░░░░░░░░]
  Security:       [XX]/20  [████████████████████████████]
  Code Quality:   [XX]/15  [████████████████████████░░░░]
  Documentation:  [XX]/10  [██████████████░░░░░░░░░░░░░░]
  Performance:    [XX]/10  [████████████████████████░░░░]
                  ─────────
  TOTAL:          [XX]/100

  Status: [PASS ✓ | BLOCKED ✗]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 4: If Blocked

When score < threshold:

```
  ✗ BLOCKED — Score [XX] < threshold [YY]

  Must address before completion:

  Category: [lowest scoring]
    Issue: [specific gap]
    Fix: [what to do]

  Category: [second lowest]
    Issue: [specific gap]
    Fix: [what to do]

  Points needed: [threshold - score]
  Fastest path: [which category to improve]
```

### Step 5: If Passed

```
  ✓ PASSED — Score [XX] ≥ threshold [YY]

  Ready to proceed. Consider:
  - Commit this work
  - Move to next task
  - Run /push-safe before pushing
```

## Threshold Guidelines

| Context | Recommended Threshold |
|---------|----------------------|
| Production feature | 85 |
| Internal tool | 70 |
| Prototype/POC | 60 |
| Hotfix (speed critical) | 75 |

Default threshold: 85 (override with argument)

## Integration

- **Part of:** `/plan` wizard (end of Stage 7: Execute)
- **Feeds into:** Commit decision
- **Pairs with:** `/security-checklist` for detailed security review

## Anti-Gaming

Watch for these attempts to inflate scores:

| Gaming Attempt | Detection |
|----------------|-----------|
| Trivial tests that always pass | Check for meaningful assertions |
| "Documentation" that's just noise | Check for actual useful content |
| Claiming security is N/A | Almost never true - validate |
| Ignoring performance | At least check for obvious issues |

## Output

If tracking a plan, update `.claude/plans/[name]/quality-gate.md` with full report.
