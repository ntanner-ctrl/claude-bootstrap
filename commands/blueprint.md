---
description: You MUST use this for ANY non-trivial implementation task. Skipping planning leads to confident mistakes that cost more to fix than to prevent.
arguments:
  - name: name
    description: Name for this blueprint (required for new, optional to resume)
    required: false
  - name: challenge
    description: "Challenge mode: vanilla, debate (default), team"
    required: false
  - name: parallel
    description: "Parallelization: sequential, parallel, auto (default)"
    required: false
---

# Blueprint

Guided planning workflow that walks through all stages. Use this for full planning discipline, or when you want the toolkit to guide you through the right steps.

> **Note:** Storage directory is `.claude/plans/` (not `.claude/blueprints/`).
> This is intentional — the directory stores both blueprint artifacts and general
> planning state. See `docs/PLANNING-STORAGE.md` for details.

## Overview

```
Stage 1: Describe    → /describe-change (triage, path, execution_preference)
Stage 2: Specify     → /spec-change (spec + work units + work graph)
Stage 3: Challenge   → Debate chain (default) / Vanilla / Agent team
Stage 4: Edge Cases  → Debate chain (default) / Vanilla / Agent team
Stage 4.5: Pre-Mortem → Operational failure exercise
Stage 5: Review      → /gpt-review (external perspective) [optional]
Stage 6: Test        → /spec-to-tests (spec-blind tests)
Stage 7: Execute     → Implementation (with manifest handoff + work graph)

Cross-cutting:
  - Feedback loops (regression from any stage to any earlier stage, max 3)
  - HALT state with escape hatches (when regressions exhausted + low confidence)
  - Confidence scoring (per-stage, Empirica-backed, advisory + trigger gated)
  - Manifest (token-dense recovery, updated every stage, corruption recovery)
  - Work graph (parallelization, computed in Stage 2, checksum validated)
  - Spec diffs (revision tracking on regression)
  - Debate output schema (JSON validated, vanilla fallback on parse failure)
  - Pre-v2 migration (auto-detect and apply defaults)
```

## Process

### Pre-Stage: Before Starting

If the problem is complex or requirements are unclear, suggest pre-stage commands:

```
Before planning, consider:
  /brainstorm [topic]            — If the problem has multiple viable approaches
  /requirements-discovery [topic] — If requirements are unclear or complex
  /design-check [topic]          — If implementation boundaries are fuzzy

These are optional. Proceed to /blueprint when you have a clear enough picture.
```

### Starting or Resuming

**New blueprint:**
```
/blueprint feature-auth
/blueprint feature-auth --challenge=debate
/blueprint feature-auth --challenge=vanilla
/blueprint feature-auth --challenge=team
```

Creates `.claude/plans/feature-auth/` and starts at Stage 1.

**Name collision handling:** If `.claude/plans/[name]/` already exists:
- If `execute.status === "complete"`: prompt "[1] Create '[name]-2', [2] View existing, [3] Archive and recreate"
- If in-progress: resume from current stage
- Never silently overwrite

**Resume existing:**
```
/blueprint feature-auth
```

If blueprint exists, read `manifest.json` for efficient context recovery (NOT full markdown).
Show current stage and resume.

**List all blueprints:**
```
/blueprints
```

### Bootstrap (First-Ever Blueprint)

If `.claude/plans/` directory doesn't exist, bootstrap:

1. Create `.claude/plans/` directory
2. Create blueprint subdirectory
3. Initialize state.json with defaults
4. Create Empirica session
5. Proceed to Stage 1

Each step is idempotent — check existence before creating.

### Challenge Mode Selection

The challenge mode is selected once at blueprint creation and **locked for the blueprint lifecycle**.
It applies to both Stage 3 (Challenge) and Stage 4 (Edge Cases).

```
/blueprint feature-auth                      # debate mode (DEFAULT)
/blueprint feature-auth --challenge=vanilla  # original single-agent
/blueprint feature-auth --challenge=debate   # sequential debate chain
/blueprint feature-auth --challenge=team     # agent team (experimental)
```

The mode is stored in `state.json` as `"challenge_mode"`. On regression, the same mode is reused.

### Pre-v2 Migration

