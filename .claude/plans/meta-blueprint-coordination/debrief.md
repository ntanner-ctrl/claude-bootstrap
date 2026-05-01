# Debrief: meta-blueprint-coordination

## Ship Reference
- Commit(s): pending (pre-commit — all work in working tree)
- Date: 2026-03-25

## Spec Delta
No regressions occurred — spec stable through implementation.
- Rev 1 → 1.1: 10 challenge amendments (schema fix, commit signal redesign, enforcement honesty, etc.)
- Rev 1.1 → 1.2: 11 edge case amendments (input validation, session recovery, debrief prerequisites, etc.)
- 4 pre-mortem amendments (context-aware mode, prompt separation, half-linked repair, stage count grep)
- All amendments were additive — no architectural changes required

## Deferred Items
- Sibling impact push-notification: passive record-only for v1. Future: manifest read at sibling blueprint resume.
- Shell hook enforcement for debrief: jq dependency blocks; tier 2.5 behavioral enforcement is honest alternative.
- Concurrent link safety: single-session design absorbs this; documented as known limitation.
- Context-budget auto-detection: manual threshold (>5 stages) for now.

## Discoveries
- **B3 schema drift (critical):** `current_stage` has always been stored as a string in all live state.json files, despite PLANNING-STORAGE.md documenting it as integer with max:7. This pre-existing drift would have silently broken the debrief transition if not caught by edge case analysis. W2 corrected the documentation.
- **Enforcement tier honesty:** The vault finding `enforcement-tier-honesty.md` directly challenged the spec's "not skippable" language. Resolution: tier 2.5 enforcement with `skippable: false` schema signal + regression-warning prompt. Honest about what the toolkit can enforce.
- **Commit signal UX:** Original "prompt every commit" design would train users to dismiss reflexively. Session-flag opt-in (`SAIL_BLUEPRINT_ACTIVE`) eliminates prompt fatigue while preserving automation path.
- **Debrief has universal value:** The "blueprints just end" problem is solved for ALL blueprints, not just meta-coordinated ones. Debrief is the structural fix for the lifecycle gap that affected 50% of blueprints.

## Reflection
### Wrong Assumptions
- Assumed `current_stage` was integer (per docs) — it's always been a string
- Assumed `/commit` was a sail command — it's from the commit-commands plugin
- Original commit signal design (universal polling) would have been counterproductive

### Difficulty Calibration
- Harder: The stage count grep across the codebase was more pervasive than expected (7 files needed updating beyond the primary targets)
- Easier: The actual W1-W6 implementation was straightforward once the spec was solid. Family debate front-loaded the complexity.

### Advice for Next Planner
- Vault findings are invaluable during Elder Council — invest in vault data
- The family debate format (defend/assert/synthesize/guide/elder) is excellent for specs that modify existing complex systems
- Pre-mortem caught genuinely different failure modes (operational UX) from what challenge/edge-cases found (design/boundary)
- Always grep for hardcoded references to counts/numbers being changed — they hide everywhere
