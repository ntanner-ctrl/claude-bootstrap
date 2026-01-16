# Where to Begin

Quickly assess project state and recommend the optimal next task.

## Instructions

1. **Assess current state** (in parallel):
   - `git status` - Check for uncommitted changes
   - `git log -3 --oneline` - Review recent commits
   - Check for existing to-do list items
   - Scan for TODO/FIXME comments in recently modified files

2. **Identify what's pending**:
   - Uncommitted work in progress
   - Failed tests or build issues
   - Open to-do items from previous sessions
   - Obvious next steps from recent commits

3. **Recommend the optimal next task**:
   - State the single most impactful thing to work on
   - Explain briefly why this is the priority
   - Estimate complexity (quick fix vs. significant work)

4. **Offer alternatives**:
   - If the recommendation doesn't fit, list 2-3 other options

## Output Format

```
## Current State
[Brief summary of git status, recent work]

## Recommended Next Task
**[Task description]**
Why: [1-2 sentence rationale]
Complexity: [Quick/Medium/Significant]

## Alternatives
- [Option 2]
- [Option 3]
```

---

$ARGUMENTS
