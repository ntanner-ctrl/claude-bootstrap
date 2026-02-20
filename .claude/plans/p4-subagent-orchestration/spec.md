# Priority 4: Subagent Orchestration

## Full Specification

### Summary

Implement subagent-driven development that spawns fresh Claude instances for implementation tasks, preventing context pollution and enabling parallel work with two-stage review (spec compliance + code quality).

---

## What Changes

### Files/Components Touched

| File | Nature of Change |
|------|------------------|
| `commands/delegate.md` | Modify - major enhancement for orchestration |
| New: `commands/dispatch.md` | Add - single-task subagent dispatch |
| New: `agents/implementer.md` | Add - implementation subagent template |
| New: `agents/spec-reviewer.md` | Add - spec compliance reviewer |
| New: `agents/quality-reviewer.md` | Add - code quality reviewer |
| New: `docs/SUBAGENT-ORCHESTRATION.md` | Add - architecture guide |

### External Dependencies
- Requires understanding of Claude Code's Task tool / subagent API
- May need MCP integration for advanced orchestration

### Database/State Changes
- Orchestration state in `.claude/orchestration/[session-id]/`
- Task queue and results tracking

---

## The Problem: Context Pollution

After extended coding sessions, Claude's context fills with:
- Previous failed attempts
- Old file versions
- Debugging tangents
- Accumulated assumptions

This leads to confused decisions. Superpowers solves this with **fresh subagents per task** - each implementer starts clean.

---

## Research Required: Claude Code Subagent Capabilities

**BEFORE designing, we must answer:**

1. **How does the Task tool work?**
   - What context does a subagent receive?
   - Can we control what context is passed?
   - How do results come back?

2. **Can we spawn truly fresh contexts?**
   - Does subagent inherit parent context?
   - Can we explicitly exclude context?
   - What's the token cost?

3. **Parallel execution?**
   - Can multiple subagents run simultaneously?
   - How is coordination handled?
   - What about file conflicts?

4. **Limitations?**
   - Maximum subagent depth?
   - Rate limits?
   - Context size per subagent?

**Research tasks:**
- [ ] Read Claude Code documentation on Task tool
- [ ] Experiment with subagent context inheritance
- [ ] Test parallel task execution
- [ ] Document observed limitations

---

## Proposed Architecture (Pending Research)

```
┌─────────────────────────────────────────────────────────────┐
│                      COORDINATOR                             │
│  (Main Claude session - maintains high-level context)       │
│                                                              │
│  Responsibilities:                                           │
│  • Parse plan into discrete tasks                           │
│  • Dispatch tasks to subagents                              │
│  • Collect and merge results                                │
│  • Track overall progress                                   │
│  • Route through review pipeline                            │
└─────────────────────────────────────────────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │ IMPLEMENTER │ │ IMPLEMENTER │ │ IMPLEMENTER │
    │  (Task 1)   │ │  (Task 2)   │ │  (Task 3)   │
    │             │ │             │ │             │
    │ Fresh ctx   │ │ Fresh ctx   │ │ Fresh ctx   │
    │ Task spec   │ │ Task spec   │ │ Task spec   │
    │ File access │ │ File access │ │ File access │
    └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
           │               │               │
           └───────────────┼───────────────┘
                           ▼
                  ┌─────────────────┐
                  │  SPEC REVIEWER  │
                  │                 │
                  │ Does impl match │
                  │ the plan spec?  │
                  └────────┬────────┘
                           │
                  ┌────────┴────────┐
                  │ Pass?           │
                  ├──► Yes ─────────┼──────────────┐
                  └──► No ──────────┘              │
                       │                           ▼
                       │ Return to             ┌─────────────────┐
                       │ implementer           │ QUALITY REVIEWER│
                       ▼                       │                 │
                  (Fix loop)                   │ Is code clean,  │
                                               │ well-structured?│
                                               └────────┬────────┘
                                                        │
                                               ┌────────┴────────┐
                                               │ Pass?           │
                                               ├──► Yes ─────────┼─► DONE
                                               └──► No ──────────┘
                                                    │
                                                    ▼
                                               (Fix loop)
```

---

## Two-Stage Review Design

### Stage 1: Spec Compliance Review

**Agent prompt:**
```markdown
You are a SPEC COMPLIANCE REVIEWER. Your ONLY job is to verify
that the implementation matches the specification.

You do NOT care about:
- Code quality
- Style
- Performance
- Best practices

You ONLY care about:
- Does the code implement what was specified?
- Are all acceptance criteria met?
- Is anything missing from the spec?
- Is anything added that wasn't in the spec?

Respond with:
- PASS: Implementation matches spec
- FAIL: [specific discrepancies]
```

### Stage 2: Code Quality Review

**Agent prompt:**
```markdown
You are a CODE QUALITY REVIEWER. The implementation has already
passed spec compliance. Your job is different.

You do NOT care about:
- Whether it matches a spec
- Feature completeness

You ONLY care about:
- Is the code clean and readable?
- Are there obvious bugs or issues?
- Does it follow project conventions?
- Are there security concerns?
- Is error handling adequate?

Respond with:
- PASS: Code quality acceptable
- FAIL: [specific quality issues]
```

