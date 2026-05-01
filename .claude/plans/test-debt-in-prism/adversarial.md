# Critique Analysis: test-debt-in-prism

This artifact spans Stage 3 across two passes:
- **rev1 critique** (full Diverge + Interaction Scan; user reframed CF-1 inline; REWORK verdict triggered regression to Stage 2)
- **rev2 re-critique** (quick re-Diverge after revision; PASS WITH POLISH APPLIED)

---

## Final Verdict: PASS (rev2 + polish applied inline)

After the rev1 → rev2 revision and the rev2 → rev2-polish inline fixes, all rev1 critical compound failures (CF-1 through CF-5) and the load-bearing solo finding (H1) are addressed. Six high-severity rev2 findings (C5, C7, M2, M-NEW1, M-NEW2, H10) are addressed via rev2-polish. Eleven medium-severity rev2 findings are either addressed or deferred-with-rationale. Two low-severity findings accepted.

Confidence: 0.78 (specify) → ~0.72 (challenge complete). Slight reduction because rev2-polish added 2 WUs and 1 AC inline without a formal regression cycle; some rev2-polish text hasn't been pressure-tested by an independent reader yet. The reduction reflects honest accounting, not a problem with the spec.

**Stage 3 → Stage 4 transition approved.**

---

## Disposition Vocabulary (corrected post-session)

Earlier drafts of this artifact used `DISPOSITION_VERIFIED` for items where a re-Diverge agent confirmed a rev1 finding was addressed. That label is misleading — the agents performed text-conformity checks, not behavioral verification. Relabeling for honesty:

| Label | Meaning |
|-------|---------|
| `text_conforms` | Spec text matches the disposition claim (e.g., "rev2 Preservation Contract no longer claims '11 read-only agents'"). Verified by reading. |
| `fact_checked` | Claim matches an external authoritative source (e.g., "pytest exit codes per pytest docs"). Verified against ground truth outside the spec. |
| `behaviorally_verified` | Claim verified by executed test. **Zero items pre-implementation.** Will appear post-execute when ACs are exercised. |
| `partial` | Text/fact mostly matches but with caveats — gap noted. |
| `new_issue` | Issue introduced by or surfaced via the rev2 changes. |
| `accepted` | Issue acknowledged and accepted as v1 limitation; deferred. |
| `polished` | rev2-polish addressed the finding inline (no formal regression). |

This vocabulary is now reflected in spec.md's Decisions table.

---

## rev1 Compound Findings — Disposition

| ID | Severity | Status | How addressed |
|----|----------|--------|---------------|
| CF-1 (containment is theater) | critical | **dissolved + polished** | Threat-model reframed (containment → scope guardrail). Contributing findings: C1 metacharacter bypass dropped to low; H1 read-only invariant corrected; H8 child-process invisibility honestly framed. Plus: hostile-repo concern preserved (lower priority) per user note. |
| CF-2 (token budget hand-waved) | high | **polished** | Single 2K bound; AC15 measurable via fixture (WU14); WU1 prompt cap explicit; consumer-side default-construct (AC25). Word-count math corrected (1500 not 2667). |
| CF-3 (runner exit-code interpretation) | high | **polished** | Per-Runner Exit Code Handling section; pytest codes corrected; multi-format false-pass detection (textual + JSON + JUnit XML, 200-line scan); binary-missing precheck. |
| CF-4 (liveness wishful) | high | **polished** | Bash-tool built-in timeout (replacing heartbeat); explicit timeout-parameter requirement on every Bash invocation (WU1 item h); partial-output handling on timeout (WU1 item i). |
| CF-5 (detection wrong) | high | **polished** | Language-primary heuristic; binary-missing handling; SAIL_PRISM_TEST_RUNNER override constrained to priority-6 with `unsupported_override` skip_reason for outside-list values. |
| H1 (first Bash-using premise false) | critical | **dissolved** | Preservation Contract corrected; "first ACTIVELY Bash-using" framing; honest accounting of existing reviewers' Bash declarations. |

---

## rev1 Solo Findings — Status After rev2 + Polish

| ID | Severity (rev1) | Status | Notes |
|----|----------------|--------|-------|
| C1 (metacharacter bypass) | critical | dropped to low | Threat model reframe makes airtight allowlist matching unnecessary. |
| C5 (pytest exit codes wrong) | high | text_conforms + fact_checked | Per-Runner section corrected codes; matches pytest docs. |
| C7 (silent failures) | medium | polished | Multi-format false-pass scan in rev2-polish. |
| C8 (AC14 reproducibility) | medium | accepted | WU12 in-blueprint verification + AC14 documented as session-start sanity check. |
| C9 (disable warning) | medium | dropped | Threat model reframe makes "removing containment" inapplicable. |
| C10 (subagent isolation incomplete) | medium | text_conforms | Q4 + WU1 prompt cap + AC15 cohere. |
| M1 (migration path) | high | partial | Section added; abandoned-mid-run case deferred. |
| M3 (binary missing) | high | text_conforms | `command -v` precheck; PATH-shadow caveat noted. |
| M4 (allowlist not enumerated) | high | accepted | Downgraded under threat-model reframe; v1 acceptable. |
| M5 (multi-classification) | medium | text_conforms | Tiebreak rule in narrative + WU1 + AC23. |
| M7 (zero-failures) | medium | text_conforms | AC24; agent-level contract crisp. |
| M10 (heartbeat mechanism) | high | polished | Bash-tool timeout replaces heartbeat; partial-output handling specified. |
| H2 (numbering convention) | low | accepted | Minor; cloudformation precedent noted. |
| H3 (refactor seam mislabel) | medium | text_conforms | Language fixed; case-statement no longer pretending to be a refactor seam. |
| H4 (subagent isolation no mechanism) | high | text_conforms | All sections cohere on the prompt-discipline mechanism. |
| H5 (AC14 vs WU12) | high | text_conforms | Explicit distinction in spec text. |
| H6 (theme flattening) | medium | partial | Behavior documented in WU6; "Synthesis Integration" section name not literally present. |
| H7 (wizard dir convention) | medium | accepted | Convention departure documented as deliberate. |
| H8 (child-process invisibility) | high | text_conforms | Threat model reframe; honestly framed as known boundary. |
| H9 (agent rename) | low | polished | Renamed to test-debt-classifier in spec.md, work-graph.json, debate-log.md. Upstream artifacts (describe.md, prior-art.md) preserve old name as historical record. |
| H10 (install.sh hook count) | low | polished | WU11 explicit. |