When resuming a blueprint that lacks `blueprint_version` in state.json:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  MIGRATION │ [name] upgraded to Blueprint v2
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Applied defaults:
    - Challenge mode: vanilla (original behavior)
    - Pre-mortem: skipped (pre-v2 plan)
    - Manifest: generated from existing artifacts
    - Empirica: not connected (optional for migrated plans)

  Your existing artifacts and progress are unchanged.
  The blueprint will continue from its current stage.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Apply defaults: `blueprint_version: 2`, `challenge_mode: "vanilla"`, `execution_preference: "auto"`,
`empirica_session_id: null`, `manifest_stale: false`, `work_graph_stale: false`,
`premortem: { "status": "skipped", "skip_reason": "created before blueprint-v2" }`.

Generate manifest.json from existing artifacts. Set `blueprint_version: 2`.

### Stage Navigation

Present the current stage header:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BLUEPRINT: [name] │ Stage [N] of 7: [Stage Name]
  Mode: [vanilla/debate/team] │ Revision: [N] │ Confidence: [score]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Stages:
  ✓ 1. Describe     [completed timestamp]
  ✓ 2. Specify      [completed timestamp]  (rev [N])
  → 3. Challenge    ← You are here
  ○ 4. Edge Cases
  ○ 4.5 Pre-Mortem  (optional)
  ○ 5. Review       (optional)
  ○ 6. Test
  ○ 7. Execute

Commands:
  'next'     Advance to next stage (requires current stage complete)
  'back'     Return to previous stage
  'skip'     Skip current stage (requires reason)
  'status'   Show progress
  'exit'     Exit wizard (progress saved)
  'reset [stage]'  Jump to earlier stage (triggers regression)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Stage Execution

Each stage invokes its corresponding command or inline logic:

| Stage | Command | Can Skip? | Auto-skipped When |
|-------|---------|-----------|-------------------|
| 1. Describe | `/describe-change` | No | Never |
| 2. Specify | `/spec-change` | Yes | Light path |
| 3. Challenge | See Challenge Modes below | Yes | Light/Standard path |
| 4. Edge Cases | See Challenge Modes below | Yes | Light/Standard path |
| 4.5. Pre-Mortem | Inline (see below) | Yes | Light/Standard path |
| 5. Review | `/gpt-review` | Yes | Always optional |
| 6. Test | `/spec-to-tests` | Yes | Light path |
| 7. Execute | Exit wizard | No | Never |

### Path-Based Stage Selection

After Stage 1 (Describe), the triage result determines the path:

**Light Path:** 1 → 7 (describe → execute)
- Stages 2-6 auto-skipped
- Quick preflight recommended but not required

**Standard Path:** 1 → 2 → 7 (describe → specify → execute)
- Stages 3-6 optional
- Preflight recommended

**Full Path:** 1 → 2 → 3 → 4 → 4.5 → 5 → 6 → 7 (all stages)
- Stage 5 (Review) always optional
- Stage 4.5 (Pre-Mortem) recommended, skippable
- Other stages recommended

---

## EMPIRICA ENFORCEMENT

When this workflow is active, you MUST call Empirica at each stage transition.
This is not optional. The confidence data feeds regression decisions.
The blueprint-stage-gate hook will flag missing Empirica data.

**Before starting Stage 1:**
- Call `session_create` with ai_id "claude-code"
- Call `submit_preflight_assessment` with honest self-assessment
- Store session_id in state.json under `empirica_session_id`
- Store session_id in manifest.json under `empirica_session_id` (dual storage)
- Set `empirica_preflight_complete: true` in state.json

**After completing each stage:**
- Call `finding_log` with a summary of what was learned
- Record confidence score (0.0-1.0) in state.json under `stages.[name].confidence`
- Include `confidence_note` explaining the score
- Update manifest.json

**On regression:**
- Call `mistake_log` if the regression was caused by an error in judgment
- Call `deadend_log` if an approach was tried and failed

**After Stage 7 complete (or workflow abandoned):**
- Call `submit_postflight_assessment`

**Session recovery:** If session_id is missing on resume:
1. Check state.json first, then manifest.json
2. If both missing: create continuation session via `session_create`
3. Log discontinuity: `"empirica_session_note": "Continuation session — original lost"`

---

## MANIFEST ENFORCEMENT

After every stage completion, update `manifest.json`. This is the token-dense recovery
format — see `docs/PLANNING-STORAGE.md` for the full schema.

**On resume:** Read manifest.json (NOT full markdown artifacts) for context recovery.
Only read full artifacts when the current stage's work requires them.