**Why separate?** One reviewer doing both tends to conflate concerns. Separation catches:
1. "Built the wrong thing well" (spec reviewer catches)
2. "Built the right thing poorly" (quality reviewer catches)

---

## Command Interface

### `/dispatch` - Single Task

```bash
/dispatch "Implement user login validation" --spec path/to/spec.md --target src/auth/
```

Dispatches one task to an implementer subagent, routes through review.

### Enhanced `/delegate` - Multi-Task Orchestration

```bash
/delegate --plan path/to/plan.md [--parallel N] [--review strict|advisory]
```

Parses plan into tasks, dispatches to subagents, coordinates results.

---

## Orchestration State

`.claude/orchestration/[session-id]/state.json`:
```json
{
  "session_id": "uuid",
  "plan_source": ".claude/plans/feature-auth/spec.md",
  "mode": "parallel",
  "max_parallel": 3,
  "review_mode": "strict",
  "tasks": [
    {
      "id": "task-1",
      "description": "Implement login endpoint",
      "status": "complete",
      "implementer_result": "success",
      "spec_review": "pass",
      "quality_review": "pass",
      "attempts": 1
    },
    {
      "id": "task-2",
      "description": "Implement logout endpoint",
      "status": "in_review",
      "implementer_result": "success",
      "spec_review": "pending",
      "quality_review": "pending",
      "attempts": 1
    },
    {
      "id": "task-3",
      "description": "Add session management",
      "status": "in_progress",
      "attempts": 1
    }
  ],
  "checkpoints": []
}
```

---

## Preservation Contract

- **Existing delegate:** Current `/delegate` functionality preserved
- **Manual work:** User can still implement directly without orchestration
- **Review integration:** Builds on existing code-reviewer patterns

---

## Success Criteria

| Criterion | How to Verify |
|-----------|---------------|
| Fresh context per task | Subagent doesn't reference previous task context |
| Spec review catches drift | Deliberately implement wrong thing → caught |
| Quality review catches issues | Deliberately write bad code → caught |
| Parallel execution works | Multiple tasks run simultaneously |
| Coordination is reliable | No lost tasks, all results collected |

---

## Failure Modes

| What Could Fail | Detection | Recovery |
|-----------------|-----------|----------|
| Subagent API doesn't support fresh context | Research phase | Redesign with context pruning |
| File conflicts in parallel | Race conditions | Sequential fallback or locking |
| Review loops infinitely | Attempt counter | Max attempts, escalate to human |
| Task parsing fails | Malformed plans | Validation step, human fallback |
| Token costs explode | Bill shock | Budgets, warnings, throttling |

---

## Rollback Plan

1. New commands are additive - can just not use them
2. Original delegate functionality preserved
3. All orchestration state is in `.claude/orchestration/` - deletable

---

## Open Questions

1. **Token economics:** Is fresh context per task cost-effective, or does it burn more tokens than context pollution saves?

2. **Task granularity:** How small should tasks be? Superpowers says "2-5 minutes." How do we enforce that?

3. **Failure handling:** What happens when an implementer fails repeatedly? When to escalate?

4. **Human checkpoints:** Where should humans be able to intervene? After each task? After each batch?

5. **Integration with TDD:** Should implementer subagents be in TDD mode by default?

---

## Senior Review Simulation

- **They'd ask:** "What's the token cost compared to monolithic sessions?"
  - Answer: Need to measure. Hypothesis: higher per-task, lower overall due to fewer retries

- **Non-obvious risk:** Subagents may not have enough context to make good decisions
  - Mitigation: Careful context passing, spec documents as primary input

- **Standard approach:** Most orchestration systems use human review, not AI review
  - Counter: AI review is faster, but have human checkpoint options

- **What bites first-timers:** Thinking orchestration is magic
  - Mitigation: Clear docs on what coordinator can/can't do

---

## Implementation Steps

### Phase 1: Research (2-3 hours) **DO THIS FIRST**
1. Document Task tool capabilities
2. Test context inheritance
3. Test parallel execution
4. Identify hard limitations

### Phase 2: Review Agents (2 hours)
1. Create spec-reviewer agent
2. Create quality-reviewer agent
3. Test review accuracy

### Phase 3: Single-Task Dispatch (2 hours)
1. Create `/dispatch` command
2. Implement task → implementer → reviews flow
3. Handle retry logic

### Phase 4: Multi-Task Orchestration (3-4 hours)
1. Enhance `/delegate` with plan parsing
2. Implement parallel dispatch
3. Implement result collection
4. Add human checkpoints

### Phase 5: Integration & Polish (2 hours)
1. Connect to `/plan` workflow
2. Add monitoring/status views
3. Documentation

---

**Estimated Total Effort:** 2-3 dedicated sessions
**Dependencies:** Research phase is blocking
**Blocks:** Nothing - but enables more sophisticated workflows
**Risk Level:** High (depends on Claude Code capabilities we don't fully know)

---

## Research First Approach

Given the unknowns, this priority should follow:

```
Session 1: Research + Proof of Concept
  • Document Task tool thoroughly
  • Build minimal dispatch POC
  • Determine what's actually possible

Session 2: Design Refinement
  • Adjust design based on research findings
  • May need to significantly revise architecture

Session 3+: Implementation
  • Based on validated design
```

**DO NOT skip the research phase.** The design above assumes capabilities that may not exist.
