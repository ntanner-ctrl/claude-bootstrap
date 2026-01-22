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
- Failures get re-dispatched (max 3 attempts)
- After 3 failures: mark task as "needs manual intervention"

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

  Duration: [time]
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
