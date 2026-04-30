# Pre-Mortem: Anti-Pattern Catalog

**Premise:** This was implemented and shipped two weeks ago. It failed. Writing the post-mortem now.

Operational focus only — design failures already covered in Stages 3-4.

## Most Likely Single Cause of Failure

**Silent decay: nobody noticed the sweep stopped working.** The sweep has fail-open semantics
at every layer. If it breaks (jq path change, regex syntax error in a new pattern, vault path
change with spaces, etc.), `/end` exits cleanly and the user sees no signal that bookkeeping
has frozen. Three weeks later: counters haven't moved. Two months later: someone notices
`recent_hits` looks suspiciously stale on every pattern. Investigation reveals the sweep
hasn't run successfully since week 1.

## Contributing Factors

| Factor | What it does | NEW or COVERED |
|--------|--------------|----------------|
| Sweep failures emit only stderr (no persistent error log) | Failures invisible after the terminal scrolls | NEW |
| `/end` doesn't surface "anti-pattern sweep ran successfully" — only failures (and even those silently in fail-open mode) | No positive signal that bookkeeping is alive | NEW |
| `last_seen` field updates even when the sweep finds zero detections — looks healthy even if regex broke | Heartbeat is conflated with data freshness | NEW |
| No metric for "time since last successful sweep" | Decay is unobservable | NEW |
| Hookify-style "Catalog: X" warnings get muscle-memory dismissed after a few weeks | First-consumer becomes noise | COVERED (Risk row: "warn-action might be too noisy") |

## Early Warning Signs Missed During Planning

- The fail-open discipline in claude-sail is well-established for **destructive** operations
  (better silent than wrong write). But anti-pattern bookkeeping is **observability**, where
  silent failure is a different category of bug — **silent observability is broken
  observability.** The spec inherited fail-open without questioning whether it fit the use case.
- The spec doesn't include any "is the sweep actually working?" check. Every other layer of
  the system (postflight, manifest write, vault export) has at least a print-on-success message.
  The sweep doesn't.

## Incident Retrospective Recommendations (NEW Findings)

Three operational changes that the spec should pre-empt:

### F-PM-1 (NEW, medium) — Add a sweep heartbeat

The sweep should write a `.last-sweep.json` file in the catalog directory after each successful
run, containing `{ "timestamp", "patterns_scanned", "events_appended", "duration_ms" }`. A
simple `cat .claude/anti-patterns/.last-sweep.json` answers "is the sweep working?" The catalog
SCHEMA.md should document this file.

**Spec update needed:** add to sweep algorithm step 8.

### F-PM-2 (NEW, medium) — Stale-sweep nudge in `/end`

When `/end` runs and detects `.last-sweep.json` is missing OR `>7 days old`, surface a one-line
nudge: `[anti-pattern catalog] last successful sweep: N days ago. Run anti-pattern-sweep.sh
manually to investigate.` This is the heartbeat consumer. Without a consumer, the heartbeat
is theater.

**Spec update needed:** /end integration block gains a heartbeat check before invoking the
sweep.

### F-PM-3 (NEW, low) — Sweep summary on success

Currently the sweep prints "Anti-pattern sweep complete: scanned N files across M patterns.
K new detections recorded." But that goes to stderr inside a `2>&1 | tail -10` invocation —
visible during `/end` but not durable. Combined with F-PM-1's heartbeat, this becomes durable.
With F-PM-2's nudge, it becomes observable. The triplet (heartbeat + nudge + summary) is what
"is bookkeeping alive?" looks like.

**No spec update beyond F-PM-1 and F-PM-2.**

## Overlap Detection

Comparing pre-mortem findings to adversarial.md (Stages 3-4):

- F-PM-1 (sweep heartbeat): no analogue in adversarial (operational concern, not design)
- F-PM-2 (stale-sweep nudge): no analogue
- F-PM-3 (durable summary): no analogue

Overlap: 0/3 = 0%. Pre-mortem earned its keep — three NEW findings that design review didn't surface.

## Should this trigger regression?

These are NEW findings but none are critical-severity. They're medium/low operational
improvements. **Recommendation: fold into spec inline (no regression), update WU3 and WU4 to
include heartbeat + nudge.**

## Spec Updates from Pre-Mortem

Will be applied directly to spec.md:

1. **Sweep algorithm step 8 (new):** Write `.last-sweep.json` heartbeat after successful run.
2. **/end integration block:** Pre-sweep heartbeat check; if stale, surface nudge.
3. **WU3 acceptance criteria:** Heartbeat file written, contains expected fields.
4. **WU4 acceptance criteria:** Stale-sweep nudge fires when expected.
5. **AC additions:** AC11 (heartbeat exists after sweep), AC12 (nudge fires on stale).