**On write failure:** Set `manifest_stale: true` in state.json, preserve `manifest.json.bak`,
block stage progression until resolved.

**On read failure (corruption):** Attempt regeneration from source artifacts
(describe.md + spec.md + adversarial.md + state.json). If regeneration fails, halt with error.

---

## Challenge Modes

### Vanilla Mode

Identical to the original behavior. A single agent runs `/devils-advocate` (Stage 3)
and `/edge-cases` (Stage 4) sequentially. One perspective per stage.

Output: Findings appended to `adversarial.md` as before.

### Debate Mode (Default)

A three-round sequential critique chain using subagents. Each round's agent sees all
prior rounds' output, creating escalating context.

**Timeout protection:** Each debate subagent has a 5-minute timeout. Each stage (3 rounds)
has a 15-minute total timeout. On timeout: log a dead-end via Empirica, fall back to
vanilla mode for the remainder of that stage, preserve any completed rounds.

**Cascading timeout behavior:** The stage timeout (15 min) is the outer envelope. If Round 1
times out, remaining time for fallback = stage_timeout - elapsed. If remaining < 2 min,
skip stage entirely with `confidence: 0.3` and note "timeout, no adversarial review completed."

**Debate round progress tracking:** Store in state.json:
```json
{
  "debate_progress": {
    "rounds_completed": ["challenger"],
    "current_round": "defender"
  }
}
```
On resume, skip completed rounds and continue from `current_round`.

#### Stage 3 (Challenge) Debate

```
Round 1 — Challenger (subagent, sonnet)
  Sees: spec.md
  Prompt: "You are an adversarial reviewer. Find the weakest assumptions
  in this specification. What would a hostile user exploit? What breaks
  at scale? What breaks under network failure? What's underspecified?
  Produce a numbered list of findings with severity ratings."

Round 2 — Defender (subagent, sonnet)
  Sees: spec.md + Round 1 output
  Prompt: "You are a specification defender. Review these challenges.
  For each finding:
    - VALID: Confirm it's a real risk. Suggest mitigation.
    - OVERSTATED: Explain why the risk is lower than claimed.
    - FALSE: Explain why this isn't actually a problem.
  Then: What did the Challenger MISS? Add any new findings."

Round 3 — Judge (subagent, sonnet)
  Sees: spec.md + Round 1 + Round 2
  Prompt: "You are the final judge. Synthesize the debate into a
  verdict. For each finding, rate:
    - Severity: critical / high / medium / low
    - Convergence: both-agreed / disputed / newly-identified
    - Addressed: already in spec / needs spec update / needs new section
  Produce the final findings list, ordered by severity.

  OUTPUT FORMAT: You MUST produce your verdict as a JSON object with
  this structure:
  {
    \"findings\": [
      {
        \"id\": \"F1\",
        \"finding\": \"description\",
        \"severity\": \"critical|high|medium|low\",
        \"convergence\": \"both-agreed|disputed|newly-identified\",
        \"addressed\": \"already-in-spec|needs-spec-update|needs-new-section\"
      }
    ],
    \"verdict\": \"PASS|PASS_WITH_NOTES|REGRESS\",
    \"critical_count\": 0,
    \"regression_target\": \"specify\"
  }

  Verdict meanings:
    PASS = no critical findings, proceed
    PASS_WITH_NOTES = non-critical findings only, proceed normally, append to adversarial.md
    REGRESS = has critical findings that need spec changes"
```

#### Stage 4 (Edge Cases) Debate

```
Round 1 — Boundary Explorer (subagent, sonnet)
  Sees: spec.md + adversarial.md (from Stage 3)
  Prompt: "Map every boundary in this specification: input boundaries
  (empty, single, limit, over-limit, malformed), state boundaries
  (transitions, cold starts, restarts), concurrency boundaries
  (simultaneous, interrupted, stale), time boundaries (zones, skew,
  DST, leap). List each boundary with its expected behavior."

Round 2 — Stress Tester (subagent, sonnet)
  Sees: spec.md + adversarial.md + Round 1
  Prompt: "For each boundary identified, describe what happens at:
  the value just below, at, just above, and far beyond the boundary.
  Which of these are handled in the spec? Which are unspecified?
  Which would cause data loss, security issues, or silent corruption?"

Round 3 — Synthesizer (subagent, sonnet)
  Sees: spec.md + adversarial.md + Round 1 + Round 2
  Prompt: "Produce the final edge case report. For each edge case:
    - Impact: critical / high / medium / low
    - Likelihood: common / uncommon / rare / theoretical
    - Priority: impact x likelihood ranking
    - Addressed: yes (cite spec section) / no (needs spec update)
  Order by priority. Flag any edge case that implies an architectural
  change (potential regression trigger).

  OUTPUT FORMAT: You MUST produce your findings as a JSON object
  following the debate output schema (see PLANNING-STORAGE.md)."
```

