# Blueprint v2: Planning Workflow Enhancement

> **Revision 2** — Integrates findings from debate chain (3 critical, 5 high, 7 medium, 5 low).
> See `adversarial.md` for the canonical findings list.
> See `spec.diff.md` for revision-over-revision changes.

## Summary

Major enhancement to the claude-bootstrap planning workflow. Renames `/plan` to `/blueprint` and `/plans` to `/blueprints`. Introduces three challenge modes (vanilla, debate, team), feedback loops with stage regression and HALT recovery, token-dense manifest storage with corruption recovery, parallelization-aware work graphs with checksum validation, pre-mortem analysis focused on operational failures, confidence scoring with Empirica integration enforced via hook, and spec diff tracking.

The guiding principle: the 7-phase planning workflow has proven its value. These enhancements make it more rigorous, more recoverable across sessions, and better at catching problems early — even if they cost more tokens upfront.

---

## What Changes

### Commands (rename + new behavior)

| File | Action | Notes |
|------|--------|-------|
| `commands/plan.md` | Rename to `commands/blueprint.md` | Core command, major rewrite |
| `commands/plans.md` | Rename to `commands/blueprints.md` | Listing command, minor updates |
| All 37+ files referencing `/plan` or `/plans` | Update references | Mechanical rename with validation script |
| `hooks/session-bootstrap.sh` | Update command categorization | `/blueprint` in planning category |
| `hooks/state-index-update.sh` | Update references | Track `active_blueprint` instead of `active_plan` |

### Storage

| Path | Action | Notes |
|------|--------|-------|
| `.claude/plans/` | **Keep as-is** | Directory name unchanged for backward compat. Document the naming gap. |
| `.claude/plans/*/manifest.json` | **New file** | Token-dense summary of all artifacts |
| `.claude/plans/*/work-graph.json` | **New file** | Parallelization dependency graph with checksum |
| `.claude/plans/*/spec.diff.md` | **New file** | Revision history when regressions occur |
| `.claude/plans/*/premortem.md` | **New file** | Pre-mortem analysis output (operational focus) |
| `.claude/plans/*/debate-log.md` | **New file** | Raw debate transcript (debug artifact) |
| `.claude/state-index.json` | Update field names | `active_blueprint`, `active_blueprint_stage` |

### Hooks

| Hook | Action | Notes |
|------|--------|-------|
| `hooks/state-index-update.sh` | Modify | New field names, manifest write trigger |
| **`hooks/blueprint-stage-gate.sh`** | **New** | Checks Empirica session_id in state.json before stage transitions [C2] |

### Agents

No new agents required. The debate chain uses subagents with role-specific prompts. The team mode uses native agent teams.

### Scripts

| Script | Action | Notes |
|--------|--------|-------|
| **`scripts/validate-rename.sh`** | **New** | Greps for stale `/plan\b` and `/plans\b` command references [C3] |

### Documentation

| File | Action |
|------|--------|
| `README.md` | Update all `/plan` → `/blueprint` references, document `.claude/plans/` naming, add FAQ [M6] |
| `commands/README.md` | Full reference update |
| `docs/PLANNING-STORAGE.md` | Add manifest.json, work-graph.json, premortem.md schemas |
| `docs/BLUEPRINT-MODES.md` | **New**: Explanation doc covering vanilla/debate/team modes |

---

## Preservation Contract

These things MUST NOT change:

- The `.claude/plans/` directory path (backward compatibility)
- The `state.json` schema (extend only, no breaking changes)
- The human-readable markdown artifacts (describe.md, spec.md, adversarial.md, tests.md)
- The Light/Standard/Full path triage system
- The ability to skip stages with a reason
- The `/describe-change` triage gateway (still Stage 1, still determines path)
- All existing review lens behavior (`--lenses security,perf,arch,cfn`)
- The `/dispatch` and `/delegate` command interfaces (they consume plan artifacts, not the other way around)

---

## Detailed Design

### 1. Command Rename

#### 1.1 `/blueprint` (was `/plan`)

The command file is renamed from `commands/plan.md` to `commands/blueprint.md`. All internal references update. The command description becomes:

```yaml
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
```

#### 1.2 `/blueprints` (was `/plans`)

Renamed from `commands/plans.md` to `commands/blueprints.md`. Output format updates cosmetically:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                     ACTIVE BLUEPRINTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [name]          Stage [N]/7 ([stage name])   Last: [time ago]
  ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Commands:
  Resume:     /blueprint [name]
  Start new:  /blueprint [new-name] or /describe-change
  View:       /status [name]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### 1.3 Storage Path Documentation

The `.claude/plans/` directory is kept for backward compatibility. All documentation that references it must include a note:

```
Note: The storage directory is `.claude/plans/` (not `.claude/blueprints/`).
This is intentional — the directory stores both blueprint artifacts and
general planning state. The `/blueprint` command name reflects the
structured design methodology; the storage path reflects the content type.
```

**FAQ entry for README [M6]:**

> **Q: Why is the command `/blueprint` but files are in `.claude/plans/`?**
> A: The command was renamed from `/plan` to `/blueprint` to avoid collision with Claude Code's native plan mode. The storage directory was intentionally kept as `.claude/plans/` for backward compatibility — it stores general planning state, not just blueprints. Think of it as: the command describes the *methodology*, the directory describes the *content*.

#### 1.4 Cross-Reference Update Scope

Every file that references `/plan` as a command invocation or `/plans` as a command invocation must be updated. References to `.claude/plans/` as a storage path are NOT changed. References to "plan" as a generic English noun (e.g., "execution plan", "plan context") are NOT changed.

Pattern: `/plan ` or `/plan\b` as a command → `/blueprint`. `/plans` as a command → `/blueprints`. `--plan` flags on `/dispatch` and `/delegate` are NOT changed (they refer to a spec file path, not the command).

#### 1.5 Rename Validation [C3]

