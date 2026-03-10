# Describe: Toolkit Hardening

## What's Changing

Six new capabilities for the claude-bootstrap toolkit:

1. **Compaction Guardian** — Cross-hook communication (statusline → PreToolUse) that gates tool calls when context window approaches auto-compaction threshold, forcing checkpoint + subagent lifeboat
2. **Ambiguity Gate** — Scored readiness check between blueprint describe→specify stages, front-loading clarity before spec generation
3. **Cognitive Trap Tables** — Markdown tables on MUST-tier commands listing known rationalizations with counters, preempting skip behavior
4. **Failure Counter Escalation** — PostToolUse hook tracking consecutive test/build failures with Yellow/Orange/Red escalation thresholds
5. **Wonder/Reflect Phase** — Post-implementation learning capture in blueprint workflow, feeding findings to Empirica and vault
6. **Knowledge Maturation Cycle** — `/promote-finding` command managing finding lifecycle from isolated observation to CLAUDE.md rule, with mandatory capacity checking and paired pruning

## Sources

- Components 2, 5: Ouroboros (github.com/Q00/ouroboros)
- Components 3, 4: GodMode (github.com/NoobyGains/godmode)
- Component 1: Operational pain point (Empirica data loss on compaction)
- Component 6: User vision for Empirica↔Obsidian lifecycle

## Triage

- **Path:** Full
- **Risk:** Medium (hook infrastructure changes affect all sessions)
- **Files:** ~15 across all components
- **Overlaps:** 4 identified (checkpoint enrichment, behavioral correction, blueprint stages, Empirica data flow)

## Implementation Phases

```
Phase A: 1-Compaction Guardian + 3-Cognitive Traps    [parallel]
Phase B: 2-Ambiguity Gate + 5-Wonder/Reflect          [serial]
Phase C: 4-Failure Counter                            [independent]
Phase D: 6-Knowledge Maturation                       [depends on A+B]
```

Critical path: 1 → (2+5) → 6
