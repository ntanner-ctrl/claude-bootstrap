---
description: You MUST use this when requirements are fuzzy, the problem space is unclear, or you're about to plan something you don't fully understand. Skipping leads to blueprints built on assumptions.
arguments:
  - name: topic
    description: What needs clarification (problem, feature, or area of uncertainty)
    required: false
---

## Cognitive Traps

Before skipping or simplifying this command, check yourself:

| Rationalization | Why It's Wrong |
|----------------|---------------|
| "I already know what I need — just let me plan" | If you knew, you wouldn't be uncertain. /clarify exists because "I know" and "I can articulate it precisely" are different things. |
| "This will slow me down — I'll figure it out during implementation" | Ambiguity discovered during implementation costs 10x more to resolve than ambiguity discovered during clarification. |
| "The requirements are clear enough" | "Clear enough" is the most expensive phrase in engineering. What's obvious to you may be ambiguous to the spec. |

# Clarify

Guided pre-planning workflow that walks through clarification steps based on what's actually unclear. Not every step runs every time — assess the situation and skip what's already resolved.

## Overview

```
Step 1: Assess    → What's fuzzy? (requirements, approaches, boundaries, prior art)
Step 2: Brainstorm → /brainstorm (if multiple viable approaches exist)
Step 3: Discover   → /requirements-discovery (if requirements are unclear)
Step 4: Check      → /design-check (if implementation boundaries are fuzzy)
Step 5: Search     → /prior-art (if building something that might already exist)
Step 6: Summary    → Present what was clarified and recommend next action
```

## Process

### Step 1: Assess What's Fuzzy

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CLARIFY: [topic] │ Step 1 of 6: Assess
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Vault Check

Before assessing, check for prior work on this topic:

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null
```

If vault is available (`VAULT_ENABLED=1`, `VAULT_PATH` non-empty, `[ -d "$VAULT_PATH" ]`):
- Search for prior brainstorms, decisions, or findings related to the topic
- If matches found: "Vault has N notes related to this topic:" [list with 1-line summaries]
- If no matches: proceed silently

If vault unavailable: skip silently (fail-open). When `$ARGUMENTS` is empty, use conversation context keywords as search terms.

Before running anything, assess which dimensions are unclear. Ask the user:

```
What's unclear about this work?

  [A] Multiple approaches — not sure which direction to take
  [B] Requirements — not sure what "done" looks like
  [C] Boundaries — not sure what's in scope or what components are involved
  [D] Prior art — not sure if this already exists as a library/tool
  [E] All of the above / I don't know what I don't know

Pick one or more (e.g., "A and C"), or describe what feels fuzzy.
```

If $ARGUMENTS was provided, infer from context which dimensions apply. Present your assessment and ask for confirmation:

```
Based on "[topic]", it looks like:
  ✓ [A] Approaches — [reason this seems unclear]
  ✗ [B] Requirements — [reason this seems resolved]
  ...

