---
name: documentation-standards
description: Enforces Diataxis documentation framework (Tutorial, How-to, Reference, Explanation)
version: 2.0.0
hooks:
  - event: PostToolUse
    tools: [Write, Edit]
    pattern: "**/docs/**/*.md"
---
# Diataxis Documentation Standards

When writing or editing documentation, classify it using the **Diataxis framework**:

```
              PRACTICAL                         THEORETICAL
                   │                                 │
   ┌───────────────┼─────────────────────────────────┼───────────────┐
   │               │                                 │               │
 A │   TUTORIAL    │    "Learning a craft"           │  EXPLANATION  │
 C │               │    Follow along, learn by doing │               │
 Q │               │                                 │  "Understanding
 U ├───────────────┼─────────────────────────────────┤   a topic"    │
 I │               │                                 │               │
 S │  HOW-TO GUIDE │    "Achieving a goal"           │  REFERENCE    │
 I │               │    Steps to accomplish task     │               │
 T │               │                                 │  "Looking up  │
 I │               │                                 │   information"│
 O │               │                                 │               │
 N └───────────────┴─────────────────────────────────┴───────────────┘
              DOING                            UNDERSTANDING
```

## Document Type Classification

**Ask: What is the reader's goal?**

| Type | Reader Goal | Opens With | Ends With |
|------|-------------|------------|-----------|
| **Tutorial** | "I want to learn X" | "In this tutorial, you will..." | Working example + next steps |
| **How-to Guide** | "I need to do X" | "This guide shows how to..." | Completed task + verification |
| **Reference** | "I need to look up X" | "This section documents..." | Complete, accurate information |
| **Explanation** | "I want to understand X" | "This explains why/how..." | Deeper understanding |

## Validation Checklists

### If This Is a TUTORIAL

Learning-oriented. The reader is acquiring skills.

- [ ] Has a clear learning objective stated upfront
- [ ] Provides a complete, working example to follow
- [ ] Steps are repeatable and produce consistent results
- [ ] Focuses on *learning*, not just *doing*
- [ ] Ends with a working result the reader built themselves
- [ ] Suggests next tutorials or related how-to guides

**Anti-patterns:**
- Explaining concepts mid-tutorial (→ link to Explanation instead)
- Offering choices or alternatives (→ pick one path for learning)
- Assuming prior knowledge not stated in prerequisites

---

### If This Is a HOW-TO GUIDE

Task-oriented. The reader is accomplishing a goal.

- [ ] Addresses a specific, real-world task
- [ ] Assumes the reader knows *what* they want, shows *how*
- [ ] Steps are numbered and actionable
- [ ] Includes verification after critical steps
- [ ] Covers the task completely (not just happy path)
- [ ] Has troubleshooting for common failures

**Process Categories:**

| Category | First Section |
|----------|---------------|
| **Manual** | "Step 1: [Human action]..." |
| **Scheduled** | "This runs automatically at [schedule]. To monitor..." |
| **Event-driven** | "Triggered when [event]. To monitor..." |

**Anti-patterns:**
- Teaching concepts (→ link to Tutorial or Explanation)
- Providing background (→ brief context only, link to Explanation)
- Multiple paths without clear recommendation

---

### If This Is a REFERENCE

Information-oriented. The reader is looking something up.

- [ ] Organized for quick lookup (alphabetical, by function, etc.)
- [ ] Consistent structure across all entries
- [ ] Accurate and complete (this is the source of truth)
- [ ] Describes *what*, not *why* or *how*
- [ ] Austere—no tutorials, no explanation, just facts

**Standard sections:**
- Signature/syntax
- Parameters/options
- Return value/output
- Examples (brief, illustrative)
- Related items

**Anti-patterns:**
- Explaining why something works (→ Explanation)
- Step-by-step procedures (→ How-to Guide)
- Learning sequences (→ Tutorial)

---

### If This Is an EXPLANATION

Understanding-oriented. The reader wants to *know* something.

- [ ] Clarifies a concept, decision, or design
- [ ] Provides context and background
- [ ] Connects to other concepts and the bigger picture
- [ ] Can discuss alternatives, tradeoffs, history
- [ ] Is discursive—explores the topic

**Standard approaches:**
- "Why does X work this way?"
- "The architecture of X"
- "X vs Y: when to use each"
- "The history/evolution of X"

**Anti-patterns:**
- Step-by-step procedures (→ How-to Guide)
- API specifications (→ Reference)
- Hands-on exercises (→ Tutorial)

---

## Document Header Template

Every document should declare its type:

```markdown
# [Title]

> **Type:** Tutorial | How-to Guide | Reference | Explanation
> **Last Updated:** YYYY-MM-DD
> **Related:** [Links to complementary doc types]
```

## Quick Decision Tree

```
What is the reader trying to do?
│
├─► Learn something new
│   └─► TUTORIAL
│
├─► Accomplish a specific task
│   └─► HOW-TO GUIDE
│
├─► Look up specific information
│   └─► REFERENCE
│
└─► Understand why/how something works
    └─► EXPLANATION
```

## Templates

- Tutorial: `~/.claude/commands/templates/documentation/tutorial.md`
- How-to Guide: `~/.claude/commands/templates/documentation/how-to-guide.md`
- Reference: `~/.claude/commands/templates/documentation/reference.md`
- Explanation: `~/.claude/commands/templates/documentation/explanation.md`

## Further Reading

- https://diataxis.fr/ — The canonical Diataxis documentation
