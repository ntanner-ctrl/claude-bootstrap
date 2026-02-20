# Implementation Notes for Blueprint v2

> Generated from Revision 2 re-validation debate (PASS_WITH_NOTES verdict)
> These are clarifications to resolve during implementation, not spec changes.

## Medium-Priority Clarifications

### F2 — Debate Fallback Parsing
**When:** Implementing debate mode (W4)
**Context:** If Judge/Synthesizer JSON output fails schema validation
**Guidance:** Use basic pattern matching to extract findings from freeform markdown:
- Look for numbered items: `F[0-9]+`, `[0-9]+\.`, `- `
- Assign all extracted findings: severity=medium, convergence=newly-identified
- If no list items found, wrap entire output as single finding
- Log warning via Empirica `deadend_log`
- Flag all for human review

### F4 — Manifest Corruption Recovery Priority
**When:** Implementing manifest handling (W8, W9)
**Context:** What to do when both manifest.json AND state.json are corrupted
**Guidance:** Recovery priority order:
1. Regenerate manifest from artifacts + state.json (normal path)
2. If state.json also corrupt: derive stage status from artifact existence/timestamps
   - describe.md exists → describe complete
   - spec.md exists → specify complete
   - adversarial.md exists → challenge complete
3. Check for manifest.json.bak (from H5 write failure handling)
4. If all fail: halt with explicit error listing missing/corrupted files

### F8 — Pre-Mortem Overlap Detection
**When:** Implementing pre-mortem stage (W6)
**Context:** "80% overlap" threshold needs an operational definition
**Guidance:** Semantic match algorithm:
- For each pre-mortem finding, check adversarial.md for same failure category + same affected component
- If match found → mark as COVERED
- If (COVERED count / total pre-mortem findings) > 0.8 → note `"premortem_overlap": "high"` in state.json
- On future blueprints with similar scope, suggest skipping pre-mortem

### F9 — "Flag as Blocking" Behavior
**When:** Implementing regression prompts (W7)
**Context:** Option [3] in regression prompt needs defined behavior
**Guidance:**
- Set `"status": "blocked_pending_resolution"` in state.json
- Store `"blocking_finding": "F[id]"` in state.json
- Append finding with `[BLOCKING]` tag to adversarial.md
- Workflow refuses to advance until user runs `/blueprint [name]` and resolves
- Resolution note appended to adversarial.md with timestamp

### F15 — HALT Confidence Check Scope
**When:** Implementing HALT state (W7)
**Context:** Skipped stages have no confidence score
**Guidance:** HALT trigger condition should be:
```
IF regression_count >= 3
AND any stage with status="complete" has confidence < 0.5
THEN enter HALT state
```
Stages with status="skipped" or "pending" are excluded from evaluation.

### F17 — Work Graph Checksum Mismatch Recovery
**When:** Implementing work graph validation (W12, W13)
**Context:** Checksum mismatch at Stage 7 blocks `/delegate` but no regeneration path defined
**Guidance:**
1. On mismatch, prompt: "Work graph is stale. Regenerating from current spec..."
2. Auto-regenerate work-graph.json from spec.md Work Units section
3. If regeneration succeeds: log warning, update checksum, proceed
4. If regeneration fails (malformed table): halt with error pointing to spec.md

### F19 — Challenge Mode Across Regressions
**When:** Implementing regression behavior (W7)
**Context:** challenge_mode preservation unspecified
**Guidance:** Challenge mode is set once at blueprint creation and locked for the lifecycle.
When re-running Stages 3/4 after regression, use the same `challenge_mode` from state.json.
Do not re-prompt for mode selection.

---

## Low-Priority Items (fix inline during implementation)

| ID | Fix | Relevant Work Unit |
|----|-----|--------------------|
| F3 | Add note that PostToolUse reads completed write | W10 |
| F5 | Fix "Stage 3" → "Stage 7" in staleness text | W7 or W12 |
| F6 | Clarify execution_preference is advisory, not binding | W14 |
| F10 | Define PASS_WITH_NOTES: proceed, append findings, no regression | W4 |
| F12 | Remove "overrides.json" reference from HALT section | W7 |
| F14 | Save spec.md.revision-N.bak before regression re-entry | W16 |
| F20 | Mark team mode hooks as deferred (Open Question 3) | W5 |
