---
description: Use when you want a focused subagent to implement a single task with fresh context. Prevents context pollution from long sessions.
arguments:
  - name: task
    description: What to implement (quoted description or path to spec file)
    required: true
  - name: review
    description: "Enable two-stage review after implementation (--review)"
    required: false
  - name: model
    description: "Model for implementer: haiku, sonnet (default), opus"
    required: false
  - name: lenses
    description: "Additional review lenses after standard review (--lenses security,perf,arch)"
    required: false
  - name: plan-context
    description: "Plan name to pull context from (--plan-context feature-auth)"
    required: false
---

# Single-Task Subagent Dispatch

Dispatch one implementation task to a fresh subagent. The subagent starts with clean context (no accumulated session baggage), implements the task, and optionally runs through spec + quality review.

## When to Use

- Session has been long and context is cluttered
- Task is well-defined with clear acceptance criteria
- You want implementation isolated from previous work
- You want optional automated review before accepting changes

## Process

### Step 1: Parse Task

Determine the task source:

**If argument is a file path:**
```bash
# Read spec from file
cat [path]
```
Extract: description, acceptance criteria, target files, test commands.

**If argument is a quoted description:**
Ask for:
1. Acceptance criteria (what does "done" look like?)
2. Target files/paths
3. Test command (if applicable)

### Step 2: Gather Context

Before dispatching, collect context the implementer will need:

```bash
# Project conventions
cat CLAUDE.md .claude/CLAUDE.md 2>/dev/null

# Current state of target files
cat [target_files]

# Test framework detection (if tests needed)
cat package.json pyproject.toml Cargo.toml go.mod 2>/dev/null | head -50
```

### Step 3: Dispatch Implementer

Show dispatch plan and wait for approval:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DISPATCH │ Task: [description]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Target:    [files]
  Model:     [sonnet/haiku/opus]
  Review:    [enabled/disabled]
  Max turns: [15]

  Acceptance criteria:
    1. [criterion]
    2. [criterion]
    3. [criterion]

  Proceed? [y/n]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

On approval, invoke Task tool:

```
Task(
  subagent_type: "general-purpose",
  model: [selected_model],  // default: sonnet
  max_turns: 15,
  prompt: IMPLEMENTER_PROMPT (see below)
)
```

### Step 4: Collect Results

When the implementer returns:
1. Parse its report (files modified, test results, issues)
2. Display summary to user

If `--review` is NOT set:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DISPATCH COMPLETE │ [description]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Files modified:
    [file list with brief descriptions]

  Test results: [pass/fail/not run]

  Changes are in your working directory.
  Review manually or run: /dispatch [task] --review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 5: Review Pipeline (if --review)

**Stage 1: Spec Compliance (haiku)**

```
Task(
  subagent_type: "general-purpose",
  model: "haiku",
  max_turns: 5,
  prompt: SPEC_REVIEWER_PROMPT (see below)
)
```

- **PASS** → proceed to quality review
- **FAIL** → display issues, ask user:
  - [1] Re-dispatch to implementer with feedback (attempt 2/3)
  - [2] Fix manually
  - [3] Accept as-is

**Stage 2: Quality Review (haiku)**

```
Task(
  subagent_type: "general-purpose",
  model: "haiku",
  max_turns: 5,
  prompt: QUALITY_REVIEWER_PROMPT (see below)
)
```

- **PASS** → display final report
- **FAIL** → display issues, ask user:
  - [1] Re-dispatch to implementer with feedback (attempt 2/3)
  - [2] Fix manually
  - [3] Accept as-is

### Step 6: Lens Reviews (if --lenses)

After standard review passes, run additional review lenses:

Available lenses: `security`, `perf`, `arch`

For each specified lens, dispatch the corresponding agent (haiku model):

```
Task(
  subagent_type: "[security-reviewer|performance-reviewer|architecture-reviewer]",
  model: "haiku",
  max_turns: 5,
  prompt: [agent reads files and applies its mandate]
)
```

