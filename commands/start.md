---
description: Use at the START of any session to orient. Assesses project state and recommends the optimal next action.
---

# Where to Begin

Quickly assess project state and recommend the optimal next task.

## Instructions

1. **Check active work** (first):
   - If `.claude/state-index.json` exists, read it for active plans/TDD/checkpoints
   - If active work exists, show `/dashboard`-style summary before git assessment
   - If a checkpoint exists, surface its `next_action` as the recommended task

2. **Query vault for prior knowledge** (fail-soft — skip if vault unavailable):
   - Use the Bash tool to source vault config:
     ```bash
     source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo "VAULT_ENABLED=$VAULT_ENABLED" && echo "VAULT_PATH=$VAULT_PATH"
     ```
   - If vault is available (`VAULT_ENABLED=1` and `VAULT_PATH` is set):
     - Get project name from git repo basename: `basename $(git rev-parse --show-toplevel 2>/dev/null)`
     - Use Grep tool to search `$VAULT_PATH` for `"^project: PROJECT_NAME"` in `*.md` files
     - Focus on `Engineering/Findings/` and `Engineering/Decisions/` directories
     - For up to 5 most recent matches, read frontmatter to extract:
       - `empirica_confidence` scores if present
       - `empirica_status` values (flag any marked `stale` or `contradicted`)
       - Brief summary of the finding/decision
     - Present vault context summary (see output format below)
   - If vault is unavailable, note: "No vault configured — skipping prior knowledge lookup"
   - If vault is available but no matches found, note: "No prior vault knowledge for this project"
   - If an Empirica session is active, suggest submitting preflight with vault context:
     ```
     Empirica session active. Submit preflight now with prior vault context:
       - N findings (M high-confidence, K need verification)
       - P decisions
     ```

3. **Assess current state** (in parallel):
   - `git status` - Check for uncommitted changes
   - `git log -3 --oneline` - Review recent commits
   - Check for existing to-do list items
   - Scan for TODO/FIXME comments in recently modified files

4. **Identify what's pending**:
   - Uncommitted work in progress
   - Failed tests or build issues
   - Open to-do items from previous sessions
   - Obvious next steps from recent commits

5. **Recommend the optimal next task**:
   - State the single most impactful thing to work on
   - Explain briefly why this is the priority
   - Estimate complexity (quick fix vs. significant work)

6. **Offer alternatives**:
   - If the recommendation doesn't fit, list 2-3 other options

## Output Format

```
## Current State
[Brief summary of git status, recent work]

## Prior Vault Knowledge
[If vault available and matches found:]
  Found N findings, P decisions for PROJECT_NAME:
  - [Finding title] (confidence: 0.X) [STALE if applicable]
  - [Decision title] (confidence: 0.X)
  ...
  Preflight suggestion: Submit with context above.
[If vault unavailable: "No vault configured — skipped"]
[If no matches: "No prior vault knowledge for this project"]

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
