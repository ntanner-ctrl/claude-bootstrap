# P4 Research Findings: Subagent Orchestration

## Date: 2026-01-22

---

## Executive Summary

The Claude Code Task tool natively supports everything needed for the subagent orchestration architecture. The key simplification from the original spec: **we don't need custom agent types**. The `general-purpose` agent with embedded instructions in the prompt handles all roles (implementer, reviewer, analyzer).

---

## Capabilities Confirmed (Tested)

### 1. Fresh Context Per Invocation ✓

**Finding:** Each non-resumed Task invocation starts fresh. The agent receives:
- Its prompt (primary context)
- Working directory path
- Git status snapshot (from SESSION START — stale if session is long)

**Does NOT receive:**
- Parent conversation history
- Previous tool call results
- Previous agent results

**Test:** Spawned agent asked about session modifications — reported "unknown" for all conversation-specific questions. Only knew project name from working directory.

**Implication:** Implementer subagents start clean. No context pollution from parent session's failed attempts, debugging tangents, or accumulated assumptions.

### 2. Parallel Execution ✓

**Finding:** Multiple Task calls in a single message execute concurrently.

**Test:** Two agents dispatched simultaneously — both completed, no ordering dependency.

**Additional:** `run_in_background` parameter enables non-blocking execution. Results retrieved via `TaskOutput` tool or reading output files.

**Implication:** Multiple implementer tasks CAN run in parallel, but need file partitioning to avoid conflicts.

### 3. Full Tool Access ✓

**Finding:** `general-purpose` agent type has access to ALL tools (Read, Write, Edit, Bash, Glob, Grep, Task, etc.).

**Test:** Subagent successfully created a file and read it back.

**Implication:** Implementer agents can read specs, write code, run tests, and even spawn sub-subagents if needed.

### 4. Embedded Instructions Work ✓

**Finding:** The prompt parameter IS the agent's personality/instructions. A `general-purpose` agent given spec-reviewer instructions produces structured, compliant reviews.

**Test:** Embedded spec-reviewer instructions in prompt, pointed at real file (tdd-guardian.sh). Agent produced a thorough line-by-line verification with PASS/FAIL verdict.

**Implication:** We don't need plugin-defined agent types. Our existing agent `.md` files are prompt templates that get embedded in Task calls.

### 5. Model Selection ✓

**Finding:** The `model` parameter supports haiku, sonnet, and opus per-invocation.

**Cost implications:**
- `haiku` (~10x cheaper): Ideal for reviews, simple analysis
- `sonnet` (balanced): Good for implementation tasks
- `opus` (most capable): Complex architecture decisions

**Implication:** Reviews on haiku, implementation on sonnet. Significant cost optimization.

### 6. Agent Resume ✓

**Finding:** Each agent returns an `agentId`. Passing this as `resume` parameter continues the agent with full prior context.

**Implication:** Multi-turn implementation (read → plan → write → test → iterate) can span multiple coordinator turns if needed.

---

## Limitations Found

### 1. Can't Restrict Tools Per-Invocation

Agent type determines available tools. `general-purpose` always has ALL tools. We can't limit an agent to read-only.

**Mitigation:**
- Existing hooks (dangerous-commands, protect-claude-md, tdd-guardian) still apply
- Prompt instructions can tell agent what NOT to do
- Coordinator reviews results before they're final

### 2. No Direct Agent-to-Agent Communication

Agents can't message each other. All coordination goes through the parent coordinator.

**Mitigation:**
- This is actually fine for our pipeline architecture
- Coordinator collects implementer results → passes to reviewer
- Sequential pipeline prevents communication need

### 3. File Conflicts in Parallel Execution

If two agents edit the same file concurrently, the second edit may fail (stale content) or create conflicts.

**Mitigation:**
- Coordinator MUST partition work by file/module
- No two parallel agents should touch the same file
- Sequential fallback for tightly coupled tasks

### 4. Git Status Snapshot is Stale

Agents receive the git status from SESSION START, not current state. In long sessions with many commits, this is misleading.

**Mitigation:**
- Agent prompts should include explicit "current state" info
- Or agent can run `git status` itself (has Bash access)

### 5. Token Cost Per Agent

Each agent gets its own context window. A fresh agent processing a 500-line file still needs to read it (tokens consumed).

**Mitigation:**
- Keep tasks focused (2-5 files per task)
- Use haiku for reviews (cheap tokens)
- Token cost of fresh context < token cost of confused decisions from pollution

### 6. Max Turns Limit

The `max_turns` parameter caps API round-trips. Too low = agent can't finish. Too high = runaway costs.

**Recommended defaults:**
- Reviewer agents: `max_turns: 5` (read → analyze → report)
- Implementer agents: `max_turns: 15` (read spec → read code → plan → write → test → iterate)
- Simple dispatch: `max_turns: 3`

