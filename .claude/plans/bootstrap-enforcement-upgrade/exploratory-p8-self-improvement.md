# Exploratory: Priority 8 - Self-Improvement Capability

## The Vision

Superpowers has `writing-skills` - a skill that teaches Claude how to write new skills. This means Superpowers can extend itself. Jesse has used this to add git worktree workflows by describing what he wanted.

The system improves itself.

## What This Would Mean for Claude-Bootstrap

A `/write-command` meta-command that:
1. Takes a description of desired behavior
2. Generates a properly-structured command file
3. Follows our patterns (frontmatter, MUST language, integration points)
4. Optionally: pressure-tests the new command

## Why This is Hard

### Challenge 1: Pattern Consistency
New commands must follow established patterns:
- Frontmatter format
- Description as trigger
- Integration with existing workflows
- Output artifact conventions

Claude would need to deeply understand our conventions.

### Challenge 2: Quality Assurance
How do you test a meta-command?
- Does the generated command work?
- Does it integrate properly?
- Is the trigger language effective?

### Challenge 3: Scope Creep
Once Claude can write commands, will it:
- Generate unnecessary commands?
- Duplicate existing functionality?
- Create conflicts?

## Potential Approaches

### Approach A: Template-Based Generation

Provide strict templates that Claude fills in:

```markdown
# /write-command

## Input Required
1. Command name
2. Trigger conditions (when should this run?)
3. Process steps
4. Integration points (what does it feed/get fed by?)

## Generation Process
1. Load template from `commands/templates/COMMAND-TEMPLATE.md`
2. Fill in sections based on input
3. Validate structure
4. Save to `commands/[name].md`
```

**Pro:** Consistent output
**Con:** Limited flexibility

### Approach B: Example-Based Learning

Have Claude study existing commands and extrapolate:

```markdown
# /write-command

## Process
1. Read 5 most similar existing commands
2. Identify patterns
3. Generate new command following patterns
4. Human review before adding
```

**Pro:** More adaptive
**Con:** May drift from conventions

### Approach C: TDD for Commands (like Superpowers)

Write pressure-test scenarios first, then generate command:

```markdown
# /write-command

## Process
1. Define: "What scenarios should trigger this command?"
2. Generate test prompts that should trigger it
3. Generate command
4. Run tests - does it trigger correctly?
5. Iterate until tests pass
```

**Pro:** Verified effectiveness
**Con:** Complex, time-consuming

## Research Questions

1. **Is this actually needed?** We already have 30+ commands. When would Claude need to generate more vs. humans adding them?

2. **What's the failure mode?** If a generated command is wrong, how bad is the impact?

3. **What guardrails?** Should generated commands go to a staging area for human review?

4. **Superpowers' experience?** How often does Jesse actually use writing-skills? For what?

## Recommendation

**Defer this until Priorities 1-4 are complete.**

The self-improvement capability is powerful but:
- Not blocking anything
- High risk of subtle bugs
- Better to have solid foundation first

Consider as a "Phase 2" enhancement after the enforcement upgrades prove effective.

## If We Do Pursue This

Minimal viable version:

1. Create `commands/templates/COMMAND-TEMPLATE.md` with blanks
2. Create `/write-command` that fills the template
3. Require human review before activating new command
4. Track generated vs. hand-written commands

Start constrained, expand if it proves useful.
