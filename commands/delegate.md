---
description: Use when you have multiple independent tasks that can run in parallel. Delegates to best-fit subagents for concurrent execution. Use --plan for orchestrated multi-task implementation.
arguments:
  - name: tasks
    description: "Ad-hoc tasks to delegate, OR --plan [path] for orchestrated implementation"
    required: false
  - name: plan
    description: "Path to spec/plan file for orchestrated dispatch (--plan path/to/spec.md)"
    required: false
  - name: review
    description: "Enable two-stage review for each task (--review)"
    required: false
  - name: parallel
    description: "Max parallel agents (--parallel N, default 3)"
    required: false
  - name: lenses
    description: "Additional review lenses after standard review (--lenses security,perf,arch,cfn)"
    required: false
  - name: isolate
    description: "Use git worktrees for per-task isolation (--isolate)"
    required: false
  - name: plan-context
    description: "Plan name to pull context from (--plan-context feature-auth)"
    required: false
---

# Smart Task Delegation

Execute tasks using best-fit subagents. Two modes:

| Mode | Trigger | What It Does |
|------|---------|--------------|
| **Ad-hoc** | `/delegate [tasks]` | Quick parallel delegation |
| **Orchestrated** | `/delegate --plan [path]` | Plan → tasks → dispatch → review |

---

## Mode 1: Ad-hoc Delegation

For quick, informal parallel work without the full orchestration pipeline.

### Instructions

1. **If no task specified**: Check the current to-do list and execute pending items

2. **Analyze task requirements** and select appropriate subagent(s):
   - `Explore` - Codebase exploration, finding files, understanding architecture
   - `Plan` - Complex implementation planning requiring architectural decisions
   - `general-purpose` - Multi-step tasks, research, code search
   - Domain-specific agents if available (check /agents)

3. **For multiple independent tasks**: Launch subagents in parallel using the Task tool
   - Send a single message with multiple Task tool calls
   - Each agent works concurrently, maximizing throughput

4. **For dependent tasks**: Execute sequentially, passing context between agents

5. **Aggregate results**: Summarize what each agent accomplished and any issues found

### Guidelines

- Prefer parallel execution when tasks are independent
- Avoid testing unless explicitly requested
- If a task fails, report the failure and suggest next steps
- Keep the user informed of which agents are working on what

### Example

```
/delegate Explore the authentication system and Plan a new OAuth integration
```

---

## Mode 2: Orchestrated Dispatch

For structured, plan-based implementation with fresh subagents and optional review.

### Step 1: Parse Plan into Tasks

Read the plan/spec file and decompose into discrete implementation tasks:

```
Task decomposition from: [plan_path]

Found [N] tasks:
  1. [task description] → [target files]
  2. [task description] → [target files]
  3. [task description] → [target files]

File partitioning: [OK — no overlapping targets / WARNING — shared files detected]
```

**Rules for task decomposition:**
- Each task targets specific files (no overlap between parallel tasks)
- Each task has clear acceptance criteria (from spec)
- Tasks that share files MUST be sequential (not parallel)

### Step 2: Approval Gate

Display the execution plan and wait for user confirmation:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DELEGATE │ Orchestrated Dispatch
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Source:    [plan_path]
  Tasks:     [N]
  Parallel:  [max N concurrent]
  Review:    [enabled/disabled]
  Model:     [sonnet]

  Execution order:
    Batch 1 (parallel):
      • Task 1: [description] → [files]
      • Task 2: [description] → [files]
    Batch 2 (parallel):
      • Task 3: [description] → [files]
    Sequential:
      • Task 4: [description] → [files] (depends on Task 1)

  Estimated cost: [low/moderate/high]

  Proceed? [y/n/edit]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If user says "edit": allow task list modification before proceeding.

### Step 3: Dispatch Tasks

For each batch, dispatch implementer agents:

```
Task(
  subagent_type: "general-purpose",
  model: [selected_model],
  max_turns: 15,
  prompt: IMPLEMENTER_PROMPT + task_context
)
```

Display progress:
```
  [■■■□□] 3/5 tasks complete
    ✓ Task 1: Implement login endpoint
    ✓ Task 2: Implement logout endpoint
    ✓ Task 3: Add session model
    ► Task 4: Wire up middleware (in progress)
    ○ Task 5: Add integration tests
```

### Step 4: Review Pipeline (if --review)

After each task completes, run through review stages using `/dispatch`'s review logic:
- Spec review (haiku) → Quality review (haiku)
- If `--lenses` specified: run additional lens agents (haiku)
- Failures get re-dispatched (max 3 attempts)
- After 3 failures: mark task as "needs manual intervention" and suggest:
  ```
  Task [N] failed review 3 times. Suggestions:
    /debug [issue]     — Investigate root cause
    /design-check      — Verify task prerequisites
  ```

### Step 5: Human Checkpoint

After each BATCH completes (not each task — too noisy):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BATCH 1 COMPLETE │ [N] tasks done
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Results:
    ✓ Task 1: [summary] — [review status]
    ✓ Task 2: [summary] — [review status]
    ✗ Task 3: [issue] — needs manual fix

  Options:
    [1] Continue to Batch 2
    [2] Fix Task 3 first, then continue
    [3] Abort remaining tasks
    [4] /checkpoint — Save progress before continuing
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 6: Final Report

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DELEGATION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Plan: [plan_path]
  Tasks: [completed]/[total]
  Failed: [N] (manual intervention needed)

  Files modified:
    [aggregated file list]

  Review results:
    Spec compliance: [N]/[N] passed
    Quality review:  [N]/[N] passed

  Next steps:
    /quality-gate      — Score against full rubric
    /checkpoint        — Save context
    /push-safe         — Commit and push safely
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## File Conflict Prevention

