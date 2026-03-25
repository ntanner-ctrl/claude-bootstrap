---
description: You MUST use this when requirements are fuzzy, the problem space is unclear, or you're about to plan something you don't fully understand. Skipping leads to blueprints built on assumptions.
arguments:
  - name: topic
    description: What needs clarification (problem, feature, or area of uncertainty)
    required: false
---

## State Management

### State Initialization

At wizard entry, before any other work:

```
1. Ensure .claude/wizards/ exists (mkdir -p equivalent)
2. Check for active session: glob .claude/wizards/clarify-*/state.json
   - Exclude _archive/ paths (active glob matches clarify-<id>/state.json at top level only)
   - If multiple matches: select most recent by session_id timestamp, archive others
3. If active session found:
   a. Read state.json — if version != 1, treat as corrupt → start fresh
   b. Display stage progression header with session age:
      "Previous clarify session from [N hours/minutes ago]"
      If age > 4 hours: prominently note staleness
   c. Prompt:
        [1] Resume from [current_step]
        [2] Abandon and start fresh
4. If error session found (status == "error"):
   Display:
     Previous session errored at [step name].
       [1] Resume from last complete step
       [2] Abandon and start fresh
   On resume: set current_step to step AFTER the last complete step (do not re-run the failed step automatically)
5. If no active/error session (or prior session was complete/abandoned):
   Create .claude/wizards/clarify-<YYYYMMDD-HHMMSS>/state.json with:
   {
     "wizard": "clarify",
     "version": 1,
     "session_id": "clarify-<YYYYMMDD-HHMMSS>",
     "status": "active",
     "current_step": "vault_check",
     "steps": {
       "vault_check":   { "status": "pending" },
       "assess":        { "status": "pending" },
       "brainstorm":    { "status": "pending", "conditional": true },
       "requirements":  { "status": "pending", "conditional": true },
       "design_check":  { "status": "pending", "conditional": true },
       "prior_art":     { "status": "pending", "conditional": true },
       "summary":       { "status": "pending" }
     },
     "context": {
       "topic": "<$ARGUMENTS or inferred topic>",
       "selected_paths": [],
       "vault_findings": []
     },
     "vault_checkpoints": [],
     "created_at": "<ISO-8601>",
     "updated_at": "<ISO-8601>"
   }
6. Run cleanup: for each .claude/wizards/clarify-*/state.json where age > 7 days
   AND status in (complete, abandoned, error): move directory to .claude/wizards/_archive/
   If age > 7 days AND status == "active": log warning, do NOT auto-archive
7. Display initial stage progression header (see Stage Progression Display below)
```

### Stage Progression Display

Render after each step transition and on resume:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CLARIFY │ [topic] │ Step: [current step label]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✓ Vault Check
  ✓ Assess
  → Brainstorm
  ○ Requirements
  — Design Check  (not selected)
  — Prior Art     (not selected)
  ○ Summary

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Status symbols: `✓` complete, `→` active, `○` pending, `—` skipped (conditional, not selected).
Generate display from state.json steps object — read status values, render accordingly.

### Resume Protocol

On resume (user chose [1]):

```
1. Reconstruct context from state.json:
   - topic: from context.topic
   - selected_paths: from context.selected_paths (which A/B/C/D were chosen)
   - vault_findings: from context.vault_findings
   - Prior step outcomes: from output_summary of each complete step
2. For conditional steps (brainstorm/requirements/design_check/prior_art):
   - If status == "skipped": do not re-run
   - If status == "active": treat as pending, re-run from start of that step
3. Continue from current_step
4. All prior output_summaries serve as compressed context — do not re-run complete steps
```

Content contract for output_summaries (per WIZARD-STATE.md):

| Step | output_summary MUST include | Budget |
|------|---------------------------|--------|
| vault_check | Related finding count, relevant titles | ~50 tokens |
| assess | Which paths selected (A/B/C/D) and one-sentence rationale for each | ~100 tokens |
| brainstorm | Approach count, recommended approach, key trade-off | ~150 tokens |
| requirements | Requirement count, ambiguity count, key gaps | ~150 tokens |
| design_check | Prerequisites met/missing, key concern | ~100 tokens |
| prior_art | Recommendation (adopt/adapt/inform/build), top candidate | ~100 tokens |
| summary | Key outcomes, recommended next action | ~100 tokens |

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

**After vault_check completes:** Update state.json:
- Set `steps.vault_check.status` = "complete", record `completed_at`
- Write `steps.vault_check.output_summary`: related finding count + relevant titles (~50 tokens)
- Update `context.vault_findings`: array of finding slugs found (empty array if none)
- Set `current_step` = "assess", `updated_at` = now
- Display updated stage progression header

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

**After assess completes (user confirms which paths):** Update state.json:
- Set `steps.assess.status` = "complete", record `completed_at`
- Write `steps.assess.output_summary`: list selected paths with one-sentence rationale each (~100 tokens)
- Update `context.selected_paths`: array of selected letters (e.g., ["A", "B"])
- For each conditional step NOT selected: set status = "skipped", add `skip_reason` = "Not selected in assessment"
- Set `current_step` = first selected conditional step (or "summary" if none selected)
- Update `updated_at`
- Display updated stage progression header showing skipped steps as `—`

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

**After brainstorm completes:** Update state.json:
- Set `steps.brainstorm.status` = "complete", record `completed_at`
- Write `steps.brainstorm.output_summary`: approach count, recommended approach, key trade-off (~150 tokens)
- Set `current_step` = next selected step or "summary" if no more selected conditional steps remain
- Update `updated_at`
- Display updated stage progression header

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

**After requirements completes:** Update state.json:
- Set `steps.requirements.status` = "complete", record `completed_at`
- Write `steps.requirements.output_summary`: requirement count, ambiguity count, key gaps (~150 tokens)
- Set `current_step` = next selected step or "summary" if no more selected conditional steps remain
- Update `updated_at`
- Display updated stage progression header

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

**After design_check completes:** Update state.json:
- Set `steps.design_check.status` = "complete", record `completed_at`
- Write `steps.design_check.output_summary`: prerequisites met/missing, key concern (~100 tokens)
- Set `current_step` = next selected step or "summary" if no more selected conditional steps remain
- Update `updated_at`
- Display updated stage progression header

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

**After prior_art completes:** Update state.json:
- Set `steps.prior_art.status` = "complete", record `completed_at`
- Write `steps.prior_art.output_summary`: recommendation (adopt/adapt/inform/build), top candidate (~100 tokens)
- Set `current_step` = "summary"
- Update `updated_at`
- Display updated stage progression header

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

**After summary completes (wizard completion):** Update state.json:
- Set `steps.summary.status` = "complete", record `completed_at`
- Write `steps.summary.output_summary`: key outcomes, recommended next action (~100 tokens)
- Set `status` = "complete", `current_step` = null
- Update `updated_at`
- Vault checkpoint: if vault is available (`VAULT_ENABLED=1`), export clarification outcomes to vault
  - On success: append to `vault_checkpoints`: `{ "step": "summary", "exported_at": "<ISO-8601>", "vault_path": "<path>" }`
  - On failure: log warning, continue (fail-open)

---

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