A validation script `scripts/validate-rename.sh` MUST be created and run after W2 (cross-reference update). The script:

```bash
#!/usr/bin/env bash
# Greps for stale /plan and /plans command references
# Excludes: .claude/plans/ paths, --plan flags, English noun usage
# Exit 1 if any stale references found

VIOLATIONS=$(grep -rn '/plan\b' commands/ hooks/ docs/ README.md templates/ \
  | grep -v '.claude/plans/' \
  | grep -v '\-\-plan' \
  | grep -v 'plan context' \
  | grep -v 'execution plan' \
  | grep -v 'plan-context' \
  | grep -v 'planName' \
  | grep -v '/blueprint')

if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: Found stale /plan command references:"
  echo "$VIOLATIONS"
  exit 1
fi

echo "PASS: No stale command references found."
exit 0
```

**W2 acceptance criteria:** `scripts/validate-rename.sh` exits with code 0 (zero command reference violations).

---

### 2. Challenge Modes

The challenge phase (Stages 3-4) gains three operating modes. The mode is selected once at blueprint creation and applies to both Stage 3 (Challenge) and Stage 4 (Edge Cases).

#### 2.1 Mode Selection

```
/blueprint feature-auth                      # debate mode (DEFAULT)
/blueprint feature-auth --challenge=vanilla  # original single-agent
/blueprint feature-auth --challenge=debate   # sequential debate chain
/blueprint feature-auth --challenge=team     # agent team (experimental)
```

The mode is recorded in `state.json`:

```json
{
  "challenge_mode": "debate",
  ...
}
```

#### 2.2 Vanilla Mode

Identical to the current behavior. A single agent runs `/devils-advocate` (Stage 3) and `/edge-cases` (Stage 4) sequentially. One perspective per stage.

Output: Findings appended to `adversarial.md` as today.

#### 2.3 Debate Mode (Default)

A three-round sequential critique chain using subagents. Each round's agent sees all prior rounds' output, creating escalating context.

**Timeout protection [M5]:** Each debate subagent has a 5-minute timeout. Each stage (3 rounds) has a 15-minute total timeout. On timeout: log a dead-end via Empirica, fall back to vanilla mode for the remainder of that stage, and preserve any completed rounds.

**Stage 3 (Challenge) debate:**

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

  OUTPUT FORMAT: You MUST produce your verdict in the following JSON
  structure (in addition to any markdown narrative):
  [See Section 2.5 for required schema]"
```

**Stage 4 (Edge Cases) debate:**

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

  OUTPUT FORMAT: You MUST produce your findings in the following JSON
  structure (in addition to any markdown narrative):
  [See Section 2.5 for required schema]"
```

**Output format:** The Judge/Synthesizer output replaces the content that would go into `adversarial.md`. The raw debate transcript is preserved in a `debate-log.md` file for reference but is NOT the primary artifact. `adversarial.md` is the **canonical source of truth** for all findings [L4].

**Cost:** ~3 subagent calls per stage, 6 total for Stages 3+4. At sonnet pricing this is moderate. The Judge/Synthesizer filtering means the human only reads the curated output, not the full debate.

#### 2.4 Team Mode (Opt-in, Experimental)

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

**Quality gate hooks:**
- `TeammateIdle`: Before a teammate goes idle, verify they've read and responded to at least one other teammate's findings.
- `TaskCompleted`: Before marking the challenge task complete, verify the consensus list exists and has severity ratings.

**Output:** Same format as debate mode — curated findings go to `adversarial.md`, full transcript to `debate-log.md`.

#### 2.5 Debate Output Schema [H2]

All debate Judge/Synthesizer rounds MUST produce a structured JSON output in addition to their markdown narrative. This enables automatic regression trigger parsing.

**Required schema for Challenge (Stage 3) Judge output:**

```json
{
  "type": "object",
  "required": ["findings", "verdict"],
  "properties": {
    "findings": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "finding", "severity", "convergence", "addressed"],
        "properties": {
          "id": { "type": "string", "pattern": "^F[0-9]+$" },
          "finding": { "type": "string" },
          "severity": { "type": "string", "enum": ["critical", "high", "medium", "low"] },
          "convergence": { "type": "string", "enum": ["both-agreed", "disputed", "newly-identified"] },
          "addressed": { "type": "string", "enum": ["already-in-spec", "needs-spec-update", "needs-new-section"] }
        }
      }
    },
    "verdict": {
      "type": "string",
      "enum": ["PASS", "PASS_WITH_NOTES", "REGRESS"],
      "description": "PASS: no critical findings. PASS_WITH_NOTES: non-critical findings only. REGRESS: has critical findings that need spec changes."
    },
    "critical_count": { "type": "integer" },
    "regression_target": {
      "type": "string",
      "description": "Stage to regress to (if verdict is REGRESS)"
    }
  }
}
```

**Fallback on validation failure [H2]:** If the Judge/Synthesizer output cannot be parsed as valid JSON matching this schema, fall back to vanilla mode output processing: treat the entire markdown output as findings, assign all findings `medium` severity, and log a warning. Do NOT silently skip the stage.

---

### 3. Pre-Mortem (Stage 4.5)

A new stage inserted between Edge Cases (4) and Review (5). The stage numbering becomes conceptual — internally stages are still tracked by name, not number, so no schema break.

#### 3.1 Position in Workflow

```
Stage 1: Describe
Stage 2: Specify
Stage 3: Challenge    (debate/vanilla/team)
Stage 4: Edge Cases   (debate/vanilla/team)
Stage 4.5: Pre-Mortem (new)
Stage 5: Review       (optional, external)
Stage 6: Test
Stage 7: Execute
```

#### 3.2 Scope Differentiation [M2]

Pre-mortem focuses on **OPERATIONAL failures** — things that go wrong during deployment, monitoring, rollback, and ongoing operations. This is explicitly distinct from Challenge (Stage 3) and Edge Cases (Stage 4), which focus on **DESIGN failures** — architectural gaps, boundary conditions, and specification ambiguity.

