# Adversarial Findings: toolkit-wiring-matrix

## Devil's Advocate (Stage 3)

### Assumptions Challenged

| # | Assumption | Challenge | Result |
|---|-----------|-----------|--------|
| 1 | All WUs are independent | blueprint.md, end.md touched by 3 and 2 WUs respectively | Fixed: added shared file coordination section |
| 2 | 1-5 lines per edit is always fine | Many suggestions could bloat commands into menus | Fixed: max suggestions rule (2 plugin + 1 toolkit per command) |
| 3 | "Active" Phase 2 label is clear | Implies runtime detection where only markdown refs exist | Fixed: use "Wired" for Phase 2, "Active" for Phase 1 |
| 4 | vault-query suggestion is always useful | Useless when vault isn't configured | Fixed: gate behind vault context display |
| 5 | Plugin mentions are safe | Claude might proactively invoke referenced plugins | Fixed: advisory language ("Also available, user-initiated") |
| 6 | Phase 2 activation is meaningful | Without runtime code, it's just a cross-reference | Fixed: terminology distinction clarifies scope |

### Gaps Found: 6
### Gaps Fixed in Spec: 6
### Gaps Remaining: 0

### Verdict: PASS_WITH_NOTES — all gaps addressed in spec revision

## Edge Cases (Stage 4)

### Edge Cases Identified

| # | Edge Case | Risk | Fixed? |
|---|-----------|------|--------|
| E1 | Plugin removed after reference added — inert conditional text | Low | No fix needed — "if detected" gates handle this |
| E2 | Uncapped toolkit command cross-refs could accumulate | Low | Fixed: added constraint limiting to direct-next-step suggestions |
| E3 | Template name length in process-doc table cells | Low | Acceptable — use short form during implementation |
| E4 | Dual lens table (delegate + dispatch) maintenance burden | Med | Fixed: added sync comment requirement to spec |

### Verdict: Well-bounded — 4 edge cases, 2 fixed, 2 acceptable risk