#### Debate Output Processing

The Judge/Synthesizer output is processed as follows:

1. **Parse JSON:** Extract the structured findings from the output
2. **Schema validation:** Verify required fields (id, finding, severity, convergence, addressed)
3. **If valid:** Use structured data for regression trigger evaluation
4. **If invalid (parse failure):** Fall back to vanilla mode processing:
   - Extract numbered list items via pattern matching (`F[0-9]+`, `[0-9]+.`, `-`)
   - Assign all findings: severity=medium, convergence=newly-identified
   - If no list items found, wrap entire output as single finding
   - Log warning via Empirica `deadend_log`
   - Flag all extracted findings for human review

The curated output goes to `adversarial.md` (canonical source of truth).
Raw debate transcript preserved in `debate-log.md` (debug artifact only).

### Team Mode (Opt-in, Experimental)

Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. If not set and user requests `--challenge=team`:

```
Agent team challenge mode requires the experimental agent teams flag.

To enable, add to your settings.json:
  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }

Falling back to debate mode (sequential challenge chain).
```

When available, spawns an agent team with three teammates:

```
Teammates:
  Red Team    — Attack vectors, security assumptions, trust boundaries
  Skeptic     — Complexity, YAGNI, hidden coupling, maintainability
  Pragmatist  — Operational reality, deployment risks, monitoring gaps
```

The teammates receive the spec and are instructed to:
1. Independently review and produce findings (Round 1)
2. Read each other's findings and respond — agree, disagree, or build on (Round 2)
3. Converge on a consensus findings list (Round 3)

The lead synthesizes the final output.

Output: Same format as debate mode — curated findings to `adversarial.md`, full transcript to `debate-log.md`.

---

## Pre-Mortem (Stage 4.5)

### Scope

Pre-mortem focuses on **OPERATIONAL failures** — things that go wrong during deployment,
monitoring, rollback, and ongoing operations. This is explicitly distinct from Challenge
(Stage 3) and Edge Cases (Stage 4), which focus on **DESIGN failures**.

| Stage | Focus | Example Finding |
|-------|-------|-----------------|
| Challenge (3) | Design: "What's wrong with the architecture?" | "JWT secret rotation not handled" |
| Edge Cases (4) | Design: "What breaks at boundaries?" | "Empty token string passes validation" |
| Pre-Mortem (4.5) | Operational: "What goes wrong when deployed?" | "No monitoring for token refresh failure rate" |

### Process

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BLUEPRINT: [name] │ Stage 4.5: Pre-Mortem
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Premise: This plan was implemented and deployed two weeks ago.
  It failed. You're writing the post-mortem.

  Focus: OPERATIONAL failures only (deployment, monitoring,
  rollback, oncall, observability). Design failures were already
  caught in Stages 3-4.

  Questions:
  1. What was the most likely single cause of failure?
  2. What contributing factors made it worse?
  3. What early warning signs were missed during planning?
  4. What would the incident retrospective recommend changing?

  For each identified failure:
    COVERED  → Already addressed in spec or adversarial findings (cite)
    NEW      → Not previously identified (potential regression trigger)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Output

Written to `.claude/plans/[name]/premortem.md`. Any NEW findings also appended to
`adversarial.md` with the tag `[pre-mortem]`.

If any NEW finding is rated critical, a regression prompt fires (see Feedback Loops below).

### Overlap Detection

For each pre-mortem finding, check adversarial.md for same failure category + same
affected component:
- If match found → mark as COVERED
- If (COVERED count / total findings) > 0.8 → note `"premortem_overlap": "high"` in state.json
- On future blueprints with similar scope, suggest skipping pre-mortem

### Skippability

Skippable (with reason logged) on all paths. Recommended on Full path, suggested on
Standard path, not shown on Light path.

---

## Stage 5: External Review