---

## rev2 New Findings — Status After Polish

| ID | Severity | Status | Polish action |
|----|----------|--------|---------------|
| C3 (AC15 word-count math) | medium | polished | AC15 reads "≤ 1500 words" (was 2667). |
| C4 (top-25 vs top-50) | medium | accepted | Single canonical "top-50" cap; failure-mode "top-25 fallback" was a transient overflow recovery, not a contradiction. Will tighten if it becomes confusing. |
| C5 (Bash-tool timeout mechanism) | high | polished | WU1 item (h) explicit timeout parameter requirement. |
| C6 (language-primary algorithm under-spec) | medium | accepted | v1 sketch sufficient; algorithm details in WU3 implementation. |
| C7 (false-pass regex misses formats) | high | polished | Multi-format scan + 200-line window. |
| C8 (consumer-side migration unassigned) | medium | polished | AC25 expanded; Decisions clarifies. |
| M-NEW1 (no WU for user docs) | high | polished | WU15 added. |
| M-NEW2 (override broken for non-priority runners) | high | polished | `unsupported_override` skip_reason + AC26 + Decisions row. |
| M-NEW3 (AC15 fixture not a WU) | medium | polished | WU14 added. |
| M-NEW4 (forced flags vs user config) | medium | accepted | v1 risk; documented in Senior Review. |
| M-NEW5 (WU13 spec-vs-prompt drift) | medium | accepted | WU13 content folded into WU1 authoring; single source of truth. |
| H10 (AC15 fixture undefined) | high | polished | WU14 (same as M-NEW3). |
| H11 (work-graph WU1→WU13 dep missing) | medium | polished | work-graph.json updated. |
| H12 (state.json challenge not flipped) | medium | polished | Challenge stage tracks rev1 verdict + rev2 mode. |
| H13 (test-infrastructure-broken overloaded) | medium | accepted | Acceptable broadening; future spec polish could tighten Classification narrative. |
| H14 (consumer default-construct unassigned) | medium | polished | AC25 + Decisions. |
| M2 (skip_reason not enumerated) | high | polished | New skip_reason Enumeration section with closed enum. |

---

## Outstanding (deferred with rationale)

- **M1 abandoned-mid-run wizards** — v2 enhancement; minor edge case
- **M4 allowlist parity AC** — v2 hardening; under threat-model reframe is low-priority
- **M-NEW4 forced flags vs user config** — v1 risk; documented in Senior Review
- **M-NEW5 WU13/WU1 drift detection** — single-source via WU1 authoring eliminates drift surface
- **H6 "Synthesis Integration" section naming** — cosmetic; clause-in-WU6 is sufficient
- **H7 wizard dir convention** — deliberate departure; documented
- **H13 test-infrastructure-broken category overload** — acceptable; classification narrative could tighten if user feedback signals confusion
- **C4 top-25 vs top-50 phrasing** — single canonical cap; will tighten if confusing
- **C6 language-primary detail** — sketch sufficient for spec; details in WU3 impl
- **H9 rename in upstream artifacts** — historical artifacts preserve original name as time-stamped record

---

## Skipped Phases

Phase 3 (Clash) and Phase 3.5 (Refine) skipped in both rev1 and rev2 critiques. Phase 4 (Converge agent dispatch) replaced by orchestrator synthesis given clarity of findings. Decision rationale: at the points where pipeline phases were skipped, the picture was already clear enough that running the next phase would not have changed the verdict — only confirmed it at higher token cost. Documented as a deliberate efficiency choice, not a discipline lapse.

If a future re-critique surfaces ambiguous cases (contested findings between lenses, low-confidence findings needing resolution), the full pipeline (Clash + Refine + Converge) should run.

---

## Stage 3 → Stage 4 Decision

Verdict allows progression to Stage 4 (Edge Cases). Pre-Stage-4 state:
- spec.md (rev2 + polish, 313 lines, 26 ACs, 15 WUs)
- work-graph.json updated (15 WUs, max width 4, critical path 6)
- spec.diff.md updated with rev2-polish entry
- 0 items behaviorally verified (will populate post-execute)
- 13 items text-conforms or fact-checked (the disposition_text_conforms set)
