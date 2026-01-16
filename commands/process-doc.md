# How-to Guide Generator

Generate How-to Guides following the Diataxis framework.

## Usage

```
/process-doc [topic]
```

**Examples:**
- `/process-doc` — Interactive mode
- `/process-doc device reboot` — Generate How-to Guide for rebooting a device
- `/process-doc azure-ad-setup` — Generate How-to Guide for Azure AD integration

---

## Diataxis Context

This skill generates **How-to Guides** — one of four Diataxis documentation types:

| Type | Purpose | This Skill? |
|------|---------|-------------|
| Tutorial | Learn by doing | No — use `/tutorial-doc` |
| **How-to Guide** | Accomplish a task | **Yes** |
| Reference | Look up information | No — use `/reference-doc` |
| Explanation | Understand concepts | No — use `/explanation-doc` |

**How-to Guide characteristics:**
- Task-oriented (reader has a specific goal)
- Assumes knowledge (not teaching, just doing)
- Numbered steps with verification
- Troubleshooting for when things go wrong

---

## Process Categories

How-to Guides fall into three categories:

| Category | Trigger | Human Role |
|----------|---------|------------|
| **Manual** | Human initiates | Active — performing steps |
| **Scheduled** | Timer/cron | Reactive — monitoring, intervening |
| **Event-driven** | System event | Reactive — monitoring, responding |

---

## Generation Workflow

### Phase 1: Topic Analysis

For the topic `$ARGUMENTS`:

1. **Identify the task** — What specific outcome is the reader trying to achieve?

2. **Determine process category:**
   - Is a human initiating this? → **Manual**
   - Does it run on a schedule? → **Scheduled**
   - Is it triggered by an event? → **Event-driven**

3. **Identify actors:**
   - External (customer, partner, end user)
   - Internal (team member, admin)
   - System (automated components)

### Phase 2: Information Gathering

Search the codebase for:
- Related documentation
- Implementation code
- CLI commands
- API endpoints
- Configuration files
- Existing troubleshooting notes

### Phase 3: Document Generation

Using the template at `~/.claude/commands/templates/documentation/how-to-guide.md`:

**For Manual processes:**
- "Step 1: [Human action]..."
- Numbered steps with verification
- Troubleshooting section

**For Scheduled/Event-driven processes:**
- "What happens automatically"
- "How to monitor"
- "How to respond to failures"
- "How to trigger manually"

**For Multi-party processes:**
- Part 1: External party steps
- Information handoff template
- Part 2: Internal steps

### Phase 4: Validation

Before finalizing, verify against Diataxis principles:

- [ ] Task-focused (not teaching concepts)
- [ ] Assumes prerequisite knowledge
- [ ] Steps are actionable and numbered
- [ ] Includes verification after critical steps
- [ ] Has troubleshooting section
- [ ] Links to related Reference/Explanation docs

---

## Anti-Patterns to Avoid

**Don't write a Tutorial disguised as a How-to Guide:**
- Tutorials teach concepts; How-to Guides accomplish tasks
- If you're explaining *why*, link to an Explanation instead

**Don't embed Reference material:**
- Don't list all options; show the one that accomplishes the task
- Link to Reference for complete specifications

**Don't offer too many choices:**
- Pick the recommended path
- Note alternatives briefly, don't detail them

---

## Related Skills

| Skill | Generates |
|-------|-----------|
| `/process-doc` | How-to Guide (this skill) |
| `/tutorial-doc` | Tutorial (planned) |
| `/reference-doc` | Reference (planned) |
| `/explanation-doc` | Explanation (planned) |

---

## Template Location

`~/.claude/commands/templates/documentation/how-to-guide.md`

---

## Further Reading

- https://diataxis.fr/how-to-guides/ — Diataxis guidance on How-to Guides
