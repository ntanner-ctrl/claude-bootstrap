---
description: You MUST run this as the FIRST step of ANY implementation task. Determines required planning depth before you proceed.
arguments:
  - name: name
    description: Short name for this change (used for plan tracking)
    required: false
---

# Describe Change

Lightweight triage that determines how much planning infrastructure to invoke. **Start here** for any non-trivial change.

## Process

### Step 1: Describe the Change

Ask the user:

> **What are you changing?** (plain English, 1-2 sentences)

### Step 2: Break Down the Steps

Ask the user to list each discrete action:

> **What are the steps?**
>
> List each discrete action. One action per step.
> - "Update the database and notify users" = TWO steps
> - "Validate input then save" = TWO steps

**Actively identify combined movements.** When a step contains multiple actions, respond:

```
Step [N] looks like it combines multiple actions:
  "[their step]"

Suggested decomposition:
  [N]a. [first action]
  [N]b. [second action]

Does this decomposition look right, or is there a reason
these must be atomic?
```

**Red flags requiring decomposition:**

| Pattern | Example | Should Become |
|---------|---------|---------------|
| "X and Y" | "Update config and restart" | Two steps |
| "X then Y" | "Validate then save" | Two steps |
| "X, Y, Z" | "Fetch, transform, load" | Three steps |
| "X if Y" | "Delete if orphaned" | Check + delete |
| "X with Y" | "Create user with permissions" | Create + permission |
| Vague verbs | "Handle the migration" | Specific actions |

### Step 3: Quick Risk Scan

Present this checklist:

> **Does this change involve any of the following?**
>
> - [ ] Database schema or data migration
> - [ ] Authentication or authorization
> - [ ] Deletion of data or resources
> - [ ] External API contracts
> - [ ] Production environment
> - [ ] Financial transactions
> - [ ] User-facing behavior change
> - [ ] Security-sensitive operations

### Step 4: Determine Path

Based on step count and risk factors:

| Steps | Risk Flags | Recommended Path |
|-------|------------|------------------|
| 1-3   | None       | **Light** — `/preflight`, then execute |
| 1-3   | Any        | **Standard** — `/spec-change` required |
| 4-7   | None       | **Standard** — `/spec-change` required |
| 4-7   | Any        | **Full** — Complete planning protocol |
| 8+    | Any        | **Full** — Complete planning protocol |

### Step 5: Present Result

```markdown
## Triage Result

**Change:** [name or summary]
**Steps:** [count] discrete actions
**Risk flags:** [list or "None"]

**Recommended path:** [Light | Standard | Full]

---
Next steps:
  • Light path → `/preflight` then execute
  • Standard path → `/spec-change`
  • Full path → `/plan [name]` for guided workflow

Disagree with assessment? You can override with a reason.
```

## Override Handling

If the user wants to override the recommendation:

1. Ask for the reason
2. Note: "Override recorded. Proceeding with [chosen] path."
3. If tracking is enabled, log to `.claude/overrides.json`

## Output Artifacts

If a plan name was provided, create:
- `.claude/plans/[name]/describe.md` — This triage output
- `.claude/plans/[name]/state.json` — Initial state (stage 1)

## Integration

- **Feeds into:** `/spec-change`, `/preflight`, `/plan`
- **Fed by:** `/brainstorm` (if exploration happened first)
- **Tracks in:** `.claude/plans/[name]/` if named