Tasks that share target files CANNOT run in parallel. The decomposition step checks for overlapping file paths and sequences them:

```
Conflict detected:
  Task 2 and Task 4 both modify: src/auth/middleware.ts

Resolution: Task 4 will run AFTER Task 2 completes.
```

---

## Cost Controls

| Setting | Default | Purpose |
|---------|---------|---------|
| `--parallel N` | 3 | Max concurrent agents |
| `--model` | sonnet | Implementer model |
| Review model | haiku (fixed) | Keep review costs low |
| Max retries | 3 | Per-task retry limit |
| Max turns | 15 | Per-agent turn limit |

**Rough cost guide:**
- Simple task (no review): ~1 sonnet call
- Simple task (with review): ~1 sonnet + 2 haiku calls
- 5-task plan (with review): ~5 sonnet + 10 haiku calls
- 5-task plan (with retries): up to ~15 sonnet + 30 haiku calls

---

## Example Usage

### Ad-hoc (simple)
```
/delegate Explore the auth system and Plan a new OAuth integration
```

### Orchestrated (from plan)
```
/delegate --plan .claude/plans/feature-auth/spec.md --review
```

### Orchestrated (with cost controls)
```
/delegate --plan spec.md --parallel 2 --model haiku
```

### With review lenses
```
/delegate --plan spec.md --review --lenses security,perf
```

### With worktree isolation
```
/delegate --plan spec.md --review --isolate
```

### With plan context
```
/delegate --plan .claude/plans/feature-auth/spec.md --plan-context feature-auth --review
```

---

## Review Lenses (--lenses)

After standard two-stage review (spec + quality) passes, run additional lenses:

| Lens | Agent | Focus |
|------|-------|-------|
| `security` | security-reviewer | OWASP top 10, injection, auth gaps |
| `perf` | performance-reviewer | N+1 queries, blocking I/O, allocations |
| `arch` | architecture-reviewer | Layer violations, circular deps, cohesion |
| `cfn` | cloudformation-reviewer | Tagging, naming, security posture, CF best practices |

Lenses run on haiku model and are **advisory** — they don't trigger re-dispatch.

**If `--review` used but `--lenses` NOT specified**, print after standard review:
```
Review complete (spec: PASS, quality: PASS).
Tip: Additional lenses available: --lenses security,perf,arch,cfn,cfn
```

---

## Worktree Isolation (--isolate)

Isolates each task in a git worktree for independent review and accept/reject.

### When to Auto-Suggest

When the task decomposition detects file overlap AND more than 1 parallel task:
```
File overlap detected between tasks. Consider --isolate for independent review.
```

### How It Works

**1. Before dispatch: Create worktrees**
```bash
git worktree add .claude/worktrees/task-1 HEAD
git worktree add .claude/worktrees/task-2 HEAD
```

**2. Each subagent works in its worktree**

Add to implementer prompt:
```
WORKING DIRECTORY: [worktree-path]
All file paths are relative to this directory.
Do NOT run git commands.
```

**3. After all agents complete: Merge review**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ISOLATED DELEGATION │ Merge Review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Task 1 ([description]):
    +[N] -[N] across [N] files
    [accept] [reject] [diff]

  Task 2 ([description]):
    +[N] -[N] across [N] files
    [accept] [reject] [diff]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**4. User accepts/rejects each independently**

Accepted changes: copy modified files from worktree to main working directory.
Rejected changes: discard.

**5. Cleanup**
```bash
git worktree remove .claude/worktrees/task-1 --force
git worktree remove .claude/worktrees/task-2 --force
rmdir .claude/worktrees 2>/dev/null
```

The `worktree-cleanup.sh` SessionStart hook catches orphaned worktrees from interrupted sessions.

---

## Plan Context (--plan-context)

When `--plan-context [name]` is provided, enriches the dispatch with accumulated planning intelligence:

### What It Reads

| Artifact | Used For |
|----------|----------|
| `.claude/plans/[name]/adversarial.md` | Warnings about assumptions, edge cases to watch |
| `.claude/plans/[name]/tests.md` | Test criteria for verification |
| `.claude/plans/[name]/spec.md` | Acceptance criteria (if --plan not already specified) |

### What It Adds to Implementer Prompt

```
PLAN CONTEXT ([name]):

ADVERSARIAL FINDINGS (from /devils-advocate):
[summary of key warnings]

TEST CRITERIA (from /spec-to-tests):
[list of test assertions to satisfy]
```

### What It Writes Back

After delegation completes, updates `.claude/plans/[name]/state.json`:
```json
{
  "execution": {
    "method": "delegate",
    "tasks_completed": N,
    "tasks_failed": N,
    "review_results": { "spec": "pass", "quality": "pass" },
    "timestamp": "ISO-8601"
  }
}
```

### Standalone Behavior

Without `--plan-context`, delegate works exactly as before. The flag is purely additive.
