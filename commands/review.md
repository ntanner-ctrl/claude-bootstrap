---
description: REQUIRED after completing a blueprint on the Full path. External perspective catches what familiarity blinds you to.
arguments:
  - name: target
    description: Blueprint name, file path, or 'current' for active context
    required: false
---

## Cognitive Traps

Before skipping or simplifying this command, check yourself:

| Rationalization | Why It's Wrong |
|----------------|---------------|
| "The blueprint already challenged this thoroughly" | Blueprint challenges the PLAN. Review challenges the IMPLEMENTATION. Different artifacts, different failure modes. |
| "I'll just do a quick look instead of running the full workflow" | A "quick look" misses what structured adversarial review catches: the things you don't think to look for. |
| "This is a small change, review is overkill" | Small changes in critical paths cause the biggest incidents. The review is proportional to risk, not size. |

# Review

Focused adversarial review workflow. Use this when you have a blueprint or implementation and want to systematically challenge it without going through full planning stages.

## Overview

```
Stage 1: Devil's Advocate  → Challenge assumptions
Stage 2: Simplify          → Question complexity
Stage 3: Edge Cases        → Probe boundaries
Stage 4: External (opt)    → GPT review for blind spots
Stage 5: Deep Analysis (opt) → Plugin-enhanced specialized review
```

Stage 5 only appears when specialized review plugins are detected.

## Process

### State Initialization

Before doing anything else, initialize or resume wizard state:

```
1. Ensure .claude/wizards/ exists (mkdir -p equivalent)
2. Check for active session: look for .claude/wizards/review-*/state.json
   - If multiple matches: select most recent by created_at timestamp, archive others
3. Dispatch based on session status:
```

**If active session found (`status == "active"`):**

Compute session age from `created_at`. Validate `version == 1` — if not, treat as corrupt (start fresh).

Display progress header:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Resuming session from [N hours/minutes ago]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [staleness warning if session > 4 hours old]

  [✓/→/○] Vault Check
  [✓/→/○] Identify Target
  [✓/→/○] Devil's Advocate
  [✓/→/○] Simplify
  [✓/→/○] Edge Cases
  [✓/→/○/—] External Review
  [✓/→/○/—] Deep Analysis
  [✓/→/○] Compile Summary

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [1] Resume from [current_step]
  [2] Abandon and start fresh

>
```

On **Resume**: reconstruct context from `output_summary` fields of completed steps + `context` object, then skip to `current_step`. Any substep with `status: active` is treated as `pending` — re-run it.

On **Abandon**: set `status: abandoned` in state.json, create new session (continue to new session flow below).

**If error session found (`status == "error"`):**

```
Previous review session errored at [step name].
  [1] Resume from last complete step
  [2] Abandon and start fresh

>
```

On Resume: set `current_step` to the step after the last complete step. Do NOT re-run the failed step automatically.

**If no active/error session (or prior session was complete/abandoned):**

Create `.claude/wizards/review-<YYYYMMDD-HHMMSS>/state.json` with:

```json
{
  "wizard": "review",
  "version": 1,
  "session_id": "review-<YYYYMMDD-HHMMSS>",
  "status": "active",
  "current_step": "vault_check",
  "steps": {
    "vault_check": { "status": "pending" },
    "identify_target": { "status": "pending" },
    "devils_advocate": { "status": "pending" },
    "simplify": { "status": "pending" },
    "edge_cases": { "status": "pending" },
    "external_review": { "status": "pending", "conditional": true },
    "deep_analysis": { "status": "pending", "conditional": true },
    "compile": { "status": "pending" }
  },
  "context": {
    "target_type": null,
    "target_description": null,
    "blueprint_name": null
  },
  "vault_checkpoints": [],
  "created_at": "<ISO-8601 timestamp>",
  "updated_at": "<ISO-8601 timestamp>"
}
```

Then run cleanup: for each `.claude/wizards/review-*/state.json`, if `created_at` age > 7 days and `status` is `complete`, `abandoned`, or `error`, move the directory to `.claude/wizards/_archive/`. If age > 7 days and `status == "active"`, log a warning but do NOT archive.

Display initial stage progression header:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Starting new session
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  → Vault Check
  ○ Identify Target
  ○ Devil's Advocate
  ○ Simplify
  ○ Edge Cases
  ○ External Review
  ○ Deep Analysis
  ○ Compile Summary

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

State writes are fail-open — if state.json cannot be written, log a warning and continue without state.

---

### Vault Check

Before starting the review, check for prior work:

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null
```

