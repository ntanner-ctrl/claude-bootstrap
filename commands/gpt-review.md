---
description: Use for cross-model adversarial review when local challenge is insufficient. A second model catches blind spots a single model cannot.
allowed-tools: Read, Glob, Grep, Bash, AskUserQuestion, TodoWrite, WebFetch
argument-hint: [--analyze <pr-url>] | [--focus security|performance|architecture|all]
---

# GPT Adversarial Code Review

A collaborative adversarial review where Claude and GPT work as a surgical team:

- **Claude** = Head of surgery (diagnosis, architecture, surgical plan, final call)
- **GPT** = Top surgeon (technical precision, implementation, intraoperative findings)
- **Adversary** = The codebase's problems (not each other)

## Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 1: DIAGNOSIS                                                         │
│  Claude interviews user, explores codebase, identifies specific issues      │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 2: SURGICAL PLAN                                                     │
│  Claude generates prompt with diagnosis + priorities + latitude for GPT     │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 3: OPERATION (User bridges to ChatGPT Codex)                        │
│  GPT executes with technical precision, may find intraoperative issues     │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE 4: POST-OP REVIEW                                                    │
│  Claude analyzes GPT's work, validates, synthesizes, delivers verdict      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Detect Mode from Arguments

```
$ARGUMENTS → Check for --analyze flag

If --analyze <pr-url> present:
  → Jump to PHASE 4: POST-OP REVIEW
Else:
  → Start PHASE 1: DIAGNOSIS
```

---

# PHASE 1: DIAGNOSIS

## Step 1.1: Gather Context

Use AskUserQuestion to understand what needs review:

**Question 1: What repository/codebase?**
- Repository name or path
- Which branch to review
- Is this in GitHub? (for ChatGPT Codex compatibility)

**Question 2: What's the scope?**
Options:
- "Entire codebase" - Full adversarial audit
- "Specific feature/module" - Focused review (specify which)
- "Recent changes" - Review commits in a range
- "Specific concern" - I have a worry about something

**Question 3: What should GPT focus on?**
Options (multi-select):
- Security - Auth, injection, data exposure, OWASP top 10
- Performance - Efficiency, memory, N+1 queries, hot paths
- Architecture - Design patterns, SOLID, coupling, cohesion
- Error Handling - Edge cases, failure modes, recovery
- Maintainability - Readability, complexity, documentation
- Correctness - Logic errors, race conditions, off-by-one
- All of the above - Comprehensive adversarial review

**Question 4: Any specific concerns or context?**
Free-form input:
- "This handles payment processing"
- "We've had bugs in the auth flow before"
- "This is legacy code we're afraid to touch"
- "Performance is critical here"

## Step 1.2: Claude Explores and Diagnoses

**CRITICAL: Before generating the prompt, Claude MUST explore the codebase.**

This is not optional. Claude should:

1. **Map the structure** - Understand file layout, module boundaries
2. **Identify specific issues** - Not "might have problems" but "this file is 44KB, here's why that's bad"
3. **Prioritize findings** - What's critical vs nice-to-have
4. **Note architectural context** - Patterns in use, how things connect

Use tools: `Glob`, `Grep`, `Read`, `Bash` (for git history, line counts, etc.)

