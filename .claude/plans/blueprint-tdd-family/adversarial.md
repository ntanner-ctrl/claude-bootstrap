# Adversarial Findings

## Family Round 1

### Synthesis (Mother)

The spec is architecturally sound at the conceptual level but was underspecified at the integration level. Three largest gaps shared the same root cause: describing what should happen but not how the components connect.

**Cross-cutting theme:** For a markdown-only toolkit, integration surfaces are unusual — but delegate.md reading TDD annotations from work-graph.json is a real integration point requiring explicit specification.

### Analysis (Father)

6 directed changes identified, all adopted into spec revision 2:

| # | Change | Priority | Status |
|---|--------|----------|--------|
| 1 | WU-4: Name delegate.md integration point (Step 3 IMPLEMENTER_PROMPT + plan context block) | Critical | Spec updated |
| 2 | WU-3: Defer Guided Walkthrough to follow-on blueprint | Critical | Spec updated — Stage 7 ships with 2 options |
| 3 | S-1: Remove risk_flags, use WU count + complexity distribution | Medium | Spec updated |
| 4 | WU-8: Add token cost comparison table to BLUEPRINT-MODES.md | Medium | Spec updated |
| 5 | WU-3: Add "WUs with tdd:true: N of M" to Stage 7 display | Low | Spec updated |
| 6 | DD-1: Clarify override is conversational, not mutation | Low | Spec updated |

Additional coupling constraint: **WU-6 MUST NOT ship without WU-7** — vault evidence scoped family-as-default to safety specs, not universal. S-1 is what makes universal default viable.

### Historical Review (Elder Council)

| Vault Source | Lesson | Relevance |
|---|---|---|
| hybrid-tdd-parallel-dispatch-experiment (2026-03-25) | Experiment explicitly recommends "reads the work graph's TDD annotations and generates appropriate agent prompts" | supports WU-4 mechanism |
| prism-premortem-context-exhaustion (2026-03-22) | Orchestrator context exhaustion from accumulated state across interactive rounds | warns against Guided Walkthrough without dedicated design |
| family-debate-catches-critical-bugs (2026-03-20) | Family-as-default recommended for "specs touching hooks or safety features" — domain-scoped, not universal | warns — S-1 needed to bridge domain→universal |
| workflow-orphan-analysis (2026-03-20) | Commands referenced but never implemented become orphan concepts | warns — deferred Guided Walkthrough needs tracking |
| unit4-decomposition (2026-03-24) | WU count alone is a reliable complexity proxy | supports S-1 simplification |

**Elder Verdict:** CONVERGED
**Confidence:** 0.85
**Carry Forward:** (1) Delegate integration point is Step 3 + plan context block; (2) WU-6/WU-7 atomic; (3) Track deferred Guided Walkthrough to prevent orphan concept.

### False Positives

- Challenge #2 (spec-change.md doesn't exist) was **incorrect** — the file exists at `commands/spec-change.md`. Challenger searched incorrectly.

---

## Family Round 1 — Edge Cases

### Synthesis (Mother → Father → Elder — combined pass)

18 boundaries mapped. 3 Critical, 6 High, 7 Medium, 2 Low.

**Spec changes adopted (5):**

| ID | Boundary | Action | Status |
|----|----------|--------|--------|
| SC-1 | B9: Timeout math (3 rounds × 5 agents > 25min) | Added DD-6 with worst-case analysis. Total timeout scales: 25min Simple/Medium, 40min Complex | Spec updated |
| SC-2 | B15: WU-3/WU-6 file conflict (blueprint.md) | Added WU-3 as WU-6 dependency. Prevents parallel dispatch race condition | Spec updated |
| SC-3 | B10: WU-6/WU-7 atomic coupling prose-only | WU-7 already depends on WU-6; WU-6 now depends on WU-3. Work graph enforces ordering | Spec updated |
| SC-4 | B2: tdd string vs boolean | WU-1 specifies JSON boolean. WU-4 specifies strict equality. Multi-file WU matching defined | Spec updated |
| SC-5 | B7: Resume reads wrong default | Added explicit resume behavior: state.json challenge_mode, NOT frontmatter | Spec updated |

**Implementation notes (4):**

| ID | Boundary | Note for Implementer |
|----|----------|---------------------|
| IN-1 | B11: Task-to-WU matching | Match on any file in WU files list, first match wins, no match = tdd:false |
| IN-2 | B13: Old work-graph.json | Absent tdd field defaults to false (schema note in WU-1) |
| IN-3 | Deferred walkthrough | Document as follow-on blueprint in BLUEPRINT-MODES.md |
| IN-4 | B8: family_progress reset | On regression, reset family_progress.rounds_completed to 0 |

**Acceptable risks (1):**

| ID | Boundary | Rationale |
|----|----------|-----------|
| AR-1 | B6: --rounds=0 or >3 | Non-destructive in markdown toolkit. 0 = no rounds, high N = expensive but functional |

### Historical Review (Elder)

| Vault Source | Lesson | Applied To |
|---|---|---|
| prism-premortem-context-exhaustion | Model orchestrator's own resource consumption | B9 timeout |
| hybrid-tdd-parallel-dispatch-experiment | File conflict detection is load-bearing for parallel safety | B15 file conflict |
| workflow-orphan-analysis | Prose constraints are ignored; graph edges enforce | B10, deferred walkthrough |
| family-debate-catches-critical-bugs | Behavioral assumptions need explicit implementation anchors | B7 resume behavior |

**Elder Verdict:** CONVERGED (after spec changes applied)
**Confidence:** 0.85

## Complexity Review

Pending — will run `/overcomplicated` after Stage 4.
