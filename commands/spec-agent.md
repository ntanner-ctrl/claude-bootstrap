---
description: Create a specification for a new agent before implementation
arguments:
  - name: name
    description: Name of the agent to specify
    required: true
---

# Spec Agent

Define a new agent with explicit inputs, outputs, constraints, and integration points. Prevents scope creep and clarifies boundaries before implementation.

## Process

Guide the user through each section.

### Section 1: Role

> **What does this agent do? (one sentence)**

The role should be:
- Specific enough to know when to use it
- General enough to not be a one-off script

### Section 2: Trigger Conditions

> **When should this agent activate?**

- **Explicit invocation:** `/command-name` or direct request
- **Automatic trigger:** [condition that fires it]
- **Never triggers when:** [constraint]

### Section 3: Inputs

> **What does this agent need to work?**

| Input | Source | Required? | Validation |
|-------|--------|-----------|------------|
| [input] | [where from] | Yes/No | [how to validate] |

### Section 4: Outputs

> **What does this agent produce?**

| Output | Format | Destination |
|--------|--------|-------------|
| [output] | [format] | [where it goes] |

### Section 5: Constraints (Critical)

> **What must this agent NOT do?**
>
> Explicit boundaries prevent scope creep. Be specific.

- Must not: [constraint]
- Must not: [constraint]
- Must not: [constraint]

Common constraints to consider:
- Must not modify files (read-only)
- Must not access network
- Must not run longer than X
- Must not make decisions for the user
- Must not access [sensitive area]

### Section 6: Success State

> **How do we know the agent succeeded?**

- [ ] [observable outcome]
- [ ] [observable outcome]

### Section 7: Failure States

> **What does failure look like, and how should the agent respond?**

| Failure Mode | Detection | Response |
|--------------|-----------|----------|
| [failure] | [how to detect] | [what to do] |

### Section 8: Integration Points

> **How does this agent connect to other tools?**

- **Upstream (feeds into this agent):** [what triggers/prepares it]
- **Downstream (this agent feeds):** [what uses its output]
- **Conflicts with:** [incompatible agents/tools]

### Section 9: Example Session

> **Show a concrete input → output example.**

**Input:**
```
[realistic example input]
```

**Expected Output:**
```
[realistic example output]
```

### Section 10: Senior Review Simulation

> **What would an experienced developer flag?**

- **Scope creep risk:** [where might this grow beyond its role?]
- **Edge case:** [what unusual input might break this?]
- **Alternative approach:** [is there a simpler way?]

## Output Format

```yaml
---
name: [agent-name]
description: [one-line description for agent selection]
model: sonnet  # or haiku for simple tasks, opus for complex
tools:
  - [tool1]
  - [tool2]
---

# [Agent Name]

## Role

[one sentence role definition]

## Trigger Conditions

- Explicit invocation: `/[command]`
- Automatic trigger: [condition]
- Never triggers when: [constraint]

## Inputs

| Input | Source | Required? | Validation |
|-------|--------|-----------|------------|
| ... | ... | ... | ... |

## Outputs

| Output | Format | Destination |
|--------|--------|-------------|
| ... | ... | ... |

## Constraints

- Must not: ...
- Must not: ...
- Must not: ...

## Success State

- [ ] ...
- [ ] ...

## Failure States

| Failure Mode | Detection | Response |
|--------------|-----------|----------|
| ... | ... | ... |

## Integration Points

- Upstream: ...
- Downstream: ...
- Conflicts with: ...

## Example Session

**Input:**
\`\`\`
[example]
\`\`\`

**Output:**
\`\`\`
[example]
\`\`\`
```

## Output Artifacts

Save to appropriate location:
- Project-specific: `.claude/agents/[name].md`
- Global: `~/.claude/agents/[name].md`
- Bootstrap toolkit: `commands/templates/stock-agents/[name].md`

---
Specification complete. Next:
  • Review constraints → Are they specific enough?
  • Test with example → Does the example cover the role?
  • Implement → Create the agent file