Lens results are **advisory** — they don't trigger re-dispatch. Display after standard review.

**If `--lenses` NOT specified but `--review` was used**, print reminder:
```
Review complete (spec: PASS, quality: PASS).
Tip: Additional lenses available: --lenses security,perf,arch
```

### Step 7: Plan Context (if --plan-context)

When `--plan-context [name]` is provided:
1. Read `.claude/plans/[name]/adversarial.md` — include adversarial findings summary in implementer prompt
2. Read `.claude/plans/[name]/tests.md` — include test criteria in implementer prompt
3. After completion, update `.claude/plans/[name]/state.json` field `execution` with results

This enriches the implementer with accumulated planning intelligence without requiring the full pipeline.

### Step 8: Final Report

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DISPATCH COMPLETE │ [description]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Implementation: ✓ Complete
  Spec Review:    ✓ Pass (attempt [N])
  Quality Review: ✓ Pass
  Lenses:         [security: PASS, perf: WARNING, arch: PASS]

  Files modified:
    [file:lines — brief description]

  Token usage: ~[estimate] (impl: [model], reviews: haiku)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Prompt Templates

### IMPLEMENTER_PROMPT

```
You are an IMPLEMENTATION AGENT working on a focused task. You have fresh context — no session history.

PROJECT CONVENTIONS:
{claude_md_content}

YOUR TASK:
{task_description}

ACCEPTANCE CRITERIA:
{criteria_list}

TARGET FILES:
{file_paths}

CURRENT FILE CONTENTS:
{current_file_contents}

TEST COMMAND:
{test_command_or_none}

RULES:
1. Read and understand the target files first
2. Implement ONLY what the criteria require (no extras, no refactoring)
3. Follow project conventions exactly
4. Run tests if a test command is provided
5. Do NOT add comments explaining what you did (the code should be clear)
6. Do NOT modify files outside the target list

WHEN COMPLETE, report:
- Files modified (with 1-line description each)
- Test results (pass/fail/skipped)
- Issues encountered (if any)
```

### SPEC_REVIEWER_PROMPT

```
You are a SPEC COMPLIANCE REVIEWER. Verify implementation matches specification EXACTLY.

You do NOT care about: code quality, style, performance, best practices.
You ONLY care about: does the code do what was specified?

SPECIFICATION:
{spec_text_or_criteria}

FILES TO REVIEW (read these):
{file_paths}

For each acceptance criterion:
1. Find the code that implements it
2. Verify it's correct and complete
3. Note anything missing or extra

RESPOND WITH:
- PASS: if ALL criteria are met
- FAIL: [specific discrepancies with file:line references]
```

### QUALITY_REVIEWER_PROMPT

```
You are a CODE QUALITY REVIEWER. Spec compliance is already verified — do NOT re-check it.

You do NOT care about: feature completeness, spec matching.
You ONLY care about: readability, bugs, conventions, security, complexity.

PROJECT CONVENTIONS:
{claude_md_content_or_inferred}

FILES TO REVIEW (read these):
{file_paths}

Check for:
- Logic errors, off-by-ones, race conditions
- Security vulnerabilities (injection, auth gaps)
- Convention violations
- Unnecessary complexity
- Poor error handling

RESPOND WITH:
- PASS: if no blocking issues found (warnings OK)
- FAIL: [specific issues with severity rating and file:line references]
```

---

## Retry Logic

- Max 3 attempts per task
- Each retry includes the previous review feedback in the implementer prompt
- After 3 failures: stop, display all feedback, let user fix manually

---

## Cost Awareness

| Operation | Model | Approximate Cost |
|-----------|-------|------------------|
| Implementation | sonnet | Moderate |
| Implementation | haiku | Low (for simple tasks) |
| Spec Review | haiku | Low |
| Quality Review | haiku | Low |
| Full pipeline (1 task) | sonnet + 2x haiku | Moderate |
| Full pipeline (3 retries) | 3x sonnet + 6x haiku | High |

Default model is `sonnet`. Use `--model haiku` for simple/boilerplate tasks.
