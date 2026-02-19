---
description: REQUIRED before proposing ANY solution to a complex problem. You MUST analyze before suggesting — jumping to solutions causes rework.
---

# Problem Analysis & Solution Design

Think hard before proposing solutions. This command enforces structured analysis.

## Phase 1: Analysis (DO NOT SKIP)

Before offering ANY solution:

1. **Root Cause Analysis**
   - What is the actual problem vs. the symptom?
   - Why does this problem exist?
   - What constraints are we working within?

2. **Context Review**
   - What existing code/patterns are relevant?
   - What has been tried before (check git history if applicable)?
   - What dependencies or side effects should we consider?

3. **Clarifying Questions**
   - List 2-5 questions that would change your approach if answered differently
   - Ask these questions and WAIT for responses

## PAUSE HERE

Do not proceed to Phase 2 until the user has answered your clarifying questions.

---

## Phase 2: Solution Design (After User Responds)

1. **Present 2-3 viable approaches** with trade-offs:
   - Approach A: [Description] - Pros/Cons
   - Approach B: [Description] - Pros/Cons
   - Approach C: [Description] - Pros/Cons

2. **Recommendation**: State which approach you'd recommend and why

3. **Verification Strategy**: How will we know the solution works?
   - What tests should pass?
   - What behavior should change?
   - What edge cases should we verify?

4. **Wait for approval** before implementing

## Integration

- **Pre-planning:** Use before `/blueprint` when the problem has multiple viable approaches
- **After `/review` verdict "Needs rethinking":** Explore alternatives
- **Feeds into:** `/blueprint` (approach becomes Stage 1 input), `/decision` (record chosen approach)
- **After approval:** Proceed to `/blueprint [name]` or `/describe-change` for triage
- **Insight capture:** If ★ Insight blocks were generated during brainstorming (rejected alternatives, surprising constraints, architectural discoveries), run `/collect-insights` to flush them to vault + Empirica before proceeding

---

$ARGUMENTS
