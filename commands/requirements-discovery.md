---
description: You MUST use this when requirements are unclear or complex. Building without validated requirements causes expensive rework.
---

# Requirements Discovery

Extract clear, validated requirements before solution design. Based on the "WHY detective" approach: drill past symptoms to find root problems.

**When to use**: Before `/feature-dev` for complex features, when requirements are unclear, or when you need stakeholder alignment.

---

## Phase 1: The WHY Detective

Ask these questions and **WAIT for answers**:

### The Job to be Done
1. **What outcome are you trying to achieve?** (Not what feature—what result?)
2. **What happens if you don't solve this?** (Stakes and urgency)
3. **How do you currently work around this problem?** (Existing patterns)

### The Real Problem
4. **Is this the problem itself, or a symptom of something deeper?**
5. **Why does this problem exist?** (Root cause)
6. **Who else is affected by this?** (Stakeholders)

### Success Criteria
7. **How will you know this is solved?** (Observable outcomes)
8. **What's the minimum that would satisfy you?** (MVP scope)
9. **What would exceed your expectations?** (Stretch goals)

---

## PAUSE HERE

Do not proceed until the user has answered these questions. Use the AskUserQuestion tool if helpful, or wait for freeform responses.

---

## Phase 2: Constraint Mapping

After the user responds, map out constraints:

### Hard Constraints (non-negotiable)
- Timeline requirements?
- Technical limitations?
- Resource/budget constraints?
- Compliance/security requirements?

### Soft Constraints (preferences)
- Technology preferences?
- Approach preferences?
- Future extensibility considerations?

### Stakeholder Map
- Who needs to approve this?
- Who will use this daily?
- Who might block or delay this?
- Who should be informed but not consulted?

Present your understanding and ask: **"Did I miss any constraints?"**

---

## PAUSE HERE

Wait for constraint confirmation before proceeding.

---

## Phase 3: Requirements Summary

Produce a structured summary document:

```markdown
## Requirements Summary: [Feature Name]

### Problem Statement
[One paragraph describing the real problem—not the symptom]

### Success Criteria
- [ ] [Measurable outcome 1]
- [ ] [Measurable outcome 2]
- [ ] [Measurable outcome 3]

### Scope
**In scope:**
- [What's included]

**Out of scope:**
- [What's explicitly excluded]

### Constraints
**Hard:** [Non-negotiable limits]
**Soft:** [Preferences]

### Stakeholders
- **Decision maker:** [Who approves]
- **Users:** [Who uses it]
- **Informed:** [Who needs updates]

### Open Questions
- [Anything still unclear]

### Recommended Next Step
[Suggest /feature-dev, /brainstorm, or direct implementation]
```

Ask: **"Does this accurately capture what you need? Any corrections before we proceed?"**

---

## After Approval

Once the user confirms the requirements summary:
- For **complex features**: Suggest running `/feature-dev [feature name]`
- For **simpler tasks**: Suggest direct implementation
- For **unclear direction**: Suggest `/brainstorm` first

---

$ARGUMENTS