| Stage | Focus | Example Finding |
|-------|-------|-----------------|
| Challenge (3) | Design: "What's wrong with the architecture?" | "JWT secret rotation not handled" |
| Edge Cases (4) | Design: "What breaks at boundaries?" | "Empty token string passes validation" |
| Pre-Mortem (4.5) | Operational: "What goes wrong when deployed?" | "No monitoring for token refresh failure rate" |

If pre-mortem findings overlap >80% with prior stages, note this in state.json. On future blueprints with similar scope, suggest skipping pre-mortem with a reason like "prior experience shows low unique value for this type of change."

#### 3.3 Process

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

#### 3.4 Output

Written to `.claude/plans/[name]/premortem.md`. Any NEW findings are also appended to `adversarial.md` with the tag `[pre-mortem]`.

If any NEW finding is rated critical, a regression prompt fires (see Section 4).

#### 3.5 Skippability

Pre-mortem is skippable (with reason logged) on all paths. It is recommended on Full path, suggested on Standard path, and not shown on Light path.

#### 3.6 state.json Schema Addition

```json
{
  "stages": {
    "premortem": {
      "status": "pending",
      "skippable": true
    }
  }
}
```

The `premortem` key is added to the stages object. Existing state.json files without it are treated as if `premortem` has status `"skipped"` with reason `"created before blueprint-v2"`.

---

### 4. Feedback Loops (Stage Regression)

#### 4.1 Regression Triggers

Two types: automatic (system-suggested) and manual (user-initiated).

**Automatic triggers** — the system prompts the user, who decides:

| Condition | Suggested Target | When |
|-----------|-----------------|------|
| Debate judge rates a finding as critical + "needs spec update" | Stage 2 (Specify) | After Stage 3 |
| Edge case synthesizer flags "implies architectural change" | Stage 2 (Specify) | After Stage 4 |
| Pre-mortem identifies NEW critical failure mode | Stage 2 (Specify) | After Stage 4.5 |
| Confidence score drops below 0.5 AND a trigger event occurs [L3] | Previous stage | After any stage |
| 2+ agents in debate converge on same critical finding | Stage 2 (Specify) | After Stage 3 |

**Confidence-gated regression [L3]:** Confidence alone does NOT trigger regression. It requires BOTH low confidence (<0.5) AND a specific trigger event (critical finding, schema validation failure, etc.) to suggest regression. This prevents false regression triggers from inaccurate self-assessment.

**Manual triggers** — user commands during any stage:

```
back              ← Go to previous stage (exists today)
reset specify     ← Jump to Stage 2 with reason prompt
reset describe    ← Jump to Stage 1 (full restart)
reset [stage]     ← Jump to any earlier stage
```

#### 4.2 Regression Prompt

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

#### 4.3 Regression Behavior

When a regression occurs:

1. **state.json updated** — `current_stage` set to target, target stage status set to `"in_progress"`, all stages between target+1 and current marked `"needs_revalidation"`.

2. **regression_log appended:**

```json
{
  "regression_log": [
    {
      "from_stage": "edge_cases",
      "to_stage": "specify",
      "trigger_type": "automatic",
      "trigger": "edge_case_architectural_impact",
      "reason": "JWT expiry mid-request requires new error handling strategy",
      "timestamp": "2026-02-07T15:00:00Z",
      "revision": 2
    }
  ]
}
```

3. **Artifact preservation** — ALL existing artifacts are kept. The spec gets a revision header:

```markdown
---
## Revision 2 (regressed from Edge Cases)

### Trigger
Edge case: JWT expiry during multi-step transaction

### Changes from Revision 1
- Added: Transaction rollback strategy (Section 3.2)
- Modified: Error handling approach (Section 4.1)

### Carried Forward Findings
- [Summary of adversarial/edge case findings that still apply]
- [Findings that are invalidated by this revision marked as such]

### Preserved Resolutions [L1]
- [Ambiguities that were already resolved in prior stages — not to be re-introduced]
---
```

4. **spec.diff.md updated** — A diff log tracking all revisions (see Section 8).

5. **Work graph marked stale [H3]** — When regressing to Stage 2, set `"work_graph_stale": true` in state.json. Stage 2 completion MUST regenerate work-graph.json. A stale work graph blocks Stage 7 progression — `/delegate` refuses to consume it.

6. **Post-regression stages** — When re-running stages after regression, the agent is given the previous stage output plus the regression context. It does NOT start from scratch — it updates.

#### 4.4 HALT State (Max Regression Recovery) [C1]

**Maximum regressions per blueprint: 3.** When the regression limit is reached:

If confidence is ≥0.5 on all stages: proceed normally (regressions exhausted but quality is acceptable).

If confidence is <0.5 on any stage AND the regression limit is reached: the blueprint enters a **HALT** state.

```json
{
  "status": "halted",
  "halted_reason": "Max regressions (3) reached with confidence <0.5 on [stage]",
  "halted_at": "2026-02-07T21:00:00Z"
}
```

**HALT recovery prompt:**

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

### 5. Confidence Scoring (Empirica Integration)

#### 5.1 Enforcement via Hook [C2]

When a blueprint workflow is active (state.json exists with `current_stage` not equal to `"complete"` or `"halted"`), Empirica calls are enforced via a **stage-gate hook**, not just markdown instructions.

**Hook: `hooks/blueprint-stage-gate.sh`**

A PostToolUse hook that fires on Write operations to `state.json`. Before allowing a stage transition (status changing to `"complete"`), it checks:

1. `empirica_session_id` exists and is non-null in state.json
2. The previous stage has a `confidence` score recorded
3. If transitioning from Stage 1 → 2, a PREFLIGHT assessment exists (checked via `empirica_preflight_complete: true` flag in state.json)

If any check fails, the hook outputs a warning:

