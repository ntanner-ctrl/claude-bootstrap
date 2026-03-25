# Family Debate Log — wizard-state-management

## Round 1

### Child-Defend (Round 1)

**Defended positions:**

1. **Separate `.claude/wizards/` namespace** — Hard correctness boundary. `/blueprints` scans `.claude/plans/`; wizard sessions would appear as spurious blueprints. Separation reflects accurate conceptual model: blueprints are persistent planning, wizard state is ephemeral workflow scaffolding.

2. **No manifest.json for wizards** — Blueprint's manifest solves a problem that doesn't exist for wizards (3-8K tokens of multi-file artifacts). Wizard state is 200-500 tokens total. `output_summary` IS the compression mechanism, inlined rather than in a separate file.

3. **Dynamic step keys** — Four wizards have fundamentally different step shapes. Fixed-key schema would require prism's 10 steps everywhere. Array approach fragile on insert. Dynamic keys let each wizard define exactly its own steps while sharing display/resume logic.

4. **`output_summary` as inlined compression** — Solves the core problem: context compaction loses constraints that later steps depend on. Without it, resume requires re-running steps, re-reading artifacts, or cold restart. 100-300 tokens per step keeps total under 500.

5. **Single active session per wizard** — Wizards are contextually anchored. Two concurrent reviews would be incoherent. Forces explicit resume/abandon decision on re-invocation, important because compaction happens without user awareness.

6. **Vault checkpoints as advisory/fail-open** — Vault is external, may not be configured. Blocking on vault failure would kill 10-minute reviews mid-completion. Follows existing fail-open philosophy.

7. **Hook integration as stretch goal** — Intellectually honest. Stage gating for 4-step wizards (steps complete in seconds) has hook overhead and false-positive concerns. Core value (resume) doesn't depend on enforcement.

8. **TDD=false for all work units** — TDD doesn't apply to markdown authoring. Validation is test.sh's structural checks. W7 (test checks) before W2-W5 is actually test-first for this artifact type.

9. **`context` object as first-class field** — Resume needs two kinds of info: what happened (output_summary) and what was configured (context). For clarify, `selected_paths` determines conditional branching. Not derivable from output summaries.

10. **7-day archive cleanup** — Right window for reference needs. Immediate deletion loses useful context; permanent retention accumulates indefinitely. `_archive/` gives recovery path.

---

### Child-Assert (Round 1)

**Challenges:**

1. **State drift on partial-step interruption** [HIGH] — If compaction hits mid-step, `current_step` points to active step but `output_summary` is empty (written only at completion). For prism Wave 1 with 4/6 agents done, resume can't distinguish 10% from 90% done. Substep tracking helps but spec gives no guidance on partial-step resume.

2. **`output_summary` quality is unspecified** [HIGH] — The entire resume value proposition rests on summaries Claude writes. No guidance on mandatory info, validation, or sufficiency. For prism's serial context accumulation, a generic "3 concerns found" summary silently degrades the cross-stage constraint passing that makes prism valuable.

3. **`/review` step mapping doesn't match actual command** [HIGH] — Spec lists steps (vault_check, identify_target, devils_advocate, simplify, edge_cases, external_review, deep_analysis, compile) but actual command doesn't use those names for stages. Step names are invented, not derived from command text. Guaranteed implementation drift.

4. **No cleanup mechanism is actually implemented** [HIGH] — Spec promises 7-day auto-archive but no work unit, no hook, no scheduler. `.claude/wizards/` will accumulate stale sessions indefinitely. After 6 months, active-session detection via glob returns ambiguous results.

5. **Missing audit trail for completed sessions** [MEDIUM] — No "list prior wizard runs" capability. Vault checkpoints are the only audit trail, but vault is optional. User can't compare today's prism findings against last month's.

6. **Phantom hook feature with no work unit** [MEDIUM] — D6 describes hook design but W1-W8 don't include hook implementation. Creates dangerous half-done feature that future implementers might build against incomplete spec.

7. **Misleading compaction detection language** [MEDIUM] — Spec says wizard "detects compaction" but there's no API for this. Actual mechanism is re-invocation check. Language could mislead implementer into over-engineering.

---

### Mother — Synthesis (Round 1)

**Genuine Strengths (keep as-is):**
- Separate `.claude/wizards/` namespace — correct and non-negotiable
- No manifest for wizards — token math is right, inline summary is right
- Dynamic step keys — correct for multi-shape wizard support
- Single active session per wizard — correct model
- Fail-open vault checkpoints — consistent with toolkit philosophy
- Hook deferral as stretch goal — correctly scoped
- `context` / `output_summary` split — well-reasoned architecture

**Genuine Gaps (need work):**

1. **`output_summary` quality unspecified** — Per-wizard content requirements are load-bearing for resume. Defender is right that inline summaries are the right mechanism; challenger is right that unguided summaries will silently degrade serial context. Both can be true. Need: per-wizard output_summary templates or mandatory fields.

2. **`/review` step names invented, not derived** — Concrete mismatch between spec's step inventory and actual command stage names. Not a design dispute — a factual accuracy issue. Need: re-derive step names from each actual command file.