### Overview

Stage 5 (Review) provides an external perspective on the specification and adversarial findings. It is always optional on all paths.

### Plugin Integration

Before presenting Stage 5 options, check for plugin enhancements:

1. **Read plugin registry:** Read `commands/plugin-enhancers.md`. If file not found, skip to standard options.
2. **Follow detection protocol:** Use Section 1 of plugin-enhancers.md to check installed plugins.
3. **Build dynamic options:** Construct the options list based on detected plugins.

### Stage 5 Options Presentation

Present options in this order:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BLUEPRINT: [name] │ Stage 5 of 7: External Review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  External review options:

    [1] GPT Surgical Review (/gpt-review)
        Claude diagnoses → GPT implements fixes → Claude reviews PR

  [If pr-review-toolkit detected:]
    [2] Deep Dive — pr-review-toolkit agents (recommended)
        6 specialized lenses: silent failures, type design,
        test coverage, comments, simplification, conventions

  [If frontend detected:]
    [3] Multi-Model Consensus — frontend:reviewer
        Parallel assessment from multiple AI models

  [If security-pro detected:]
    [4] Security Audit — security-pro:security-auditor
        Deep vulnerability assessment, OWASP compliance, auth gaps

  [If performance-optimizer detected:]
    [5] Performance Audit — performance-optimizer:performance-engineer
        Bottleneck identification, caching, query optimization

  [If superpowers OR feature-dev detected:]
    [6] Code Quality Review — additional reviewers
        [superpowers: methodology-based] [feature-dev: convention-based]

    [N] Skip — local challenge stages were sufficient

>
```

**Dynamic numbering rules:**
- GPT review is always option [1]
- Plugin options are numbered sequentially after GPT review, in the order above
- Skip is always the last option (numbered N, where N = total options)
- Options only appear when their required plugin is detected
- Multiple options can be selected (comma-separated, e.g., "2,4")

**If no plugins detected:** Show only options [1] GPT review and [2] Skip.

### Deep Dive Option (pr-review-toolkit)

When user selects the Deep Dive option:

**Step 1: Fast-fail probe**
```
Probing pr-review-toolkit availability...
```

Dispatch `pr-review-toolkit:code-reviewer` with 10-second timeout.
- If probe succeeds: proceed to Step 2
- If probe fails:
  ```
  [PLUGIN] pr-review-toolkit probe failed; skipping all agents
  Note: pr-review-toolkit unavailable (probe failed). Falling back to GPT review.
  ```
  Automatically execute GPT review option instead.

**Step 2: Full agent dispatch**
```
Dispatching 6 specialized review agents...
```

Dispatch all 6 agents in parallel:
1. `pr-review-toolkit:silent-failure-hunter`
2. `pr-review-toolkit:type-design-analyzer`
3. `pr-review-toolkit:pr-test-analyzer`
4. `pr-review-toolkit:comment-analyzer`
5. `pr-review-toolkit:code-simplifier`
6. `pr-review-toolkit:code-reviewer`

Each agent receives:
- Context: Spec from `spec.md`
- Files: All implementation files from work units (if Stage 7 started) OR spec sections (if pre-implementation)
- Timeout: 5 minutes per agent

**Step 3: Collect results**

For each agent:
- Success: format per Section 5 of plugin-enhancers.md
- Failure: log and skip (see graceful degradation below)
- Timeout: kill agent, log, skip

**Step 4: Present findings**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Deep Dive Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Consolidated findings from all agents, formatted per Section 5]

These findings are advisory. They have been appended to
adversarial.md under "## Plugin Review Findings" with
[plugin-review] tags.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Append all findings to `.claude/plans/[name]/adversarial.md`:
```markdown
## Plugin Review Findings

[All plugin results with [plugin-review] tags]
```

**Step 5: Mark stage complete**

Set `stages.review.status = "complete"` in state.json with confidence 0.8 (plugin reviews are advisory but thorough).

### Multi-Model Option (frontend)

When user selects the Multi-Model option:

**Step 1: Dispatch**
```
Dispatching frontend:reviewer for multi-model assessment...
```

Dispatch `frontend:reviewer` with:
- Context: Spec from spec.md + adversarial findings
- Files: Implementation files (if available)
- Timeout: 5 minutes

**Step 2: Present findings**

Format per Section 5 of plugin-enhancers.md, append to adversarial.md with `[plugin-review]` tag.

**Step 3: Mark stage complete**

Set `stages.review.status = "complete"` with confidence 0.8.

### GPT Review Option (Existing Behavior)

When user selects GPT review (option [1]):

Execute `/gpt-review` as documented in that command. This is the existing cross-platform adversarial review.

### Skip Option

When user selects Skip:
```
You're about to skip Stage 5: External Review