If vault is available (`VAULT_ENABLED=1`, `VAULT_PATH` non-empty, `[ -d "$VAULT_PATH" ]`):
- Search for prior reviews, decisions, or findings related to the target
- If matches found: "Vault has N notes related to this review target:" [list with 1-line summaries]
- If no matches: proceed silently

If vault unavailable: skip silently (fail-open).

**State transition — vault_check complete:**
Update state.json:
- `steps.vault_check.status` → `"complete"`
- `steps.vault_check.output_summary` → prior review count found, relevant finding titles (~50 tokens)
- `steps.identify_target.status` → `"active"`
- `current_step` → `"identify_target"`
- `updated_at` → current timestamp

### Step 1: Identify Target

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 1 of 5: Setup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

What are you reviewing?

  [1] An existing blueprint (provide name or path)
  [2] Current implementation (describe scope)
  [3] An idea or approach (describe it)

>
```

**State transition — identify_target complete:**
Update state.json:
- `steps.identify_target.status` → `"complete"`
- `steps.identify_target.output_summary` → target type, target description, scope (~50 tokens)
- `context.target_type` → one of `"blueprint"` / `"implementation"` / `"idea"`
- `context.target_description` → brief description of what is being reviewed
- `context.blueprint_name` → blueprint name if target_type is `"blueprint"`, otherwise `null`
- `steps.devils_advocate.status` → `"active"`
- `current_step` → `"devils_advocate"`
- `updated_at` → current timestamp

### Step 2: Run Adversarial Stages

**Stage 1: Devil's Advocate**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 1 of 5: Devil's Advocate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Challenging assumptions...
```

Run `/devils-advocate` on the target.

> Stage 1 complete: [N] assumption gaps found. Proceeding to Stage 2 (Simplify).

**State transition — devils_advocate complete:**
Update state.json:
- `steps.devils_advocate.status` → `"complete"`
- `steps.devils_advocate.output_summary` → finding count with severity breakdown, top 2 findings (~150 tokens)
- `steps.simplify.status` → `"active"`
- `current_step` → `"simplify"`
- `updated_at` → current timestamp

**Stage 2: Simplify**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 2 of 5: Simplify
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Questioning complexity...
```

Run `/overcomplicated` on the target.

> Stage 2 complete: [N] simplification opportunities found. Proceeding to Stage 3 (Edge Cases).

**State transition — simplify complete:**
Update state.json:
- `steps.simplify.status` → `"complete"`
- `steps.simplify.output_summary` → simplification count, top opportunity (~100 tokens)
- `steps.edge_cases.status` → `"active"`
- `current_step` → `"edge_cases"`
- `updated_at` → current timestamp

**Stage 3: Edge Cases**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 3 of 5: Edge Cases
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Probing boundaries...
```

Run `/edge-cases` on the target.

> Stage 3 complete: [N] unhandled edge cases found. Proceeding to Stage 4 (External Review).

**State transition — edge_cases complete:**
Update state.json:
- `steps.edge_cases.status` → `"complete"`
- `steps.edge_cases.output_summary` → unhandled edge case count, top 2 boundaries (~150 tokens)
- `steps.external_review.status` → `"active"` (conditional: if skipped, set to `"skipped"` with `skip_reason: "User declined"`)
- `current_step` → `"external_review"`
- `updated_at` → current timestamp

