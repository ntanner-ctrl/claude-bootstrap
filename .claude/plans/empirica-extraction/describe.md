# Describe: Empirica Extraction — Native Epistemic Tracking

## Change Summary

Replace the Empirica MCP server with a native claude-sail epistemic tracking system.
Store vectors in `~/.claude/calibration.json` + Obsidian note frontmatter. Compute
rolling-average calibration with behavioral feedback (not just numbers). Wire into
existing claude-sail hook infrastructure.

## Discrete Steps

1. Design JSON schema for `~/.claude/calibration.json`
2. Create calibration computation module (shell script, rolling averages, ±0.25 cap)
3a. Define behavioral feedback template format (delta → instruction mapping)
3b. Create feedback generation logic (reads history + context, produces instructions)
4. Create SessionStart hook (preflight vectors → JSON + Obsidian)
5. Create SessionEnd hook (postflight vectors, deltas, rolling averages, feedback)
6. Update CLAUDE.md instructions (replace Empirica sections)
7. Migrate existing paired session data (27 sessions from Empirica SQLite → JSON)
8. Deprecate Empirica MCP (document removal, update guidance)
9. Update test.sh (new file checks, schema validation)
10. Update install.sh (include new hooks/scripts in distribution)

## Risk Flags

- **User-facing behavior change**: The feedback format directly affects Claude's
  session behavior. The "user" is Claude itself, making the feedback design critical.

## Dependencies

```
Schema (1) ──→ Computation (2) ──→ Feedback Templates (3a)
                                        │
                                        ▼
                                   Feedback Logic (3b)
                                        │
                              ┌─────────┼─────────┐
                              ▼         ▼         ▼
                         Hook Start  Hook End  Migration
                            (4)       (5)       (7)
                              │         │
                              └────┬────┘
                                   ▼
                         ┌─────────┼─────────┬──────────┐
                         ▼         ▼         ▼          ▼
                     CLAUDE.md  Deprecate  test.sh  install.sh
                       (6)       (8)       (9)       (10)
```

## Triage

- **Path:** Full
- **Execution preference:** Auto
- **Step count:** 11
- **Risk flags:** 1 (user-facing behavior change)

## Key Design Decisions (from conversation)

1. **Rolling averages over Bayesian** — at current data volumes (~2 observations/vector),
   Bayesian and rolling averages produce near-identical results. Data model designed to
   support Bayesian upgrade at ~15-20 observations/vector.
2. **Behavioral feedback, not just numbers** — "you overestimate know by 0.12" is trivia.
   "When you overestimate know, you skip reading test files" is actionable.
3. **Context-sensitive calibration** — aggregate accuracy must not create false confidence
   in novel situations. Historical calibration may not transfer to unfamiliar domains.
4. **Keep all 13 vectors** — Empirica author has deeper epistemology knowledge; understand
   before pruning.
5. **Obsidian as human-readable layer** — vectors in note frontmatter, JSON for machine
   consumption. Dual-write pattern.
6. **No Python dependency** — claude-sail is bash-only. Use jq/awk for computation.
