# Specification Revision History

## Revision 1 (initial)
- Created: 2026-02-07T18:30:00Z
- Sections: Summary, What Changes, Preservation Contract, Detailed Design (1-9), Success Criteria, Failure Modes, Rollback Plan, Open Questions, Work Units
- Work Units: 17 (W1-W17)
- Parallelization: Width 4, Critical path 5

## Revision 1 → Revision 2
- Trigger: Debate chain regression — Judge recommended REGRESS with 3 critical findings
- Date: 2026-02-07T19:15:00Z
- Source: adversarial.md (3 critical, 5 high, 7 medium, 5 low findings from 3-round debate)

### Sections Added
- **1.5** — Rename Validation [C3]: validation script + W2 acceptance criteria
- **2.5** — Debate Output Schema [H2]: JSON schema for Judge/Synthesizer output with vanilla fallback
- **3.2** — Pre-Mortem Scope Differentiation [M2]: operational vs design failure focus
- **4.4** — HALT State [C1]: max regression recovery with 3 escape hatches
- **5.2** — Session ID Storage [H1]: dual storage in state.json + manifest.json
- **6.3** — Manifest Write Failure Handling [H5]: staleness flag, backup, blocked progression
- **6.4** — Manifest Corruption Recovery [M4]: regeneration from source artifacts
- **6.6** — Staleness Detection [L2]: artifact timestamps in manifest
- **7.2** — Work Units Table Schema [L5]: required columns definition
- **7.4** — Checksum Validation [M3]: SHA-256 of Work Units section
- **7.5** — Staleness on Regression [H3]: work graph marked stale, blocks Stage 7
- **9** — Pre-v2 Migration [M7]: auto-detect, apply defaults, generate manifest
- What Changes → Scripts subsection: validate-rename.sh
- What Changes → Hooks: blueprint-stage-gate.sh [C2]

### Sections Modified
- **Summary** — Added: HALT recovery, corruption recovery, checksum validation, operational focus, hook enforcement
- **What Changes → Hooks** — Added blueprint-stage-gate.sh [C2]
- **What Changes → Storage** — Added debate-log.md
- **2.3 Debate Mode** — Added: timeout protection [M5], output format schema reference, canonical source of truth declaration [L4]
- **3.3 Pre-Mortem Process** — Added: operational focus framing [M2]
- **4.1 Regression Triggers** — Changed: confidence now advisory + trigger gated [L3], not standalone gate
- **4.3 Regression Behavior** — Added: preserved resolutions [L1], work graph staleness [H3]
- **5.1 Enforcement** — Rewritten: now hook-based enforcement [C2] instead of markdown-only
- **6.1 manifest.json Schema** — Added: execution_preference [H4], artifact_timestamps [L2], empirica_session_id description updated [H1], work_unit required fields added [L5]
- **7.1 work-graph.json** — Added: spec_work_units_checksum and generated_at fields
- **7.6 Parallelization Recommendation** — Added: execution_preference column [H4], triage capture UI
- **Success Criteria** — Expanded from 16 to 29 criteria
- **Failure Modes** — Expanded from 6 to 16 failure modes with mitigations
- **Rollback Plan** — Added: hook rollback, migration rollback
- **Open Questions** — Removed Q3 (max regressions, resolved as 3), removed Q4 (manifest versioning, resolved as regeneration). Added Q4 (hook strictness).
- **Work Units** — Added W14 (execution_preference), W17 (migration), W18-W20 (renumbered). Total: 17 → 20.

### Sections Removed
- None

### Sections Unchanged
- Preservation Contract
- Section 2.1 (Mode Selection)
- Section 2.2 (Vanilla Mode)
- Section 2.4 (Team Mode)
- Section 5.3 (Confidence Scores)
- Section 5.4 (Regression Threshold) — wording refined but semantics unchanged
- Section 5.5 (Empirica Vector Mapping)
- Section 6.2 (Manifest Enforcement Points)
- Section 6.5 (Token Budget Comparison)
- Section 8 (Spec Diff Tracking)

### Adversarial Findings Addressed
- All 20 findings from debate chain integrated
- 0 findings invalidated by revision
- User override: M1 (debate stays as default, not changed to vanilla)

### Work Units Affected
- W2: Added validation script requirement + acceptance criteria
- W4: Added output schema to scope
- W6: Added operational focus differentiation
- W7: Added HALT state to scope
- W8: Added corruption recovery + staleness handling
- W10: **New** — blueprint-stage-gate.sh hook
- W11: Added dual session_id storage
- W12: Added checksum validation
- W13: Added staleness tracking
- W14: **New** — execution_preference in triage
- W17: **New** — pre-v2 migration logic
- W18-W20: Renumbered from W15-W17