**Output of this step:** A concrete list of diagnosed issues with:
- File locations
- What's wrong
- Why it matters
- Suggested approach (not exact implementation—leave room for GPT's expertise)

Example diagnosis:
```
DIAGNOSED ISSUES:

1. GOD-MODULE: src-tauri/src/commands.rs (44KB, 1385 lines)
   Problem: Single file handles transactions, categories, budgets, rules
   Impact: Hard to maintain, test, reason about
   Approach: Split by domain into separate *_commands.rs modules
   Priority: HIGH

2. DUPLICATE CACHING: commands.rs has local lazy_static cache
   Problem: Duplicates caching.rs functionality, risks staleness
   Impact: Cache invalidation bugs, maintenance burden
   Approach: Route through centralized caching module
   Priority: MEDIUM

3. INCONSISTENT ERRORS: Mix of .map_err(|e| e.to_string()) patterns
   Problem: No structured error types for frontend to handle
   Impact: Poor UX, hard to debug
   Approach: Create AppError enum, consistent error handling
   Priority: MEDIUM
```

---

# PHASE 2: SURGICAL PLAN

## Step 2.1: Generate the Prompt

Based on diagnosis, construct the surgical plan for GPT:

```markdown
# SURGICAL PLAN: ADVERSARIAL CODE REVIEW

## Context
I've diagnosed this codebase. Below is my assessment and the surgical plan.
You are the operating surgeon—I'm handing you the scalpel.

## Our Roles
- **Me (Claude)**: Diagnosis, architectural assessment, priorities, final review
- **You (GPT)**: Technical implementation, precision fixes, intraoperative findings
- **Adversary**: The codebase's problems (not each other)

## Rules of Engagement
- Execute the surgical plan below with precision
- If you find issues I didn't diagnose, address them and document in your PR
- Your technical judgment matters—if you see a better approach, take it and explain why
- Don't do superficial work (formatting, comments) unless it serves a real fix
- Open a PR with real, substantive changes

## Pre-Op Diagnosis

{CLAUDE_DIAGNOSED_ISSUES}

### Issue 1: {ISSUE_TITLE}
- **Location:** {file_path}
- **Problem:** {what's wrong}
- **Impact:** {why it matters}
- **Suggested approach:** {direction, not exact steps—use your judgment}
- **Priority:** {CRITICAL/HIGH/MEDIUM}

### Issue 2: ...
[Additional diagnosed issues]

## Focus Areas
{USER_SELECTED_FOCUS_AREAS}

## Additional Context
{USER_PROVIDED_CONTEXT}

## Repository
{REPOSITORY_AND_BRANCH_INFO}

## Deliverables
1. Create a branch for your surgical work
2. Address the diagnosed issues above (in priority order)
3. Document any intraoperative findings (issues you discovered during implementation)
4. Open a PR with:
   - Clear title: "Adversarial Review: [Summary of changes]"
   - Description listing: diagnosed issues addressed, intraoperative findings, rationale
   - Severity categories: CRITICAL / SERIOUS / IMPROVEMENT
5. For issues requiring discussion (can't fix unilaterally), note in PR description

## Begin
Execute the surgical plan. Trust your technical expertise on the implementation details.
If you disagree with my diagnosis or see a better path, take it—and tell me why.
```

## Step 2.2: Present Prompt to User

Display the generated prompt in a copyable format:

```
════════════════════════════════════════════════════════════════════
                    ADVERSARIAL REVIEW PROMPT
════════════════════════════════════════════════════════════════════

[GENERATED PROMPT HERE]

════════════════════════════════════════════════════════════════════

NEXT STEPS:
1. Copy the prompt above
2. Go to ChatGPT Codex (or your preferred GPT coding interface)
3. Select repository: {REPO}
4. Select branch: {BRANCH}
5. Paste the prompt and let GPT work
6. Once GPT opens a PR, return here with:

   /gpt-review --analyze <pr-url>

════════════════════════════════════════════════════════════════════
```

---

# PHASE 3: OPERATION

User takes the surgical plan to ChatGPT Codex. GPT operates.

---

# PHASE 4: POST-OP REVIEW

## Step 4.1: Fetch PR Information

When user provides `--analyze <pr-url>`:

1. Parse PR URL to extract owner/repo/pr-number
2. Use `gh pr view` or WebFetch to get:
   - PR title and description
   - Files changed
   - Diff content
   - GPT's stated rationale

```bash
# Get PR diff
gh pr diff <pr-number> --repo <owner/repo>

# Get PR details
gh pr view <pr-number> --repo <owner/repo> --json title,body,files,additions,deletions
```

## Step 4.2: Analyze GPT's Changes

For each change GPT made, evaluate:

### Categorize Each Change
- **Legitimate Fix**: Real bug/vulnerability that needed fixing
- **Good Improvement**: Valid enhancement, not critical
- **Stylistic**: Preference-based, not substantive
- **Questionable**: Change may introduce new issues
- **Unnecessary**: Change doesn't improve anything
- **Wrong**: GPT misunderstood the code

### Check for Gaps
- What did GPT miss that Claude would have caught?
- Are there security issues GPT didn't address?
- Did GPT fix symptoms but miss root causes?

### Validate Fixes
- Do the fixes actually work?
- Are there edge cases GPT didn't consider?
- Did GPT introduce any new bugs?

## Step 4.3: Generate Consolidated Report

```markdown
# Adversarial Review Analysis

**PR Reviewed:** {PR_URL}
**GPT Model:** ChatGPT Codex
**Analyst:** Claude
**Date:** {DATE}

---

## Executive Summary

{1-2 sentence overview: How many changes, overall quality assessment}

---

## GPT's Changes - Claude's Assessment

### ✅ Legitimate Fixes (Recommend Merge)
| File | Change | Claude's Take |
|------|--------|---------------|
| {file} | {description} | {assessment} |

### ⚠️ Questionable Changes (Review Carefully)
| File | Change | Concern |
|------|--------|---------|
| {file} | {description} | {why this is questionable} |

### ❌ Changes to Reject
| File | Change | Reason |
|------|--------|--------|
| {file} | {description} | {why this should be reverted} |

### 📝 Stylistic Only (Optional)
{Changes that are preference-based, not bugs}

---

## What GPT Missed

{Issues Claude identified that GPT didn't catch or fix}

### Security Gaps
- {issue GPT missed}

### Logic Issues
- {issue GPT missed}

### Performance Concerns
- {issue GPT missed}

---

## Recommendations

### For This PR
- [ ] Merge as-is
- [ ] Merge with modifications: {specify}
- [ ] Request changes: {specify}
- [ ] Close without merging: {reason}

### Follow-up Actions
- [ ] {Additional fixes Claude recommends}
- [ ] {Areas needing more review}

---

## Verdict

{MERGE / REVISE / REJECT}

{Final recommendation with rationale}
```

## Step 4.4: Offer Next Steps

After delivering the report:

```
What would you like to do next?

1. Help implement Claude's recommended fixes
2. Generate comments for the PR
3. Create a follow-up review prompt for remaining issues
4. Done - I'll handle it from here
```

---

# USAGE EXAMPLES

```bash
# Start a new adversarial review (interactive)
/gpt-review

# Start with focus area specified
/gpt-review --focus security

# Analyze a PR that GPT opened
/gpt-review --analyze https://github.com/owner/repo/pull/123

# Analyze PR by number (assumes current repo)
/gpt-review --analyze 123
```

---

# NOTES

## Why This Workflow?

### The Surgical Team Model

Claude and GPT have complementary strengths:

| Claude | GPT |
|--------|-----|
| Architecture & vision | Technical precision |
| Diagnosis & prioritization | Implementation detail |
| Leadership & final call | Persistence & adherence |
| Seeing the forest | Cutting the trees |

Neither model is "better"—they're different instruments. This workflow composes them:
1. Claude diagnoses (what's wrong, why it matters, what direction to take)
2. GPT operates (precise implementation, may find things Claude missed)
3. Claude reviews (validates, synthesizes, decides)

### Why Pre-Diagnosis Matters

Without Claude's diagnosis, GPT tends to:
- Take the easy wins (find one issue, fix it, declare victory)
- Avoid risky refactors even when necessary
- Not challenge architectural decisions

With Claude's diagnosis, GPT gets:
- Clear priorities (fix THIS, not whatever looks easy)
- Permission to make substantive changes
- Latitude to exercise technical judgment on the "how"

### Why GPT's Autonomy Matters

If Claude over-specifies the implementation:
- We lose GPT's technical precision (they might know a better way)
- We lose intraoperative findings (things discovered during surgery)
- We reduce GPT to a typist, not a surgeon

The prompt gives direction + latitude, not paint-by-numbers.

## Best Practices

- **Claude must explore before generating the prompt** - No skipping diagnosis
- **Be specific about what's wrong** - Not "might have issues" but "this is broken because X"
- **Leave implementation details to GPT** - Direction, not dictation
- **Value GPT's intraoperative findings** - They may find things Claude missed
- **Don't auto-merge** - Claude always validates GPT's work

## Limitations

- Requires manual copy/paste between Claude and ChatGPT Codex
- GPT may not have full git history context
- Large codebases may need scoped reviews (not full audit)
- GPT may still play it safe on truly risky refactors