3. **Partial-step resume protocol absent** — Substep tracking correctly models parallel agents (defender right), but spec is silent on what to do when `current_step` has `status: active` with partial substeps (challenger right). Need: explicit protocol — "resume pending substeps only."

4. **Auto-archive described as implemented but has no WU** — 7-day logic is sound (defender right), but it's unimplemented (challenger right). Need: either add WU or acknowledge as deferred + make glob detection robust to stale sessions.

5. **D6 hook design in spec with no WU** — Correctly deferred (defender right), but described in spec-level detail without corresponding work unit (challenger right). Need: explicitly label as "design sketch, out of scope for this implementation."

6. **No always-on audit trail when vault absent** — Fail-open is correct (defender right), but vault-only persistence means no run history without vault (challenger right). Need: acknowledge trade-off explicitly.

---

### Father — Guide (Round 1)

**Confidence assessment: 70% ready.** Architecture sound, core decisions well-reasoned. Gaps are not fundamental — don't require rethinking the approach.

**What should change (8 items):**

1. **Add per-wizard `output_summary` content templates** — Most critical gap. Per-step mandatory fields. For prism wave1: issue count per paradigm, top 3 critical, pattern-level diagnosis. For clarify assess: which paths and why. Content contract, not implementation.

2. **Reconcile step names against actual command files** — Factual accuracy, not design. Audit all 4 wizards' actual stage names and derive step keys from them.

3. **Add partial-substep resume policy** — One sentence: "When substep status is `active` at resume, treat as `pending` (re-run it)." Simplest correct behavior.

4. **Either add W9 for cleanup OR remove archive promise** — Path (a): "on new-session creation, archive sessions older than N days" logic. Path (b): remove promise, document accumulation as acceptable, make glob detection robust with most-recent-wins. Current spec does neither.

5. **Rewrite D6 as explicit out-of-scope design sketch** — Remove "extend blueprint-stage-gate.sh" reference (hook may not exist). Two sentences: "Stage gate hook is future. When implemented, will use wizard-stage-gate.sh (not yet created)."

6. **Acknowledge vault-absent trade-off** — One sentence: "Without vault, run history available only via state.json files in `.claude/wizards/`."

7. **Clarify `_archive/` glob exclusion** — Active-session glob must exclude `_archive/` subdirectory. Minor but prevents 10-minute debugging session.

8. **Add trigger condition for prism findings-summary.json** — "If orchestrator context exceeds N tokens before synthesis, add findings-summary.json." Prevents open-ended implementation decision.

**What should stay:** All core architecture decisions confirmed sound.

**Unresolved tensions for Elder Council:**

1. Content contracts vs. over-specification — how much structure for output_summary?
2. Cleanup mechanism design — on-invocation age check vs. deferred
3. Monorepo target_path scoping — is "active" scoped to wizard-type or (wizard-type, target-path)?

---

### Elder Council — Historical Validation (Round 1)

**Vault findings: 8 relevant analogies found.**

| Vault Source | Lesson | Relevance |
|---|---|---|
| prism-serial-context-compression | output_summary must separate CONSTRAINTS from CONTEXT — inline compression is right mechanism | supports |
| prism-premortem-context-exhaustion | 500-token resume budget is optimistic for prism (10 steps × 300 = 3,000 tokens). Known compound failure. | warns |
| blueprint-lifecycle-gap | 50% of blueprints stale across 2 projects. Promised cleanup without implementation = 100% failure rate. | warns |
| enforcement-tier-honesty | Describing hook enforcement when no hook exists is a category error. D6 must be relabeled. | supports |
| behavioral-feedback-is-mechanism | Unstructured summaries = trivia that don't shape behavior. Content templates are the mechanism. | supports |
| premortem-catches-process-failures | Debate caught design gaps; pre-mortem will catch operational gaps (expected). | neutral |
| hybrid-tdd-parallel-dispatch | TDD=false for markdown is historically validated. test.sh structural checks are correct. | supports |
| family-debate-catches-critical-bugs | Debate process working as designed — 7 genuine gaps identified. | supports |

**Father's changes review:** 6/8 supported by vault, 1 novel (glob exclusion), 1 supported analytically (partial-substep resume).

**Additional caution:** Prism's resume budget math needs adjustment. 10 steps × 300 tokens = 3,000 tokens, exceeding the 500-token claim. Either use shorter summaries for early steps or acknowledge ~1,000 token budget for prism specifically.

**Elder Verdict:** CONVERGED
**Confidence:** 0.88
**Carry Forward:** null

---

## Stage 4: Edge Cases — Round 1

### Child-Defend (Edge Cases)

**10 defended boundary positions:**

