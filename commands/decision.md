---
description: You MUST record decisions when the reasoning is non-obvious or context-dependent. Future sessions lose context — decisions preserve it.
arguments:
  - name: title
    description: Short title for this decision
    required: true
---

# Decision

Capture non-obvious decisions for future reference. Useful when you make a choice that isn't self-evident from the code—future you (or teammates) will thank you.

## When to Use

- Choosing between multiple valid approaches
- Making tradeoffs with non-obvious consequences
- Rejecting a "standard" approach for good reasons
- Decisions that will look wrong without context

## Process

### Section 1: Context

> **What situation prompted this decision? What constraints exist?**

Describe:
- What problem you're solving
- What constraints are in play (time, resources, compatibility)
- What triggered the need to decide now

### Section 2: Options Considered

> **What alternatives did you evaluate?**

For each option:

#### Option A: [name]
- **Pros:** [benefits]
- **Cons:** [drawbacks]
- **Risk:** [what could go wrong]

#### Option B: [name]
- **Pros:** [benefits]
- **Cons:** [drawbacks]
- **Risk:** [what could go wrong]

#### Option C: [name] (if applicable)
- **Pros:** [benefits]
- **Cons:** [drawbacks]
- **Risk:** [what could go wrong]

### Section 3: Decision

> **What did you choose and why?**

We chose **[option]** because:

[Explanation that addresses why this option despite its cons]

### Section 4: Consequences

> **What follows from this decision?**

**We gain:**
- [benefit]
- [benefit]

**We lose:**
- [tradeoff]
- [tradeoff]

**We must now:**
- [implication]
- [implication]

### Section 5: Review Trigger

> **When should this decision be revisited?**

Revisit this decision if:
- [condition that invalidates the reasoning]
- [milestone that enables reconsidering]
- [external change that shifts tradeoffs]

## Output Format

```markdown
# Decision Record: [title]

**Date:** [YYYY-MM-DD]
**Status:** proposed | accepted | deprecated | superseded by [link]

## Context

[What situation prompted this decision? What constraints exist?]

## Options Considered

### Option A: [name]
- **Pros:** [benefits]
- **Cons:** [drawbacks]
- **Risk:** [what could go wrong]

### Option B: [name]
- **Pros:** [benefits]
- **Cons:** [drawbacks]
- **Risk:** [what could go wrong]

### Option C: [name]
- **Pros:** [benefits]
- **Cons:** [drawbacks]
- **Risk:** [what could go wrong]

## Decision

We chose **[option]** because:

[Reasoning]

## Consequences

**We gain:**
- [benefit]

**We lose:**
- [tradeoff]

**We must now:**
- [implication]

## Review Trigger

Revisit this decision if:
- [condition]
```

## Output Artifacts

Save to:
- Project decisions: `.claude/plans/[plan-name]/decisions/[title].md`
- Standalone decisions: `docs/decisions/[NNNN]-[title].md` (ADR format)

## ADR Numbering (Optional)

If using Architecture Decision Records format:
- `0001-use-typescript.md`
- `0002-choose-react-over-vue.md`
- etc.

## Integration

- Can be created during `/spec-change` when options emerge
- Can be created during `/brainstorm` when evaluating approaches
- Referenced in code comments: `// See ADR-0003 for why we chose this approach`

---
Decision recorded. Consider:
  • Link from relevant code → `// See decision: [title]`
  • Set calendar reminder → for review trigger conditions
  • Share with team → if this affects others