**Stage 4: External Review (Optional)**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 4 of 5: External Review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Would you like an external perspective via /gpt-review?
This can catch blind spots that local review missed.

  [1] Yes - run external review
  [2] No - skip, local review is sufficient

>
```

If yes, run `/gpt-review` with all local findings included.

> Stage 4 complete: external review [included/skipped]. Proceeding to Stage 5 (Deep Analysis).

**State transition — external_review complete:**
Update state.json:
- `steps.external_review.status` → `"complete"` (or `"skipped"` if user declined, already set above)
- `steps.external_review.output_summary` → "included, N findings" or "skipped: user declined" (~50 tokens)
- `steps.deep_analysis.status` → `"active"` (or `"skipped"` if no plugins detected or `/review --quick`)
- `current_step` → `"deep_analysis"`
- `updated_at` → current timestamp

**Stage 5: Deep Analysis (Optional)**

After completing the core 4 stages, check for plugin enhancements:

1. Read `commands/plugin-enhancers.md`. If file not found, skip this stage entirely.
2. Follow the Detection Protocol (Section 1) to check for review-capable plugins.
3. If NO review plugins detected, skip this stage entirely (don't show the option).
4. Build options list from detected plugins:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 5 of 5: Deep Analysis (optional)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Core adversarial review complete.

  Deep analysis available (select one or more, comma-separated):

  [If pr-review-toolkit detected:]
    [1] PR Toolkit — 6 specialized agents in parallel
        (silent failures, type design, test coverage,
         comments, simplification, conventions)

  [If security-pro detected:]
    [2] Security Audit — security-pro:security-auditor
        Deep vulnerability assessment and compliance

  [If performance-optimizer detected:]
    [3] Performance Audit — performance-optimizer:performance-engineer
        Bottleneck identification and optimization

  [If superpowers detected:]
    [4] Methodology Review — superpowers:code-reviewer
        Code review against project guidelines and best practices

  [If feature-dev detected:]
    [5] Conventions Review — feature-dev:code-reviewer
        Convention-focused review with confidence-based filtering

  [If frontend detected:]
    [6] Multi-Model Review — frontend:reviewer
        Parallel assessment from multiple AI models

    [N] Skip — core review is sufficient

>
```

Options are dynamically numbered based on detected plugins. Multiple can be selected.

5. For each selected option:
   - Fast-fail probe: dispatch ONE agent from that plugin with 10-second timeout
   - If probe fails: Log `[PLUGIN] <plugin> probe failed; skipping`, continue to next selection
   - If probe passes: dispatch the plugin's review agent(s) (5-min timeout each)
   - For pr-review-toolkit: dispatch all 6 agents in parallel
   - For other plugins: dispatch the single registered review agent
   - Format results per plugin-enhancers.md Section 5
   - Circuit breaker: 3 consecutive failures from same plugin → abort remaining agents for that plugin
   - Add results to the Review Summary under "### Deep Analysis" section

6. Quick mode (`/review --quick`) skips this stage entirely.

**State transition — deep_analysis complete:**
Update state.json:
- `steps.deep_analysis.status` → `"complete"` (or `"skipped"` if no plugins detected / user skipped / `--quick` mode)
- `steps.deep_analysis.output_summary` → plugin findings count, top concerns (~100 tokens); or `"skipped: no plugins detected"` / `"skipped: --quick mode"`
- `steps.compile.status` → `"active"`
- `current_step` → `"compile"`
- `updated_at` → current timestamp

### Step 3: Compile Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Review Summary: [target]

### Devil's Advocate
- Gaps found: [N]
- Critical: [list]

### Simplify
- Simplification opportunities: [N]
- Recommended: [list]

### Edge Cases
- Unhandled: [N]
- High-risk: [list]

### External Review
[Included / Skipped]
[If included, key novel findings]

### Deep Analysis
[If run: plugin findings summary with [plugin-review] tags]
[If skipped: "Not run" or "No specialized plugins detected"]

