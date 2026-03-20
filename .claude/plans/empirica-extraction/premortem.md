# Pre-Mortem: Native Epistemic Tracking

## Premise

This plan was implemented and deployed two weeks ago. It failed. This is the post-mortem.

## Most Likely Cause of Failure

**The `/end` command was never effectively updated.** The spec treats "update `/end`"
(work unit 5c) and "deprecate Empirica" (work unit 8) as independent tasks. In reality,
`/end` currently calls Empirica MCP tools that no longer exist after deprecation. The
new `/epistemic-postflight` call was added to `/end`, but `/end` errors on the now-missing
Empirica calls before reaching the new code. The PRIMARY pairing mechanism never fires.

Pairing rate: 0%. Calibration never activates. Nobody notices for two weeks because
"insufficient data" is indistinguishable from "system is broken."

## Contributing Factors

### A. No pairing rate health check (NEW)
The system says "insufficient data" identically whether warming up or broken. After
10+ unpaired sessions, there should be escalation: "WARNING: 0 of N sessions paired."

### B. settings.json manual merge gap (PARTIALLY COVERED)
`install.sh` copies files but doesn't modify user's `settings.json`. During a transition
that removes old hooks AND adds new ones, the merge gap means neither fires.

### C. No rollback path (NEW)
The deprecation section is one-way. No procedure to re-enable Empirica if the new
system fails.

## Early Warning Signs Missed

1. The transition is a multi-step atomic operation treated as independent tasks
2. No smoke test after deployment
3. The `settings.json` merge gap was treated as normal rather than transition-critical

## Retrospective Recommendations

1. **Deployment checklist** — ordered procedure, not just file inventory
2. **Pairing rate health check** — escalate after 10+ unpaired sessions
3. **Smoke test script** — `scripts/epistemic-smoke-test.sh`
4. **`/end` transition specification** — explicit ordering of Empirica removal + new integration
5. **Rollback documentation** — 2-minute procedure to re-enable Empirica

## Finding Classification

| Finding | Status | Severity |
|---------|--------|----------|
| `/end` transition ordering | NEW | Critical |
| Pairing rate health check | NEW | High |
| Smoke test script | NEW | Medium |
| Rollback procedure | NEW | Medium |
| settings.json merge gap | PARTIALLY COVERED | Medium |
