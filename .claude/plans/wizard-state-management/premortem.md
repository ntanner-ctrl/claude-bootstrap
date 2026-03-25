# Pre-Mortem: wizard-state-management

## Premise

Two weeks after deployment. All 4 wizards persist state, display progression, attempt vault checkpoints. Feature merged after passing test.sh.

## Most Likely Single Cause of Failure

**Resume prompt becomes friction — users learn to always choose "Abandon."**

Context compaction mid-wizard leaves sessions in `active` state. Users get prompted "Resume or Abandon?" on every re-invocation. Resume produces subtly inferior output (thin output_summary context). Users learn that "Abandon" gives better results. After 2 weeks, wizard state management is functionally disabled.

This is the operational manifestation of F1 (output_summary quality). If F1 isn't addressed, the entire feature collapses.

## Contributing Factors

1. **No observability into resume quality** — No way to measure if resumed sessions produce comparable output. Degradation is silent.
2. **test.sh doesn't validate resume behavior** — Most important feature (resume quality) has zero automated validation.
3. **`.claude/wizards/` accumulates stale sessions** — 5-10 orphan sessions per project after 2 weeks. Inconsistent handling across wizards.
4. **output_summary content varies wildly** — Without content contracts, some summaries are detailed enough, others are one-liners. Unpredictable resume quality.

## Early Warning Signs Missed

1. No resume quality metric defined (structural correctness ≠ semantic correctness)
2. "500 tokens" claim never tested against real wizard runs
3. No user-facing documentation about what resume does or when to choose Abandon

## Retrospective Recommendations

1. **F1 is the load-bearing wall** — Content contracts must be implemented before other wizard state work
2. **Add resume freshness heuristic** — Auto-suggest Abandon for sessions older than 4h (short wizards) / 24h (prism)
3. **Cleanup decision (A2) must be made now** — Not deferrable
4. **Add minimal resume smoke test** — "If output_summary present for all completed steps, resume is viable"

## Findings

| ID | Finding | Severity | Status |
|----|---------|----------|--------|
| PM1 | Resume prompt becomes friction (users always Abandon) | critical | NEW |
| PM2 | No observability into resume quality | medium | NEW |
| PM3 | test.sh doesn't validate resume behavior | medium | NEW |
| PM4 | output_summary variance makes resume unpredictable | high | COVERED (F1/G1) |
| PM5 | Stale session accumulation | high | COVERED (A2/F4) |
| PM6 | No resume freshness heuristic | medium | NEW |
| PM7 | No user-facing resume documentation | low | NEW |

**Overlap:** 2/7 (0.29) — low overlap confirms pre-mortem found a genuinely different failure class (operational UX failures vs design/boundary failures).
