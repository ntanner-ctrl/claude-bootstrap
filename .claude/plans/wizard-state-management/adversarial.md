# Adversarial Findings — wizard-state-management

## Family Round 1

### Synthesis (Mother)

**Genuine Strengths:**
- `.claude/wizards/` namespace separation — correct, non-negotiable
- No manifest for wizards — token math correct, inline summary is right
- Dynamic step keys — correct for multi-shape wizard support
- Single active session — correct contextual model
- Fail-open vault checkpoints — consistent with toolkit philosophy
- `context` / `output_summary` architectural split — well-reasoned

### Analysis (Father)

**Spec readiness: 70%.** Architecture sound, gaps are refinement not rethink.

**8 Required Changes (ordered by priority):**

| # | Change | Severity | Direction |
|---|--------|----------|-----------|
| F1 | Add per-wizard `output_summary` content templates | critical | Mandatory fields per step. Prism wave1: issue count per paradigm, top 3 critical, pattern diagnosis. Clarify assess: paths selected and why. Content contract, not implementation. |
| F2 | Reconcile step names against actual command files | high | Audit all 4 wizards' actual stage names. Derive step keys from commands, not invent them during spec writing. |
| F3 | Add partial-substep resume policy | medium | One sentence: "When substep status is `active` at resume, treat as `pending` (re-run)." |
| F4 | Add W9 for cleanup OR remove archive promise | high | Prefer path (a): on-invocation age check. Alternative: remove promise, make glob robust with most-recent-wins. |
| F5 | Rewrite D6 as out-of-scope design sketch | medium | Remove "extend blueprint-stage-gate.sh" reference. Two sentences: future enhancement, not yet created. |
| F6 | Acknowledge vault-absent trade-off | low | One sentence: "Without vault, run history via state.json files in `.claude/wizards/`." |
| F7 | Clarify `_archive/` glob exclusion | low | Active-session glob must exclude `_archive/` subdirectory. |
| F8 | Add trigger condition for prism findings-summary.json | medium | "If orchestrator context exceeds N tokens before synthesis, add findings-summary.json." |

### Historical Review (Elder Council)

| Vault Source | Lesson | Relevance |
|---|---|---|
| prism-serial-context-compression | output_summary must separate CONSTRAINTS from CONTEXT | supports F1 |
| prism-premortem-context-exhaustion | 500-token budget is optimistic for prism (10 × 300 = 3,000) | warns — needs budget adjustment |
| blueprint-lifecycle-gap | 50% stale rate across 2 projects; unimplemented cleanup = 100% failure | supports F4 |
| enforcement-tier-honesty | Hook enforcement described without implementation = category error | supports F5 |
| behavioral-feedback-is-mechanism | Unstructured summaries = trivia; content templates are the mechanism | supports F1 |

**Additional finding from vault analysis:**
- F9: **Prism resume token budget needs adjustment** [medium] — 500-token claim doesn't hold for 10-step prism. Either use tiered summary lengths (shorter for early steps) or acknowledge ~1,000 token budget for prism specifically.

**Elder Verdict:** CONVERGED
**Confidence:** 0.88

## Complexity Review

*Pending — will run /overcomplicated after edge cases stage completes.*

---

## Edge Cases — Family Round 1

### Boundary Analysis Summary

30 boundaries identified → triaged to 5 genuine gaps + 5 acceptable risks + 20 declined/noise.

### Genuine Gaps (Spec Changes Required)

| # | Boundary | Category | Direction |
|---|----------|----------|-----------|
| G1 | `output_summary` quality unspecified | Input | Add per-wizard Content Contracts section (3-5 mandatory fields per step). Also document required `context` keys per wizard (M3 extension). |
| G2 | Partial-substep resume absent | State | One sentence: "Substep with `status: active` at resume → treat as `pending` (re-run)." |
| G3 | `_archive/` glob exclusion implicit | Resource | One sentence clarifying the naming convention provides exclusion. |
| G4 | `error` status semantics undefined | State | Define: semi-terminal, show error-specific prompt on resume, don't auto-re-run failed step. Switch resumability to positive `== active` check. |
| G5 | `current_step` at completion undefined | State | Set `current_step: null` on completion. |

### Acceptable Risks (Acknowledge in Spec)

| # | Boundary | Direction |
|---|----------|-----------|
| A1 | Session ID collision (minute resolution) | Update examples to HHMMSS format |
| A2 | No cleanup implementation **[PROMOTED]** | Binary decision required: add W9 or withdraw promise. Vault finding: 100% failure for unimplemented cleanup. |
| A3 | Negative resumability check | Switch to `status == "active"` positive check |
| A4 | 500-token budget wrong for prism | Replace with: ~500 tokens short wizards, ~1,000 tokens prism |
| A5 | Stale session UX | Display session age in resume prompt |

### Missed Boundaries (Father)

| # | Boundary | Direction |
|---|----------|-----------|
| M1 | Version mismatch on read | Treat as corrupt / start fresh |
| M3 | `context` keys load-bearing at resume | Document required keys per wizard (extension of G1) |

### Declined (Over-Engineering)

O1 (atomic writes), O2 (transition graphs), O3 (schema migration), O4 (size enforcement), O5 (monorepo scoping) — all correctly declined, O1 validated by vault finding (heartbeat-v2).

### Historical Review (Elder Council)

| Vault Source | Lesson | Supports |
|---|---|---|
| blueprint-lifecycle-gap | 50% stale rate, 100% failure for unimplemented promises | A2 promotion |
| prism-serial-context-compression | Unstructured summaries fail to transmit constraints | G1/F1 |
| prism-premortem-context-exhaustion | Context accumulates ~300 tokens/stage, 10×300=3000 | A4 budget fix |
| enforcement-tier-honesty | Undefined semantics for status values → inconsistent behavior | G4 |
| heartbeat-v2 F5 | Atomic writes warranted for cross-process, not self-recovery | O1 decline |

**Elder Verdict:** CONVERGED
**Confidence:** 0.91

---

## Pre-Mortem (Stage 4.5) — Operational Failures

**Overlap with prior stages:** 2/7 (low — different failure class)

| ID | Finding | Severity | Status |
|----|---------|----------|--------|
| PM1 | Resume prompt becomes friction — users always choose Abandon because resume quality is inferior to fresh run | critical | NEW [pre-mortem] |
| PM2 | No observability into resume quality — degradation is silent | medium | NEW [pre-mortem] |
| PM3 | test.sh doesn't validate resume behavior — most important feature untested | medium | NEW [pre-mortem] |
| PM6 | No resume freshness heuristic — stale sessions prompt equally with fresh ones | medium | NEW [pre-mortem] |
| PM7 | No user-facing resume documentation | low | NEW [pre-mortem] |

**Key insight:** PM1 is the operational expression of F1 (output_summary quality). If F1 is fixed, PM1 is largely mitigated. F1 is now confirmed as critical from THREE independent angles: Challenge (design), Edge Cases (boundary), Pre-Mortem (operations).

## Complexity Review

*Pending — will run /overcomplicated after pre-mortem completes.*