---

## Architecture Revision

### Original Design (from spec)

```
Custom agent types → Plugin infrastructure → Complex setup
```

### Revised Design (from research)

```
general-purpose agents → Embedded prompts → Works NOW
```

The architecture diagram from the spec is correct, but the implementation is simpler:

```
Coordinator (main session)
│
├─ Parse plan/spec into discrete tasks
│   - Partition by file/module (no overlap)
│   - Each task: {description, target_files, acceptance_criteria}
│
├─ Dispatch: Task(general-purpose, prompt=IMPLEMENTER_PROMPT + task, model=sonnet, max_turns=15)
│   - Parallel dispatch OK if tasks don't share files
│   - Background execution for long tasks
│
├─ Collect results (agent returns summary of changes)
│
├─ Review Stage 1: Task(general-purpose, prompt=SPEC_REVIEWER_PROMPT + spec + changes, model=haiku, max_turns=5)
│   - PASS → continue
│   - FAIL → re-dispatch to implementer with feedback
│
├─ Review Stage 2: Task(general-purpose, prompt=QUALITY_REVIEWER_PROMPT + changes, model=haiku, max_turns=5)
│   - PASS → task complete
│   - FAIL → re-dispatch with quality feedback
│
└─ Max 3 attempts per task. After 3 failures → escalate to human.
```

### Key Differences from Original Spec

| Aspect | Original | Revised |
|--------|----------|---------|
| Agent types | Custom plugin agents | `general-purpose` + prompts |
| Agent instructions | Separate `.md` files | Embedded in dispatch prompt |
| Infrastructure | Plugin registration | None needed |
| Review model | Not specified | `haiku` (cost optimization) |
| Implementation model | Not specified | `sonnet` (balanced) |
| Max turns | Not specified | 15 impl / 5 review |
| Resume support | Not considered | Available for multi-turn |

---

## Prompt Templates (For Implementation Phase)

### Implementer Prompt Template

```markdown
You are an IMPLEMENTATION AGENT. You receive a task specification and implement it.

RULES:
- Read the spec carefully before writing ANY code
- Write ONLY what the spec requires (no extras)
- Run tests after implementation if a test command is provided
- Report what files you modified and test results

TASK SPECIFICATION:
{task_description}

ACCEPTANCE CRITERIA:
{criteria_list}

TARGET FILES:
{file_paths}

TEST COMMAND (if applicable):
{test_command}

When complete, report:
1. Files modified (with brief description of changes)
2. Test results (pass/fail/not applicable)
3. Any issues encountered
```

### Spec Reviewer Prompt Template

```markdown
You are a SPEC COMPLIANCE REVIEWER. Verify implementation matches specification.

You do NOT care about: code quality, style, performance, best practices.
You ONLY care about: does the code do what was specified?

SPECIFICATION:
{spec_text}

FILES TO REVIEW:
{file_paths}

For each acceptance criterion, verify it's implemented. Report:
- PASS: All criteria met
- FAIL: [specific discrepancies with file:line references]
```

### Quality Reviewer Prompt Template

```markdown
You are a CODE QUALITY REVIEWER. Spec compliance already verified.

You do NOT care about: feature completeness, spec matching.
You ONLY care about: readability, bugs, conventions, security, complexity.

PROJECT CONVENTIONS (if available):
{claude_md_content}

FILES TO REVIEW:
{file_paths}

Report:
- PASS: No blocking issues
- FAIL: [specific issues with severity and file:line references]
```

---

## Open Questions Resolved

| Question (from spec) | Answer |
|----------------------|--------|
| Can we control context passed? | YES — prompt parameter only |
| Can we run parallel subagents? | YES — multiple Task calls in one message |
| Does subagent inherit parent context? | NO — fresh start (except env info) |
| Can we explicitly exclude context? | YES — don't put it in the prompt |
| Maximum subagent depth? | Not tested — likely limited |
| Rate limits? | Standard API rate limits apply |
| Token economics? | Higher per-task, but fewer retries |
| File conflicts? | YES — must partition work |

---

## Recommendation for Implementation Phase

1. **Start with `/dispatch`** — single-task dispatch is simpler, validates the pattern
2. **Then enhance `/delegate`** — multi-task builds on proven single-task
3. **Use existing agent `.md` files as reference** — but embed in prompts, don't try to invoke as types
4. **Model hierarchy:** haiku (review) → sonnet (implementation) → opus (architecture)
5. **Max 3 parallel tasks** — limits file conflicts and cost
6. **Human checkpoint after each batch** — not after each task (too noisy)

---

## Next Steps

- [ ] Create `/dispatch` command using these findings
- [ ] Create prompt templates as reusable components
- [ ] Enhance `/delegate` with plan parsing + dispatch
- [ ] Test with a real multi-task implementation
- [ ] Document token costs from real usage