Does this match your sense of what's fuzzy?
```

### Step 2: Brainstorm (if approaches are unclear)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CLARIFY: [topic] │ Step 2 of 6: Brainstorm
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Trigger:** User selected [A] or you assessed multiple viable approaches exist.
**Skip if:** The approach is obvious or already decided.

Run `/brainstorm $ARGUMENTS` — structured problem analysis that explores root causes, constraints, and solution alternatives.

After brainstorm completes, capture the key output:
- Recommended approach (or top 2-3 if still ambiguous)
- Constraints identified
- Questions surfaced

  Step 2 complete: [outcome summary]. Proceeding to Step 3.

### Step 3: Requirements Discovery (if requirements are unclear)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CLARIFY: [topic] │ Step 3 of 6: Requirements Discovery
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Trigger:** User selected [B] or requirements lack testable acceptance criteria.
**Skip if:** Requirements are already concrete and testable.

Run `/requirements-discovery $ARGUMENTS` — extracts validated requirements through structured questioning.

After discovery completes, capture:
- Validated requirements (with acceptance criteria)
- Assumptions that were surfaced and resolved
- Remaining open questions

  Step 3 complete: [outcome summary]. Proceeding to Step 4.

### Step 4: Design Check (if boundaries are fuzzy)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CLARIFY: [topic] │ Step 4 of 6: Design Check
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Trigger:** User selected [C] or scope/components are uncertain.
**Skip if:** Architecture, interfaces, and error strategy are already clear.

Run `/design-check $ARGUMENTS` — 6-point prerequisite validation (requirements, architecture, interfaces, errors, data, algorithms).

After check completes, capture:
- READY or BLOCKED verdict
- Specific gaps identified (if any)

  Step 4 complete: [outcome summary]. Proceeding to Step 5.

### Step 5: Prior Art Search (if building something new)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CLARIFY: [topic] │ Step 5 of 6: Prior Art Search
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Trigger:** User selected [D] or the work involves building a component that might already exist as a library/tool.
**Skip if:** This is clearly project-specific work with no general-purpose equivalent.

Run `/prior-art $ARGUMENTS` — searches GitHub and package registries for existing solutions.

After search completes, capture:
- Build vs. adopt recommendation
- Top candidates (if any)

  Step 5 complete: [outcome summary]. Proceeding to Step 6.

### Step 6: Summary & Next Action

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CLARIFY: [topic] │ Step 6 of 6: Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Present a structured summary of everything that was clarified:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CLARIFY │ Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Topic: [topic]

  Steps completed:
    [✓/✗] Brainstorm      [1-line outcome or "skipped — approach was clear"]
    [✓/✗] Requirements     [1-line outcome or "skipped — requirements concrete"]
    [✓/✗] Design Check     [1-line outcome or "skipped — boundaries clear"]
    [✓/✗] Prior Art        [1-line outcome or "skipped — project-specific work"]

  Key findings:
    - [finding 1]
    - [finding 2]
    - ...

  Open questions (if any):
    - [question]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Recommended next step:
    /describe-change [topic]  → Triage and determine planning depth
    /blueprint [topic]        → Jump to full planning if depth is obvious

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Failure Modes

| What Could Fail | Detection | Recovery |
|-----------------|-----------|----------|
| Brainstorm produces no viable approaches | Step 2 output is empty or single generic option | Rephrase the problem. Try `/requirements-discovery` to uncover hidden constraints. |
| Prior-art search unavailable (no WebSearch) | `/prior-art` reports tool unavailable | Skip Step 5, note in summary. User can search manually. |
| Requirements discovery stalls (user can't articulate criteria) | Step 3 loops without converging | Suggest concrete examples: "What would a successful version look like?" Break into sub-problems. |
| Vault search returns excessive results (50+) | Result list dominates context | Show only top 5 most recent. Note: "[N] additional results not shown." |
| All dimensions assessed as "clear" | Step 1 finds nothing fuzzy | This is a valid outcome. Recommend proceeding directly to `/describe-change`. |

## Known Limitations

- **Pre-planning only** — /clarify assesses what's fuzzy; it does not resolve ambiguity itself. Resolution happens in the sub-commands it invokes (/brainstorm, /requirements-discovery, etc.).
- **Single-topic scope** — Designed for one topic at a time. Cross-cutting concerns that span multiple systems should be decomposed first.
- **Vault search is keyword-based** — May miss relevant prior work if vocabulary differs from stored notes. Not a semantic search.
- **Conditional steps may under-explore** — If the initial assessment (Step 1) misjudges which dimensions are fuzzy, downstream steps are skipped. User can override by selecting dimensions manually.

## Integration

- **Feeds into:** `/describe-change`, `/blueprint`
- **Fed by:** Conversation context, user uncertainty
- **Called by:** `/blueprint` pre-stage (suggested when problem is fuzzy)
- **Insight capture:** Clarification often surfaces architectural insights. Run `/collect-insights` after completion.
