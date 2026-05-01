# Adversarial Findings: Meta-Blueprint Coordination

## Family Round 1

### Synthesis (Mother)

The spec's architecture is sound. Plugin-enhancer seam, explicit linkage, JSONL format, bidirectional references, and root-level completion flag are all defensible. The children identified 4 blocking issues:

1. Schema violation (current_stage max:7 vs Stage 8)
2. Enforcement gap (debrief "not skippable" but no hook)
3. Commit signal friction (every-commit prompting trains reflexive dismissal)
4. Broken artifact reference (spec.md.revision-1.bak doesn't exist)

Plus clarification needs around circular detection, unlink behavior, and completed:true derivation.

### Analysis (Father)

Refined to 6 MUST-FIX + 3 NEW + 3 UNRESOLVED TENSIONS:

| # | Finding | Severity | Direction |
|---|---------|----------|-----------|
| F1 | `current_stage` max:7 schema violation | High | Raise to 8, note Stage 8 is terminal |
| F2 | Commit signal fires every commit, trains "no" | High | Session-flag opt-in, not universal polling |
| F3 | `spec.md.revision-1.bak` doesn't exist | High | Use spec.diff.md + regression_log |
| F4 | Circular detection is pairwise only | Medium | Ancestor traversal DFS |
| F5 | Unlink of complete should block, not warn | Medium | Block with --force escape |
| F6 | `completed:true` derivation rule unstated | Medium | Explicit invariant from debrief |
| F7 | Parent-complete link should block | Medium | Block link when parent completed |
| F8 | Bidirectional write failure → half-linked state | Medium | Detect + repair at resume |
| F9 | commits.jsonl needs dedup by hash | Low | Deduplicate on read |
| F10 | Plugin slot contention for commit-commands | Low | Verify single-occupancy assumption |

Unresolved tensions: jq dependency for enforcement, commit signal value proposition, completed blueprint immutability.

### Historical Review (Elder Council)

| Vault Source | Lesson | Relevance |
|---|---|---|
| `2026-03-20-blueprint-lifecycle-gap.md` | 50% of blueprints "done but not closed" across 2 projects | Supports — validates the core problem |
| `2026-03-25-enforcement-tier-honesty.md` | "Not skippable" in prose is tier 3, not enforceable | Warns — spec must be honest about enforcement tier |
| `2026-03-18-spec-deployment-gap.md` | New artifacts need explicit creation paths | Neutral — commits.jsonl relies on optional plugin |
| `2026-03-24-workflow-portfolio-analysis.md` | Source document for this design | Supports — spec faithful to original |
| `2026-02-08-plugin-enhancers-blueprint.md` | Registry is hand-maintained, will desync | Warns — adding slot inherits known fragility |
| `2026-03-22-prism-premortem-context-exhaustion.md` | Multi-step flows confabulate under context pressure | Warns — debrief at Stage 8 runs in heavy session |
| `2026-03-25-content-contracts-enable-agent-thoroughness.md` | Explicit derivation rules prevent inference errors | Supports — completed:true invariant is critical |
| `2026-03-20-family-debate-catches-critical-bugs.md` | Family mode catches what single perspective misses | Supports — validates this review process |

**Elder Verdict:** CONVERGED
**Confidence:** 0.82
**Carry Forward:** Three items for pre-mortem: (1) context exhaustion at Stage 8, (2) enforcement tier labeling honesty, (3) systematic grep for hardcoded "7" references

## Tension Resolutions

### A: jq Dependency → NO
Use regression-warning friction, not jq-dependent hook. Zero-dependency constraint holds. Debrief uses `"skippable": false` as schema signal + regression warning at Stage 7 completion. Honest about tier 2.5 enforcement.

### B: Commit Signal Value → YES, simplified
Session-flag opt-in (`SAIL_BLUEPRINT_ACTIVE=name`). Value is in debrief auto-population, not per-commit prompting. Manual fallback (ask for hashes) is sufficient baseline.

### C: Completed Immutability → NO --reopen
Problem is blueprints that never close, not ones that close too early. Supersession via new linked blueprint is the intended path for revisiting completed work.

## Edge Cases — Family Round 1

### Boundary Analysis Summary

11 boundaries found, 6 MUST ADDRESS, 4 SPEC NOTE, 1 ACCEPT.

| Finding | Severity | Verdict |
|---------|----------|---------|
| B1: Empty name → phantom key | HIGH | MUST ADDRESS — added validation |
| B2: Path traversal/spaces | HIGH | SPEC NOTE — implicit protection |
| B3: current_stage string vs integer | HIGH | MUST ADDRESS — corrects pre-existing drift |
| B4: Empty commits.jsonl | MEDIUM | SPEC NOTE — treat as missing |
| B5: Parent orphan in debrief | HIGH | MUST ADDRESS — added fallback behavior |
| B6: Concurrent links | MEDIUM | ACCEPT — single-session design |
| B7: SAIL_BLUEPRINT_ACTIVE ghost | HIGH | SPEC NOTE — added directory check |
| B8: Debrief on un-executed blueprint | HIGH | MUST ADDRESS — added execute prerequisite |
| B9: Session break Stage 7→8 | HIGH | MUST ADDRESS — added persistent breadcrumb |
| B10: DFS on corrupt ancestor | MEDIUM | SPEC NOTE — fail-open documented |
| B11: --show with no meta_units | MEDIUM | MUST ADDRESS — added empty display |

### Cross-Cutting: Schema Drift

Pre-existing drift between PLANNING-STORAGE.md schema and actual state.json files:
- `current_stage` is string in all live files, integer in schema
- Field naming: `completed_at` vs `completed` for timestamps
- Several fields present in live files but absent from schema

W2 must correct this as a sub-task. Debrief uses `current_stage: "debrief"` (string), not `8` (integer).

**Elder Verdict:** CONVERGED at 0.85 confidence.
**Carry Forward:** B3 (schema drift) is the highest-risk item for implementation — must be fixed before W1 starts.

## Complexity Review

[Pending — /overcomplicated will run after edge cases]