This stage normally provides:
  - External perspective from different model families
  - Fresh eyes on assumptions made during planning
  - Specialized review lenses not available in earlier stages

Are you sure? Provide a reason for the skip:
> [user reason]

Skip recorded. Proceeding to Stage 6 (Test).
```

Set `stages.review.status = "skipped"` and `stages.review.skip_reason = "[user reason]"` in state.json.

### Graceful Degradation

Follow all rules from Section 4 of plugin-enhancers.md:

**Agent dispatch failure:**
1. Log: `[PLUGIN] pr-review-toolkit:<agent> dispatch failed: <error>`
2. User message: `Note: <agent> unavailable (dispatch failed), skipping.`
3. Continue with remaining agents

**Agent timeout (5 minutes):**
1. Log: `[PLUGIN] pr-review-toolkit:<agent> timeout: 5m exceeded`
2. User message: `Note: <agent> unavailable (timeout after 5min), skipping.`
3. Kill agent, continue with remaining agents

**Oversized output (>2000 tokens):**
1. Truncate to 2000 tokens
2. Append: `[truncated — full output available via direct plugin invocation]`

**Circuit breaker (3 consecutive failures):**
1. Log: `[PLUGIN] Circuit breaker: 3 consecutive failures from pr-review-toolkit; skipping remaining agents`
2. User message: `Plugin enhancements temporarily disabled due to repeated failures.`
3. Abort remaining agents for that plugin
4. Fallback: offer GPT review as alternative

### Results Handling

**Plugin findings are advisory:**
- Appended to `adversarial.md` with `[plugin-review]` tags
- Do NOT trigger regression logic
- Do NOT affect confidence scoring
- Do NOT block workflow progression
- User may act on them or ignore them

This is explicitly distinct from debate chain findings (Stage 3/4), which CAN trigger regressions.

### Logging

Use `[PLUGIN]` prefix for all plugin-related operations:
```
[PLUGIN] Detection: found pr-review-toolkit@claude-code-plugins
[PLUGIN] pr-review-toolkit:code-reviewer dispatched
[PLUGIN] pr-review-toolkit:code-reviewer completed: 1247 tokens
[PLUGIN] pr-review-toolkit:silent-failure-hunter timeout: 5m exceeded
```

If Empirica session is active:
- Log successful plugin insights via `finding_log`
- Log failures via `deadend_log`

---

## Feedback Loops (Stage Regression)

### Regression Triggers

Two types: automatic (system-suggested) and manual (user-initiated).

**Automatic triggers** — the system prompts the user, who decides:

| Condition | Suggested Target | When |
|-----------|-----------------|------|
| Debate judge rates finding as critical + "needs spec update" | Stage 2 (Specify) | After Stage 3 |
| Edge case synthesizer flags "implies architectural change" | Stage 2 (Specify) | After Stage 4 |
| Pre-mortem identifies NEW critical failure mode | Stage 2 (Specify) | After Stage 4.5 |
| Confidence <0.5 AND a trigger event occurs | Previous stage | After any stage |
| 2+ agents in debate converge on same critical finding | Stage 2 (Specify) | After Stage 3 |

**Confidence-gated regression:** Confidence alone does NOT trigger regression. It requires
BOTH low confidence (<0.5) AND a specific trigger event (critical finding, schema validation
failure, etc.) to suggest regression.

**Manual triggers:**

```
back              ← Go to previous stage (exists today)
reset specify     ← Jump to Stage 2 with reason prompt
reset describe    ← Jump to Stage 1 (full restart)
reset [stage]     ← Jump to any earlier stage
```

### Regression Prompt

When an automatic trigger fires:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REGRESSION SUGGESTED │ Stage [current] → Stage [target]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Trigger: [description of what caused the suggestion]

  Impact: [what part of the spec/plan is affected]

  Options:
    [1] Regress to [target stage] — rework affected sections
        (All later-stage findings are preserved and carried forward)
    [2] Note and continue — append finding to adversarial.md
    [3] Flag as blocking — halt workflow until manually resolved

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Option [3] behavior:** Set `status: "blocked_pending_resolution"` in state.json.
Store `blocking_finding: "F[id]"` in state.json. Append finding with `[BLOCKING]`
tag to adversarial.md. Workflow refuses to advance until user runs `/blueprint [name]`
and resolves. Resolution note appended to adversarial.md with timestamp.

### Regression Behavior

When a regression occurs:

1. **state.json updated** — `current_stage` set to target, target stage status set to
   `"in_progress"`, all stages between target+1 and current marked `"needs_revalidation"`.

2. **regression_log appended:**
```json
{
  "from_stage": "edge_cases",
  "to_stage": "specify",
  "trigger_type": "automatic",
  "trigger": "edge_case_architectural_impact",
  "reason": "JWT expiry mid-request requires new error handling strategy",
  "timestamp": "2026-02-07T15:00:00Z",
  "revision": 2
}
```

3. **Artifact preservation** — ALL existing artifacts are kept. The spec gets a revision
   header. Copy `spec.md` to `spec.md.revision-N.bak` before allowing re-entry to Stage 2.

4. **Preserved resolutions** — Ambiguities resolved in prior stages are listed in the
   regression context, preventing them from being re-introduced.

5. **spec.diff.md updated** — Revision log tracking all changes (see Spec Diff Tracking below).

6. **Work graph marked stale** — When regressing to Stage 2, set `"work_graph_stale": true`
   in state.json. Stage 2 completion MUST regenerate work-graph.json.

7. **Post-regression stages** — When re-running stages after regression, the agent is given
   the previous stage output plus the regression context. It updates, not restarts from scratch.

8. **Challenge mode preserved** — On regression, use the same `challenge_mode` from state.json.
   Do not re-prompt for mode selection.

### HALT State (Max Regression Recovery)

**Maximum regressions per blueprint: 3.**

If confidence is >=0.5 on all completed stages: proceed normally (regressions exhausted
but quality is acceptable). Skipped stages are excluded from threshold evaluation.

If confidence is <0.5 on any completed stage AND the regression limit is reached:
the blueprint enters **HALT**.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BLUEPRINT HALTED │ [name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  This blueprint has exhausted its regression budget (3/3)
  but confidence remains below threshold on: [stage(s)]

  Regression history:
    [1] [from] → [to]: [reason]
    [2] [from] → [to]: [reason]
    [3] [from] → [to]: [reason]

  Options:
    [1] Override confidence threshold — proceed despite low confidence
        (Logged as override in state.json and overrides.json)
    [2] Simplify scope and restart — reduce scope, create new blueprint
        (Current blueprint archived as [name]-abandoned-[date])
    [3] Abandon blueprint — stop planning, decide manually
        (Artifacts preserved for reference)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Spec Diff Tracking

### When Created

`spec.diff.md` is created on the first regression and appended on subsequent ones.

### Format

```markdown
# Specification Revision History

