# Adversarial Findings: prism

## Stage 3 — Challenge Mode: Family (Round 1)

### Synthesis (Mother)

**Genuinely strong — keep as-is:**
- Observation-only lens agents with structured output format
- 6-lens conceptual roster with "You do NOT care about" boundaries
- Orchestrator-as-command for synthesis and control flow
- Zero-modification reuse of existing domain reviewers
- Vault input/output integration pattern
- Fail-open partial completion (timeout → skip → note → continue)
- Ease/Impact/Risk scoring as a relative ranking tool

**Genuinely needs work — 5 items identified:**
1. Accumulated context compression (no compression strategy for serial domain findings)
2. Synthesis specificity (theme detection algorithm underspecified)
3. Dispatch prompt treatment of prior findings ("account for" is too soft)
4. Error handling scope gap (not covered by any named lens)
5. File distribution strategy (acknowledged in open questions but load-bearing)

**Genuinely uncertain — 2 items:**
- Whether domain reviewers will meaningfully modulate based on accumulated context
- Whether lens boundaries will hold for files where multiple lenses have legitimate claims

### Analysis (Father)

**6 directional changes proposed:**

1. **Add constraint summary format per domain stage** — After each serial stage, orchestrator extracts ~200-300 token constraint block. By Stage 5, quality receives one flat cumulative constraint summary, not five separate raw dumps. Orchestrator owns the compression (not the domain reviewers — stay-in-your-lane pattern).

2. **Make synthesis algorithm explicit** — Two sub-steps: (a) mechanical grouping via co-location rule (same file:line from 2+ lenses = merge candidate) and voting threshold (theme requires 2+ independent observations), then (b) judgment-based classification (theme naming, discrete/nebulous, Ease/Impact/Risk scoring). Separate algorithmic from judgment steps.

3. **Restructure dispatch prompt** — Split "PRIOR DOMAIN FINDINGS" into two labeled sections: CONTEXT (background that informs) and CONSTRAINTS (findings that restrict recommendations). The IMPORTANT clause becomes: "DO NOT recommend anything that conflicts with CONSTRAINTS below. Flag the conflict if you believe the constraint is wrong."

4. **Add error path coverage note** — One paragraph documenting that quality-reviewer owns error path health, cohesion-lens secondary for error-routing mixed into business logic. No new lens needed.

5. **Add multi-lens density as priority signal** — Files with observations from 3+ lenses are HIGH priority candidates regardless of individual confidence scores. Multi-source convergence is a reliability multiplier.

6. **Add re-prompt on malformed lens output** — Single retry if a lens agent doesn't follow structured format. Catches transient format deviations without creating a retry loop.

**3 tensions resolved:**
- Tension 1 (constraint summary ownership): Orchestrator owns it — domain reviewers stay in their lane
- Tension 2 (synthesis algorithm vs judgment): Two sub-steps — mechanical grouping first, then judgment-based classification
- Tension 3 (100-file threshold): Ship 100, instrument it, adjust after 3-5 real runs

**Confidence assessment:** 75-80% ready. Lens agents (W1-W6) can be built today. Orchestrator (W7) needs the 6 changes above.

### Historical Review (Elder Council)

Vault searched: 10 findings, 5 blueprints, 2 decisions spanning 2026-01 through 2026-03.

| Vault Source | Lesson | Relevance |
|---|---|---|
| emoji-text-severity-mismatch (2026-03-13) | Agent output format mismatch is a silent integration failure | Supports change #6 (re-prompt on malformed output) |
| parallel-agent-file-isolation (2026-02-27) | Parallel read-only agents are safe to dispatch concurrently | Supports Wave 1 parallel lens design |
| claude-md-context-budget (2026-03-06) | Trim always-on context to decision-driving information only | Supports change #1 (constraint summaries) |
| cross-project-synthesis-gap (2026-02-19) | Findings from different sources don't connect without explicit synthesis rules | Supports change #2 (explicit synthesis algorithm) |
| compound-failures-family-mode (2026-03-18) | Most dangerous edge case is compound failure where individual components look fine | **Warns:** skipped-stage gap in dispatch prompt needs handling |
| source-of-truth-drift (2026-02-20) | Copies of authoritative data silently rot — derive, don't copy | Supports change #1 (cumulative summary, not five separate dumps) |
| behavioral-feedback-is-mechanism (2026-03-19) | Behavioral instructions must be separated from background info to have effect | **Strongest support** for change #3 (CONTEXT/CONSTRAINTS split) |
| tiered-knowledge-architecture (2026-03-18) | Separate by decay rate — principles vs heuristics vs references | Supports tension #2 resolution (two-step synthesis) |
| naksha-inspired-improvements (2026-03-18) | Complex multi-component addition needed 4 revisions, 68+ findings | Neutral — prism is more complex, needs equivalent rigor |
| family-debate-catches-critical-bugs (2026-03-20) | Family mode caught 6 critical/high bugs single-perspective missed | Validates this review process itself |