```
⚠ Blueprint stage gate: Missing Empirica data.
  - [ ] empirica_session_id in state.json
  - [x] confidence score for [stage]
  - [ ] preflight assessment

Run the required Empirica calls before advancing to the next stage.
```

The hook is **advisory** (exit 0) but its output is visible to the agent, creating strong social pressure to comply. Future enhancement: make it blocking (exit 2) once confidence in the hook is established.

**Required Empirica calls:**

| Event | Empirica Call | Data |
|-------|--------------|------|
| Blueprint created | `session_create` | ai_id: "claude-code", session_type: "development" |
| Blueprint created | `submit_preflight_assessment` | 13 vectors assessing knowledge of the task |
| Each stage completed | `finding_log` | Stage summary as finding |
| Confidence scored | `finding_log` + confidence metadata | Per-stage confidence |
| Regression occurs | `mistake_log` or `deadend_log` | What was wrong, what changed |
| Blueprint complete | `submit_postflight_assessment` | 13 vectors assessing current state |
| Dead-end encountered | `deadend_log` | Approach tried, why it failed |

The `/blueprint` command markdown ALSO includes explicit instructions (belt and suspenders):

```
EMPIRICA ENFORCEMENT:
When this workflow is active, you MUST call Empirica at each stage transition.
This is not optional. The confidence data feeds regression decisions.
The blueprint-stage-gate hook will flag missing Empirica data.

Before starting Stage 1:
  - Call session_create with ai_id "claude-code"
  - Call submit_preflight_assessment with honest self-assessment
  - Store session_id in state.json under "empirica_session_id"

After completing each stage:
  - Call finding_log with a summary of what was learned
  - Record confidence score in state.json

On regression:
  - Call mistake_log if the regression was caused by an error in judgment
  - Call deadend_log if an approach was tried and failed

After Stage 7 complete (or workflow abandoned):
  - Call submit_postflight_assessment
```

#### 5.2 Session ID Storage [H1]

The Empirica session_id is stored in **two locations** for redundancy:

1. `state.json` → `"empirica_session_id": "uuid"` (primary, always checked)
2. `manifest.json` → `"empirica_session_id": "uuid"` (backup, for cross-session recovery)

On blueprint resume: check state.json first, fall back to manifest.json. If both are missing, create a **continuation session** via `session_create` and log the discontinuity:

```json
{
  "empirica_session_id": "new-uuid",
  "empirica_session_note": "Continuation session — original session_id lost across conversation boundary"
}
```

Include `empirica_session_id` explicitly in `memory_compact` handoff and checkpoint data.

#### 5.3 Confidence Scores

After each stage, the agent assesses confidence on a 0.0-1.0 scale. This is stored in state.json per-stage:

```json
{
  "stages": {
    "describe": {
      "status": "complete",
      "completed": "2026-02-07T18:00:00Z",
      "confidence": 0.95,
      "confidence_note": "Clear scope, well-understood domain"
    },
    "specify": {
      "status": "complete",
      "completed": "2026-02-07T18:30:00Z",
      "confidence": 0.75,
      "confidence_note": "Token refresh edge cases not fully mapped"
    }
  }
}
```

#### 5.4 Regression Threshold

Default threshold: 0.5. Below this, a regression is **suggested** (not auto-triggered) IF a trigger event also occurs [L3].

The threshold could be made configurable in the future but starts as a fixed constant.

#### 5.5 Empirica Vector Mapping

The per-stage confidence maps to Empirica's 13 epistemic vectors as follows:

| Stage | Primary Vectors | Rationale |
|-------|----------------|-----------|
| Describe | CLARITY, CONTEXT | "Do I understand what we're building and why?" |
| Specify | KNOW, DO, COMPLETENESS | "Do I know enough to specify this fully?" |
| Challenge | UNCERTAINTY, SIGNAL | "What don't I know? What am I missing?" |
| Edge Cases | SIGNAL, DENSITY | "Have I found the important boundaries?" |
| Pre-Mortem | CHANGE, IMPACT | "What could go wrong in production?" |
| Test | COHERENCE, COMPLETENESS | "Do the tests cover the spec?" |
| Execute | DO, STATE | "Can I implement this correctly?" |

These mappings guide the PREFLIGHT and POSTFLIGHT assessments — the agent focuses on the vectors most relevant to the current stage.

---

### 6. Token-Dense Manifest Storage

#### 6.1 manifest.json Schema