## Overall Verdict

- [ ] Ready to proceed
- [ ] Address [N] issues first
- [ ] Needs significant rethinking

## Recommended Actions

1. [action]
2. [action]
3. [action]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**State transition — compile complete (session end):**
Update state.json:
- `steps.compile.status` → `"complete"`
- `steps.compile.output_summary` → total findings count, critical count, action items (~100 tokens)
- `status` → `"complete"`
- `current_step` → `null`
- `updated_at` → current timestamp

Then attempt vault checkpoint (fail-open): export review findings summary to vault if configured. On success, append to `vault_checkpoints`:
```json
{ "step": "compile", "exported_at": "<ISO-8601>", "vault_path": "<path>" }
```
On vault unavailable or failure: log warning, continue.

## Failure Modes

| What Could Fail | Detection | Recovery |
|-----------------|-----------|----------|
| Devil's advocate finds nothing to challenge | Stage 1 output is empty | Target may be genuinely solid, or scope is too narrow. Try broadening scope or running `/edge-cases` directly. |
| Plugin agents fail or timeout | Plugin dispatch returns error or no output within 5 minutes | Circuit breaker activates after 3 failures. Fall back to GPT review. See Graceful Degradation section. |
| Target scope too broad | Review produces generic findings without specific file:line references | Narrow scope to a specific blueprint, directory, or component. |
| External review (GPT) unavailable | `/gpt-review` reports WebSearch or proxy unavailable | Skip Stage 4. Local adversarial stages (1-3) provide substantial coverage. |
| All stages produce contradictory findings | Stage 2 (Simplify) recommends removing what Stage 1 flagged as critical | This is signal, not failure. Present contradictions explicitly for user judgment. |

## Known Limitations

- **Implementation-blind when pre-implementation** — Review is most valuable when implementation artifacts exist. Pre-implementation review is based on spec prose only, which limits specificity.
- **Plugin availability varies** — Stages 4-5 depend on optional plugins. Not all environments have the same review capabilities.
- **Single-pass review** — Each stage runs once. Unlike /blueprint's family debate, /review does not iterate on its findings.
- **No automated regression tracking** — Review findings are presented but not automatically wired into blueprint regression loops. User must decide whether to act on findings.

## Quick Mode

For faster review focusing on one dimension:

```
/review --quick devils-advocate [target]
/review --quick simplify [target]
/review --quick edge-cases [target]
```

Runs only the specified stage.

## Output Format

```markdown
# Adversarial Review: [target]

## Executive Summary

| Dimension | Issues | Critical? |
|-----------|--------|-----------|
| Assumptions | [N] gaps | [Yes/No] |
| Complexity | [N] opportunities | [Yes/No] |
| Edge Cases | [N] unhandled | [Yes/No] |
| External | [included/skipped] | — |
| Deep Analysis | [N] findings | [Yes/No] |

## Detailed Findings

### Assumptions (Devil's Advocate)
[findings]

### Complexity (Overcomplicated)
[findings]

### Boundaries (Edge Cases)
[findings]

### External Perspective
[findings if included]

### Deep Analysis (Plugin Review)
[findings if run — formatted per plugin-enhancers.md Section 5]

## Recommended Actions

1. [prioritized action]
2. [prioritized action]
...

## Verdict

[Ready / Needs Work / Rethink]
```

## Post-Review Actions

Based on the verdict:

| Verdict | Suggested Next |
|---------|----------------|
| Ready to proceed | `/design-check` → implementation |
| Address N issues | `/decision` to record trade-offs, then fix |
| Needs rethinking | `/brainstorm` to explore alternatives |

## Integration

- **Standalone:** Can be run on any blueprint, implementation, or idea
- **After /blueprint:** Provides deeper adversarial review post-planning
- **Before /push-safe:** Final check before shipping
- **Findings recorded:** Appended to `.claude/plans/[name]/adversarial.md` if blueprint context active