1. **Fail-open on state.json write failure** — Wizard work is the deliverable, not the state file. Requiring atomic writes would import filesystem reliability as hard dependency.
2. **Corrupt state.json → abandon and start fresh** — Partial recovery from corrupt state would need checksums and transactional semantics. Not warranted for 200-500 token files.
3. **`_archive/` glob exclusion via naming convention** — `_archive/` doesn't match `<wizard>-*` glob prefix. Implicit boundary from naming.
4. **Single-active-session without file locking** — Claude Code runs single conversation thread. True parallel invocations are edge case. Last-write-wins + next-invocation prompt is sufficient.
5. **`context` with `additionalProperties: true`** — Extension point by design. Closed schema per wizard would need 4 separate schemas or `oneOf` discriminator. No benefit for resume.
6. **Vault checkpoint failure as advisory** — Tying wizard completion to external vault would make success depend on uncontrolled infrastructure.
7. **Substeps tracking for parallel agents** — `active` at resume implies re-run. Partial agent output without committed summary is unusable anyway.
8. **`version: 1` constant as migration marker** — Costs nothing, buys clean migration path for future schema changes.
9. **Auto-create `.claude/wizards/` directory** — Lazy creation at invocation is simpler and more resilient than requiring installer pre-creation.
10. **`abandoned` as explicit terminal state** — Distinguishes "user chose not to continue" from "errored" and "completed". Gates resumability logic.

---

### Child-Assert (Edge Cases)

**30 boundary conditions identified. Top 5 most critical:**

1. **No atomic write pattern** [HIGH] — Every step transition has corruption window. Disk-full mid-write produces corrupt file silently abandoned. Combined with #24 (disk full), most dangerous data loss scenario.
2. **Session ID collision at minute resolution** [HIGH] — `prism-20260324-2355` format guarantees collision for abandon+restart within same minute. Silent state.json overwrite.
3. **`_archive/` not excluded from glob** [HIGH] — F7 still unresolved. After first cleanup pass, "Resume or Abandon?" prompt fires for archived sessions permanently.
4. **No consistency validation at resume** [HIGH] — `current_step` pointing to `complete` step causes re-execution. All-steps-complete with top-level `active` creates permanent orphan.
5. **Resumability uses negative check** [HIGH] — `!= complete && != abandoned` instead of positive `== active`. Any novel status value (typo, future addition) passes through as "resumable."

**Additional notable boundaries:**
- `error` status: terminal or recoverable? Entirely unspecified (#14)
- Stale 90-day session prompts resume with irrelevant context (#20)
- Schema version bump mid-session unhandled (#21)
- Step status transitions have no legal graph (#9)
- Oversized output_summary has no enforcement (#6)

---

### Mother — Edge Case Synthesis (Round 1)

**30 challenger findings triaged into 3 buckets:**

**Genuine Gaps (will bite first-time implementer):**
- G1: output_summary quality unspecified → need per-wizard mandatory field list
- G2: Partial-substep resume absent → one sentence: treat active as pending
- G3: _archive/ glob exclusion implicit → one clarifying sentence
- G4: `error` status semantics undefined → when to set, whether terminal
- G5: `current_step` at completion undefined → set to null on completion

**Acceptable Risks (acknowledge, don't over-engineer):**
- A1: Session ID collision → add sub-minute precision note
- A2: No cleanup implementation → binary choice: add WU or withdraw promise
- A3: Negative resumability check → switch to positive `== "active"` check
- A4: 500-token budget wrong for prism → tiered budget claim
- A5: Stale session UX → show age in resume prompt

**Over-Engineering Temptations (decline):**
- O1-O5: Atomic writes, transition graphs, schema migration, size enforcement, monorepo scoping → all declined with rationale

---

### Father — Edge Case Guide (Round 1)

**Confidence: 75% boundary coverage, 85% spec readiness after changes.**

**G1-G5 all confirmed as genuine gaps needing spec changes.**

**A2 promoted:** Cleanup is misclassified as "acceptable" — binary decision required before implementation. Vault finding (blueprint-lifecycle-gap) gives 100% failure rate for unimplemented promises.

**O1-O5 all correctly declined.** O2 gets a middle-path one-liner about expected transitions. O5 gets a known-limitation sentence.

**4 missed boundaries identified:**
- M1: Version mismatch on read → treat as corrupt/start fresh
- M2: Cross-command discovery → wizard state not surfaced by other commands
- M3: `context` keys load-bearing at resume → document required keys per wizard
- M4: test.sh check is no-op without sessions → note scope limitation

**Unresolved tensions:**
- T1: Content contracts specificity level (categories, not format strings)
- T2: A2 is a product decision, not technical
- T3: M3 context keys vs schema openness — make failure mode explicit

---

### Elder Council — Edge Case Historical Validation (Round 1)

**8 vault sources consulted. All Father triage confirmed.**

Key validations:
- A2 promotion mandatory — blueprint-lifecycle-gap (50% stale, 100% failure)
- G1/F1 highest confidence — two independent findings confirm
- O1 decline validated — heartbeat-v2 different context, different answer
- No O1-O5 promotions warranted
- M3 more important than classified — extension of G1/F1, implement together

**Elder Verdict:** CONVERGED
**Confidence:** 0.91
**Carry Forward:** M3 is extension of G1/F1; prism budget needs concrete number (~1,000 tokens)