A structured, compressed representation of the entire blueprint's key facts. Maintained automatically — updated after every stage completion.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["v", "name", "summary", "scope"],
  "properties": {
    "v": {
      "type": "integer",
      "const": 1,
      "description": "Manifest schema version"
    },
    "name": {
      "type": "string"
    },
    "summary": {
      "type": "string",
      "description": "One-line description of the blueprint's purpose"
    },
    "scope": {
      "type": "object",
      "properties": {
        "files_touched": {
          "type": "array",
          "items": { "type": "string" },
          "description": "File paths or globs affected"
        },
        "risk_flags": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Risk categories from triage (auth, database, deletion, etc.)"
        },
        "path": {
          "type": "string",
          "enum": ["light", "standard", "full"]
        },
        "challenge_mode": {
          "type": "string",
          "enum": ["vanilla", "debate", "team"]
        },
        "execution_preference": {
          "type": "string",
          "enum": ["speed", "simplicity", "auto"],
          "description": "User intent for execution style [H4]"
        }
      }
    },
    "spec_digest": {
      "type": "object",
      "properties": {
        "changes": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "action": { "type": "string", "enum": ["create", "modify", "delete"] },
              "target": { "type": "string" },
              "desc": { "type": "string" }
            }
          }
        },
        "preserve": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Preservation contract items"
        },
        "success_criteria": {
          "type": "array",
          "items": { "type": "string" }
        },
        "failure_modes": {
          "type": "array",
          "items": { "type": "string" }
        }
      }
    },
    "adversarial_digest": {
      "type": "object",
      "properties": {
        "critical": { "type": "array", "items": { "$ref": "#/$defs/finding" } },
        "high": { "type": "array", "items": { "$ref": "#/$defs/finding" } },
        "medium": { "type": "array", "items": { "$ref": "#/$defs/finding" } },
        "low": { "type": "array", "items": { "$ref": "#/$defs/finding" } },
        "regressions_triggered": { "type": "integer" }
      }
    },
    "edge_cases_digest": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "boundary": { "type": "string" },
          "impact": { "type": "string", "enum": ["critical", "high", "medium", "low"] },
          "likelihood": { "type": "string", "enum": ["common", "uncommon", "rare", "theoretical"] },
          "addressed": { "type": "boolean" }
        }
      }
    },
    "premortem_digest": {
      "type": "object",
      "properties": {
        "top_failure": { "type": "string" },
        "contributing_factors": { "type": "array", "items": { "type": "string" } },
        "new_findings_count": { "type": "integer" },
        "covered_count": { "type": "integer" }
      }
    },
    "work_units": {
      "type": "array",
      "items": { "$ref": "#/$defs/work_unit" }
    },
    "parallel_score": {
      "type": "object",
      "properties": {
        "width": { "type": "integer", "description": "Max concurrent work units" },
        "critical_path": { "type": "integer", "description": "Minimum sequential steps" },
        "file_conflicts": { "type": "array", "items": { "type": "string" } }
      }
    },
    "decisions": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "topic": { "type": "string" },
          "chosen": { "type": "string" },
          "reason": { "type": "string" },
          "alternatives_rejected": { "type": "array", "items": { "type": "string" } }
        }
      }
    },
    "confidence": {
      "type": "object",
      "description": "Per-stage confidence scores (0.0-1.0)",
      "additionalProperties": { "type": "number", "minimum": 0.0, "maximum": 1.0 }
    },
    "revision": {
      "type": "integer",
      "description": "Spec revision number (increments on regression)"
    },
    "last_regression": {
      "type": ["object", "null"],
      "properties": {
        "from_stage": { "type": "string" },
        "to_stage": { "type": "string" },
        "reason": { "type": "string" },
        "timestamp": { "type": "string", "format": "date-time" }
      }
    },
    "empirica_session_id": {
      "type": ["string", "null"],
      "description": "Empirica session UUID — redundant copy for cross-session recovery [H1]"
    },
    "artifact_timestamps": {
      "type": "object",
      "description": "Last-modified timestamps per artifact for staleness detection [L2]",
      "additionalProperties": { "type": "string", "format": "date-time" }
    }
  },
  "$defs": {
    "finding": {
      "type": "object",
      "properties": {
        "finding": { "type": "string" },
        "source": { "type": "string", "description": "challenger, defender, judge, boundary_explorer, stress_tester, synthesizer, pre-mortem" },
        "convergence": { "type": "string", "enum": ["both-agreed", "disputed", "newly-identified"] },
        "stage": { "type": "string" }
      }
    },
    "work_unit": {
      "type": "object",
      "required": ["id", "desc", "files", "deps", "complexity"],
      "properties": {
        "id": { "type": "string" },
        "desc": { "type": "string" },
        "files": { "type": "array", "items": { "type": "string" } },
        "deps": { "type": "array", "items": { "type": "string" } },
        "complexity": { "type": "string", "enum": ["low", "medium", "high"] },
        "status": { "type": "string", "enum": ["pending", "in_progress", "complete", "failed"] }
      }
    }
  }
}
```

#### 6.2 Manifest Enforcement Points

The manifest MUST be read (not the full markdown artifacts) at these recovery points:

| Trigger | What Reads Manifest | Why |
|---------|-------------------|-----|
| Session start with active blueprint | Session bootstrap hook output | Orient the agent to current state |
| `/blueprint [name]` resume | The `/blueprint` command itself | Recover full context cheaply |
| `/status [name]` | Status display | Show meaningful summary |
| `/checkpoint` | Checkpoint creation | Include manifest in checkpoint |
| `/dispatch --plan-context [name]` | Dispatch context enrichment | Feed implementer with plan intelligence |
| `/delegate --plan-context [name]` | Delegate context enrichment | Feed orchestrator with plan intelligence |
| Empirica `memory_compact` | Continuation session | Carry forward plan context |

The manifest MUST be written (updated) at these points:

| Trigger | What Writes Manifest |
|---------|---------------------|
| Each stage completion | The stage's command updates the manifest |
| Regression occurs | Regression handler updates manifest |
| Work unit status changes | Execution tracking updates manifest |
| Decision recorded | `/decision` command updates manifest |

#### 6.3 Manifest Write Failure Handling [H5]

If a manifest write fails (permissions error, disk full, JSON serialization error):

1. **Set staleness flag:** Write `"manifest_stale": true` to state.json (smaller, more likely to succeed)
2. **Preserve backup:** If a previous manifest exists, rename to `manifest.json.bak`
3. **Block stage progression:** The blueprint-stage-gate hook checks for `manifest_stale` and blocks advancement until the write succeeds
4. **Recovery on resume:** When resuming a blueprint with `manifest_stale: true`, attempt to regenerate the manifest from source artifacts (describe.md + spec.md + adversarial.md + state.json). If regeneration succeeds, clear the flag and continue. If it fails, halt with an error explaining what's wrong.

#### 6.4 Manifest Corruption Recovery [M4]

If `manifest.json` cannot be read (parse error, missing file, truncated):

1. Attempt regeneration from: `describe.md` → scope, `spec.md` → spec_digest + work_units, `adversarial.md` → adversarial_digest, `state.json` → confidence + revision + regression info
2. If regeneration succeeds: write new manifest, log a warning, continue
3. If regeneration fails (source artifacts also missing/corrupted): halt with explicit error listing which artifacts are missing

#### 6.5 Token Budget Comparison

| Recovery Method | Approx. Tokens | Information Quality |
|----------------|----------------|-------------------|
| Read all markdown artifacts | 3,000 - 8,000+ | Complete (everything) |
| Read manifest.json | 400 - 800 | High (all key facts, structured) |
| Read state.json only | 100 - 200 | Low (progress only, no substance) |
| Read manifest + state | 500 - 1,000 | High (facts + progress) |

The manifest is the default recovery format. Full markdown artifacts are read only when the agent needs detail for a specific stage's work (e.g., reading spec.md when entering Stage 3 to provide it to the debate agents).

#### 6.6 Staleness Detection [L2]

The manifest includes `artifact_timestamps` — a map of artifact filenames to their last-modified timestamps:

```json
{
  "artifact_timestamps": {
    "describe.md": "2026-02-07T18:00:00Z",
    "spec.md": "2026-02-07T19:30:00Z",
    "adversarial.md": "2026-02-07T19:10:00Z"
  }
}
```

On manifest read: compare these timestamps against actual file modification times. If any artifact is newer than its timestamp in the manifest, warn: "Manifest may be stale — [artifact] was modified after last manifest update." This is advisory, not blocking.

---

### 7. Work Graph (Parallelization)

#### 7.1 work-graph.json

A dependency graph of work units, computed during Stage 2 (Specify) and refined through later stages.

```json
{
  "nodes": [
    { "id": "W1", "label": "JWT middleware", "files": ["src/auth/middleware.ts"], "status": "pending", "complexity": "medium" },
    { "id": "W2", "label": "User model update", "files": ["src/models/user.ts"], "status": "pending", "complexity": "low" },
    { "id": "W3", "label": "Auth routes", "files": ["src/routes/auth.ts"], "status": "pending", "complexity": "medium" },
    { "id": "W4", "label": "Integration tests", "files": ["tests/auth.test.ts"], "status": "pending", "complexity": "medium" }
  ],
  "edges": [
    { "from": "W1", "to": "W3", "type": "blocks" },
    { "from": "W2", "to": "W3", "type": "blocks" },
    { "from": "W3", "to": "W4", "type": "blocks" }
  ],
  "batches": [
    { "batch": 1, "units": ["W1", "W2"], "parallel": true },
    { "batch": 2, "units": ["W3"], "parallel": false },
    { "batch": 3, "units": ["W4"], "parallel": false }
  ],
  "analysis": {
    "total_units": 4,
    "max_parallel_width": 2,
    "critical_path_length": 3,
    "file_conflicts": [],
    "parallelization_recommendation": "moderate"
  },
  "spec_work_units_checksum": "sha256:abc123...",
  "generated_at": "2026-02-07T18:30:00Z"
}
```

#### 7.2 Work Units Table Schema [L5]

The spec.md "Work Units" table MUST include these required columns:

| Column | Description | Required |
|--------|-------------|----------|
| ID | Unique identifier (W1, W2, ...) | Yes |
| Description | What the work unit does | Yes |
| Files | File paths or globs affected | Yes |
| Dependencies | Other work unit IDs this depends on | Yes |
| Complexity | low / medium / high | Yes |

#### 7.3 When the Graph is Built

- **Stage 2 (Specify)**: Initial work graph computed from the spec. The spec.md gains a "Work Units" section (human-readable table) that is the source of truth. work-graph.json is the machine-readable companion.
- **Stage 3-4.5**: If adversarial findings or edge cases change the architecture, the work graph may need updating. On regression to Stage 2, the work graph is marked stale [H3].
- **Stage 7 (Execute)**: The work graph feeds directly into `/delegate --plan` decomposition. No need to re-parse the spec.

#### 7.4 Checksum Validation [M3]

The work graph includes a `spec_work_units_checksum` — a SHA-256 hash of the spec.md "Work Units" section. On Stage 7 entry:

1. Recompute the hash of the current spec.md Work Units section
2. Compare with `spec_work_units_checksum` in work-graph.json
3. If mismatch: block `/delegate` until the work graph is regenerated

This prevents manual spec edits from causing divergence between the human-readable table and the machine-readable graph.

#### 7.5 Staleness on Regression [H3]

When regressing to Stage 2:
1. Set `"work_graph_stale": true` in state.json
2. Stage 2 completion MUST regenerate work-graph.json (new checksum, updated nodes/edges)
3. A stale work graph blocks Stage 7 progression

#### 7.6 Parallelization Recommendation

Based on the analysis AND user intent [H4]:

| Width | Critical Path | `execution_preference` | Recommendation |
|-------|--------------|----------------------|----------------|
| Any | Any | `speed` | `strong` (always suggest `/delegate`) |
| Any | Any | `simplicity` | `none` (always suggest sequential) |
| 1 | Any | `auto` | `none` — sequential |
| 2 | ≤3 | `auto` | `moderate` — suggest `/delegate` |
| 3+ | Any | `auto` | `strong` — recommend `/delegate --review` |
| Any | >5 | `auto` | `strong` — recommend `/delegate --review` |

The `execution_preference` is captured during Stage 1 (Describe/triage):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TRIAGE: [name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ...existing triage fields...

  Execution preference:
    [1] Speed — parallelize aggressively, use /delegate
    [2] Simplicity — sequential implementation, minimal overhead
    [3] Auto — let the work graph analysis decide (default)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

At Stage 7 completion screen, the recommendation determines the suggestion:

```
  Implementation options:
    [1] Standard implementation (sequential)
    [2] TDD-enforced → /tdd --plan-context [name]
    [3] Parallel dispatch → /delegate --plan .claude/plans/[name]/spec.md --review
        ↑ Recommended: 2 work units can run concurrently (W1 ∥ W2)
