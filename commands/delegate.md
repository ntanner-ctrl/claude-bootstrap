---
description: Use when you have multiple independent tasks that can run in parallel. Delegates to best-fit subagents for concurrent execution.
---

# Smart Task Delegation

Execute tasks using best-fit subagents for parallel work.

## Instructions

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

## Guidelines

- Prefer parallel execution when tasks are independent
- Avoid testing unless explicitly requested
- If a task fails, report the failure and suggest next steps
- Keep the user informed of which agents are working on what

## Example Usage

```
/delegate Explore the authentication system and Plan a new OAuth integration
```

This would launch Explore to understand existing auth, then Plan to design the OAuth addition.

---

$ARGUMENTS