## Revision 1 (initial)
- Created: [timestamp]
- Sections: [list of top-level sections]
- Work Units: [count]

## Revision 1 → Revision 2
- Trigger: [what caused the regression]
- Date: [timestamp]
- Sections added: [list]
- Sections modified: [list with change summaries]
- Sections removed: [list or None]
- Sections unchanged: [list]
- Adversarial findings addressed: [N/total]
- Work units affected: [list with changes]
```

### Maintenance

When a regression occurs:
1. Read current spec.md
2. After user modifies spec (re-running Stage 2), diff against previous version
3. Append diff summary to spec.diff.md
4. Increment `revision` in state.json and manifest.json
5. Update manifest's `spec_digest`

---

## During Any Stage

At any point during planning:

- **Non-obvious choice made?** → Run `/decision [topic]` to record rationale
- **Session getting long?** → Run `/checkpoint` to save context
- **Requirements unclear?** → Run `/requirements-discovery` to validate

These are invoked inline — they don't interrupt stage progression.

---

## Skip Handling

When user requests skip:

```
You're about to skip Stage [N]: [name]

This stage normally catches:
  - [what this stage finds]

Are you sure? Provide a reason for the skip:
> [user reason]

Skip recorded. Proceeding to Stage [N+1].
```

Skips are logged in `state.json` and visible in `/overrides`.

---

## Completion

When Stage 7 (Execute) is reached:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BLUEPRINT: [name] │ Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Planning complete! Summary:

  Path: [Light/Standard/Full]
  Mode: [vanilla/debate/team]
  Stages completed: [N]/7 (+ skipped: [list])
  Revisions: [N] (regressions: [N])
  Confidence: [min - max across stages]

  Artifacts:
  - .claude/plans/[name]/describe.md
  - .claude/plans/[name]/spec.md
  - .claude/plans/[name]/adversarial.md
  - .claude/plans/[name]/manifest.json
  - .claude/plans/[name]/work-graph.json
  [+ any additional artifacts]

Ready to implement. Artifacts saved for reference.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Vault Export (Automatic)

After presenting the completion summary, export blueprint to vault if available:

1. Source vault config:
   ```bash
   source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo "VAULT_ENABLED=$VAULT_ENABLED" && echo "VAULT_PATH=$VAULT_PATH"
   ```

2. If vault is available (`VAULT_ENABLED=1` and path exists and writable):
   a. Ensure target directory: `mkdir -p "$VAULT_PATH/Engineering/Blueprints"`
   b. Read `manifest.json` for the completed blueprint
   c. Read `adversarial.md` for top findings (if exists)
   d. Determine project name: `basename $(git rev-parse --show-toplevel 2>/dev/null || echo "unknown")`
   e. Generate slug from blueprint name (include project): `YYYY-MM-DD-project-blueprint-name.md`
   f. Hydrate `blueprint-summary.md` template with `schema_version: 1` in frontmatter
   g. **Merge-write [F2]**: If file exists, read it, split at `<!-- user-content -->` sentinel, preserve content below sentinel, overwrite above
   h. Write to `$VAULT_PATH/Engineering/Blueprints/YYYY-MM-DD-project-blueprint-name.md`
   i. Report: `Vault: Blueprint summary exported to Engineering/Blueprints/`

3. If vault is enabled but not accessible: `"Vault write skipped: directory not accessible"`
4. If vault is not enabled: silently skip (no message)

```
  Pre-implementation:
    /design-check [name]    — Verify prerequisites are met (recommended)
    /preflight              — Safety check for risky operations

  Implementation options:
    [1] Standard implementation (sequential)
    [2] TDD-enforced → /tdd --plan-context [name]
    [3] Parallel dispatch → /delegate --plan .claude/plans/[name]/spec.md --review
        [parallelization recommendation based on work graph + execution_preference]

  Post-implementation:
    /quality-gate           — Score against rubric before completing

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Parallelization recommendation** (based on work graph analysis + execution_preference):