```

---

### 8. Spec Diff Tracking

#### 8.1 spec.diff.md

A revision log maintained whenever the spec is modified after initial completion. Created on first regression, appended on subsequent ones.

```markdown
# Specification Revision History

## Revision 1 (initial)
- Created: 2026-02-07T18:30:00Z
- Sections: [list of top-level sections]

## Revision 1 → Revision 2
- Trigger: Edge case regression (JWT expiry mid-request)
- Date: 2026-02-07T20:15:00Z
- Sections added: 3.2 (Transaction rollback)
- Sections modified: 4.1 (Error handling) — added retry logic
- Sections removed: None
- Sections unchanged: 1.0, 2.0, 3.1, 5.0, 6.0
- Adversarial findings invalidated: 0/12
- Edge case findings invalidated: 1/8 (EC-3: superseded by new rollback strategy)
- Work units affected: W3 (Auth routes) — new dependency on rollback module

## Revision 2 → Revision 3
...
```

#### 8.2 How It's Maintained

When a regression occurs:
1. The current spec.md is read
2. After the user modifies the spec (re-running Stage 2), the agent diffs against the previous version
3. The diff summary is appended to spec.diff.md
4. The manifest.json `revision` field is incremented
5. The manifest's `spec_digest` is updated to reflect the new state

---

### 9. Pre-v2 Migration [M7]

#### 9.1 Detection

When `/blueprint` encounters a plan directory with a state.json that lacks `blueprint_version`:

```json
// Missing field = pre-v2 plan
{
  "name": "old-feature",
  "current_stage": 3,
  // no "blueprint_version", "challenge_mode", "empirica_session_id", etc.
}
```

#### 9.2 Auto-Migration

Apply defaults for all new fields:

```json
{
  "blueprint_version": 2,
  "challenge_mode": "vanilla",
  "execution_preference": "auto",
  "empirica_session_id": null,
  "empirica_preflight_complete": false,
  "manifest_stale": false,
  "work_graph_stale": false,
  "stages": {
    "premortem": { "status": "skipped", "skip_reason": "created before blueprint-v2" }
  }
}
```

Generate `manifest.json` from existing artifacts (describe.md, spec.md, adversarial.md if they exist). Set `blueprint_version: 2` in state.json.

#### 9.3 User Notification

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

---

### 10. Updated Stage Map

The full stage structure with all enhancements:

```
Stage 1: Describe     → /describe-change (triage, path selection, execution_preference)
Stage 2: Specify      → /spec-change (spec + work units + parallel analysis + work graph)
Stage 3: Challenge    → Debate chain (default) / Vanilla / Agent team
Stage 4: Edge Cases   → Debate chain (default) / Vanilla / Agent team
Stage 4.5: Pre-Mortem → Operational failure exercise
Stage 5: Review       → /gpt-review (optional, external perspective)
Stage 6: Test         → /spec-to-tests (spec-blind)
Stage 7: Execute      → Implementation (with manifest handoff + work graph)