**New finding from Elder Council:**
The spec's partial-failure handling has a compound failure risk. When a domain reviewer times out, the next reviewer's dispatch prompt must explicitly note the gap: "NOTE: [domain] review was skipped (timeout). Do NOT assume no [domain] constraints exist — err on the side of flagging potential [domain] conflicts rather than ignoring them." This is a 7th change to add.

**Elder Verdict:** CONVERGED
**Confidence:** 0.85
**Reason:** All 6 proposed changes historically supported or novel-with-precedent. All 3 tensions resolved. One new compound-failure gap surfaced but is implementable during W7 without another spec round.

---

## Stage 4 — Edge Cases: Family (Round 1)

### Synthesis (Mother)

**Genuinely covered (28 boundary positions defended):**
- Empty/single file, no-git-repo, all agent timeouts, mixed success/failure
- Context overflow (paradigm summary compression, constraint budget)
- Vault degradation (read-only, missing dirs, malformed prior reports)
- Zero themes output, large scope warning

**3 critical gaps (must fix):**
1. **Critical severity bypass** — single-source SQL injection buried after multi-source style themes
2. **Same-day vault slug collision** — second run silently overwrites first
3. **Constraint extraction auditability** — no record of what constraints were extracted

**6 additional gaps (sentence-level fixes):**
4. Standalone findings have no defined output format
5. CONSTRAINTS aggregate cap not stated
6. Co-location 5-line window too narrow for function-level convergence
7. 1000+ file agent behavior undefined
8. Zero observations vs malformed output treated identically
9. Tie-breaking rule for equal composite scores undefined

### Analysis (Father)

5 priority changes + 4 short additions. Confidence: 85% → 95% after changes.

Key decisions:
- Constraint extraction: auditability (post-hoc) over validation (mid-pipeline), informed by observability-fix pattern
- File chunking: implementation detail, not spec concern
- Conflict markers: warning not abort

### Elder Council

**Verdict:** CONVERGED at 0.92
**Tensions resolved:**
- Voting bypass: critical-only. Extending to high would gut the voting threshold.
- Constraint extraction corruption: accepted risk, mitigated by auditability + downstream challenge mechanism.

| Vault Source | Supports |
|---|---|
| compound-failures-family-mode | Critical bypass — misleading success signals are most dangerous |
| emoji-text-severity-mismatch | Standalone format + zero/malformed distinction |
| pre-mortem-catches-different-failure-class | Constraint auditability (observability fix pattern) |
| debate-convergence-pattern | Critical-only bypass (don't extend to high) |
| Session naming convention | YYYY-MM-DD-HHMM slug pattern already used in vault |

---

## Stage 4.5 — Pre-Mortem [pre-mortem]

Focus: OPERATIONAL failures (installation, UX, maintenance, real-world usage).

### NEW Findings (8 actionable)

| ID | Finding | Severity |
|----|---------|----------|
| F17 | Orchestrator session token budget never modeled — context exhaustion during synthesis | HIGH |
| F7 | No progress indication during 15-30 min runtime | HIGH |
| F11 | Constraint extraction audit missing from vault export template | HIGH |
| F12 | /quality-sweep vs /prism confusable, no decision guide | HIGH |
| F19 | Session survivability after prism unaddressed | MEDIUM |
| F4 | Vault template in wrong directory (templates/vault-notes/ is for bootstrap targets) | MEDIUM |
| F8 | No minimum scope floor — 3-file project gets 11 agents | MEDIUM |
| F3 | Description trigger field not yet specified — false invocation risk | MEDIUM |

### Recommendations

R1: Token budget estimation in Stage 0 (addresses F17)
R2: Structured progress narration per stage (addresses F7)
R3: Constraint audit section in vault export template (addresses F11)
R4: Minimum scope floor warning <10 files (addresses F8)
R5: Evals fixture for prism trigger behavior (addresses F3)
R6: "Start fresh session" note in report footer (addresses F19)
R7: Decision rule in /toolkit for sweep vs prism (addresses F12)

### Most Likely Failure Mode

Context window exhaustion during synthesis — the orchestrator's own session holds 6,000-10,000+ tokens by Stage 5. Synthesis runs inline (not as subagent). Output appears complete but may contain confabulated references. Silent failure.