| Width | Critical Path | Preference | Suggestion |
|-------|--------------|------------|------------|
| Any | Any | `speed` | `strong` — always suggest `/delegate` |
| Any | Any | `simplicity` | `none` — always suggest sequential |
| 1 | Any | `auto` | `none` — sequential |
| 2 | <=3 | `auto` | `moderate` — suggest `/delegate` |
| 3+ | Any | `auto` | `strong` — recommend `/delegate --review` |
| Any | >5 | `auto` | `strong` — recommend `/delegate --review` |

The execution_preference is advisory — user always has final choice.

---

## State Persistence

On any action, update `.claude/plans/[name]/state.json`.
See `docs/PLANNING-STORAGE.md` for the full v2 schema.

---

## Output Artifacts

All artifacts saved to `.claude/plans/[name]/`:
- `state.json` — Progress tracking + v2 metadata
- `manifest.json` — Token-dense recovery format
- `describe.md` — Triage output
- `spec.md` — Full specification
- `adversarial.md` — Challenge + edge case findings (canonical source of truth)
- `premortem.md` — Pre-mortem analysis (operational focus)
- `debate-log.md` — Raw debate transcript (debug, debate/team mode only)
- `work-graph.json` — Parallelization dependency graph
- `spec.diff.md` — Revision history (created on first regression)
- `preflight.md` — Pre-flight checklist
- `tests.md` — Generated test specs

## Integration

- **Wraps:** All planning commands
- **Tracked in:** `.claude/plans/[name]/`
- **Listed by:** `/blueprints`
- **Status checked by:** `/status`
- **Recovery format:** `manifest.json` (read at all recovery points)
- **Work decomposition:** `work-graph.json` (consumed by `/delegate`)
- **Enforcement:** `hooks/blueprint-stage-gate.sh` (checks Empirica data)