Cross-cutting:
  - Feedback loops (regression from any stage to any earlier stage, max 3)
  - HALT state with escape hatches (when regressions exhausted + low confidence)
  - Confidence scoring (per-stage, Empirica-backed, advisory + trigger gated)
  - Manifest (token-dense recovery format, updated every stage, corruption recovery)
  - Work graph (parallelization readiness, computed in Stage 2, checksum validated)
  - Spec diffs (revision tracking on regression)
  - Empirica session (enforced via hook, spans entire blueprint lifecycle)
  - Debate output schema (JSON validated, vanilla fallback on parse failure)
  - Pre-v2 migration (auto-detect and apply defaults)
```

---

## Success Criteria

1. `/blueprint` invokes the renamed command without triggering native plan mode
2. `/blueprints` lists all active blueprints from `.claude/plans/`
3. All 37+ files referencing `/plan` as a command are updated
4. `scripts/validate-rename.sh` exits 0 (zero stale command references) [C3]
5. Debate mode runs three sequential subagents and produces a curated findings list
6. Debate output conforms to the JSON schema in Section 2.5, with vanilla fallback on failure [H2]
7. Debate subagents respect 5-min individual / 15-min stage timeouts [M5]
8. Team mode gracefully falls back to debate when experimental flag is not set
9. Vanilla mode produces identical output to the current `/plan` challenge stage
10. Pre-mortem stage focuses on operational failures distinct from design failures [M2]
11. Regression prompt fires when automatic triggers are met (confidence + event, not confidence alone) [L3]
12. Regression preserves all existing artifacts, marks revision in spec, and includes preserved resolutions [L1]
13. HALT state activates when max regressions reached with low confidence, offering 3 escape hatches [C1]
14. manifest.json is written after every stage completion
15. manifest.json is read (not full artifacts) at all recovery points listed in 6.2
16. Manifest write failures are detected and block progression until resolved [H5]
17. Manifest corruption triggers artifact-based regeneration [M4]
18. Empirica session is created at blueprint start and postflight submitted at end
19. Empirica session_id stored in both state.json and manifest.json [H1]
20. `hooks/blueprint-stage-gate.sh` checks for Empirica data before stage transitions [C2]
21. work-graph.json is computed during Stage 2 and consumed by `/delegate` at Stage 7
22. Work graph includes checksum and blocks `/delegate` on mismatch [M3]
23. Work graph marked stale on regression to Stage 2 and regenerated [H3]
24. Parallelization recommendation respects `execution_preference` from triage [H4]
25. spec.diff.md is created on first regression and appended on subsequent ones
26. Confidence scores are recorded in state.json per-stage
27. Pre-v2 plans are auto-migrated with sensible defaults [M7]
28. Documentation explains `.claude/plans/` naming with FAQ [M6]
29. Documentation covers all three challenge modes and backward compatibility

---

## Failure Modes

| Failure | Impact | Mitigation |
|---------|--------|-----------|
| Debate subagents produce too much noise | User overwhelmed with false positives | Judge/Synthesizer filters by severity + convergence |
| Debate subagent hangs | Workflow blocks indefinitely | 5-min per agent, 15-min per stage timeout, vanilla fallback [M5] |
| Debate output not parseable as JSON | Regression triggers fail silently | Schema validation with vanilla fallback [H2] |
| Regression loops (Stage 4 → 2 → 3 → 4 → 2...) | Infinite planning, no execution | Max 3 regressions. HALT state with user escape hatches [C1] |
| HALT state reached | Blueprint cannot proceed | Three options: override threshold, simplify scope, abandon [C1] |
| Manifest gets out of sync with artifacts | AI works from stale data | Artifact timestamps + staleness detection [L2] |
| Manifest write fails | Next resume loads stale data | Staleness flag, backup preservation, blocked progression [H5] |
| Manifest corrupted | All recovery points fail | Regeneration from source artifacts [M4] |
| Empirica session not created (agent skips it) | No confidence data for regression decisions | Hook-based enforcement via blueprint-stage-gate.sh [C2] |
| Empirica session_id lost across conversations | POSTFLIGHT can't calculate delta | Dual storage (state.json + manifest.json) + continuation session [H1] |
| Agent team mode fails (experimental) | Challenge stage incomplete | Automatic fallback to debate mode with user notification |
| `.claude/plans/` naming confuses new users | Support questions | Documentation note + FAQ in README [M6] |
| Stale /plan references after rename | Broken command invocation or native mode trigger | Validation script with zero-violation acceptance criteria [C3] |
| Work graph diverges from spec edits | Incorrect parallelization | Checksum validation on Stage 7 entry [M3] |
| Work graph stale after regression | `/delegate` uses outdated decomposition | Staleness flag blocks Stage 7 until regenerated [H3] |
| Pre-v2 plan resumed with v2 code | Missing fields, crashes | Auto-migration with sensible defaults [M7] |

---

## Rollback Plan

If the enhancement causes issues:

1. **Rename rollback**: `git mv commands/blueprint.md commands/plan.md` + restore references. The storage path never changed, so no data migration needed.
2. **Debate mode rollback**: Set `--challenge=vanilla` as default. The subagent prompts are self-contained and can be removed without affecting other features.
3. **Hook rollback**: Remove `hooks/blueprint-stage-gate.sh`. Empirica enforcement returns to advisory-only in command markdown.
4. **Manifest rollback**: The manifest is additive — removing it just means falling back to reading full markdown artifacts. No data loss.
5. **Empirica rollback**: Remove enforcement language from command. Empirica calls become optional again.
6. **Migration rollback**: Pre-v2 plans were only extended (new fields added), never mutated. Removing v2 fields restores original state.

All enhancements are additive and independently revertible.

---

## Open Questions

1. **Debate model selection**: Should debate agents use sonnet (richer analysis, higher cost) or haiku (cheaper, faster, possibly less insightful)? Current spec says sonnet. Could make it configurable with `--debate-model`.
2. **Pre-mortem in debate mode**: Should the pre-mortem also run as a debate chain, or is a single-agent pass sufficient? A debate pre-mortem would be thorough but adds 3 more subagent calls.
3. **Agent team hook enforcement**: The `TeammateIdle` and `TaskCompleted` hooks for team mode quality gates — should these be shell hooks in the repo, or inline instructions in the command markdown?
4. **Blueprint-stage-gate hook strictness**: Start advisory (exit 0) and promote to blocking (exit 2) after validation? Or start blocking from day one?

---

## Work Units

| ID | Description | Files | Dependencies | Complexity |
|----|-------------|-------|--------------|------------|
| W1 | Rename commands (plan→blueprint, plans→blueprints) | commands/blueprint.md, commands/blueprints.md | None | Low |
| W2 | Update all cross-references (37+ files) + validation script | All files referencing /plan or /plans as commands, scripts/validate-rename.sh | W1 | Medium |
| W3 | Update hooks (session-bootstrap, state-index-update) | hooks/session-bootstrap.sh, hooks/state-index-update.sh | W1 | Low |
| W4 | Write debate mode prompts, logic, and output schema into blueprint.md | commands/blueprint.md | W1 | High |
| W5 | Write team mode fallback logic into blueprint.md | commands/blueprint.md | W4 | Medium |
| W6 | Add pre-mortem stage (operational focus) to blueprint.md | commands/blueprint.md | W4 | Medium |
| W7 | Add feedback loop / regression logic + HALT state to blueprint.md | commands/blueprint.md | W4 | High |
| W8 | Define manifest.json schema + corruption/staleness handling in PLANNING-STORAGE.md | docs/PLANNING-STORAGE.md | None | Medium |
| W9 | Add manifest read/write enforcement + write failure handling to blueprint.md | commands/blueprint.md | W8 | Medium |
| W10 | Create blueprint-stage-gate.sh hook for Empirica enforcement | hooks/blueprint-stage-gate.sh | None | Medium |
| W11 | Add Empirica enforcement + dual session_id storage to blueprint.md | commands/blueprint.md | W10 | Medium |
| W12 | Define work-graph.json schema + checksum validation in PLANNING-STORAGE.md | docs/PLANNING-STORAGE.md | None | Medium |
| W13 | Add work graph generation + staleness tracking to spec-change.md | commands/spec-change.md | W12 | Medium |
| W14 | Add execution_preference to describe-change.md triage | commands/describe-change.md | None | Low |
| W15 | Add confidence scoring + advisory threshold to state.json schema | docs/PLANNING-STORAGE.md | None | Low |
| W16 | Add spec.diff.md tracking to blueprint.md | commands/blueprint.md | W7 | Low |
| W17 | Add pre-v2 migration logic to blueprint.md | commands/blueprint.md | W7, W11 | Medium |
| W18 | Write BLUEPRINT-MODES.md explanation doc | docs/BLUEPRINT-MODES.md | W4, W5 | Medium |
| W19 | Update README.md with all changes + FAQ | README.md | W1, W4, W18 | Medium |
| W20 | Update commands/README.md reference | commands/README.md | W1, W4, W6, W7 | Medium |

Parallelization score: Width 5 (W1/W8/W10/W12/W14 can run concurrently), critical path 5 steps.
