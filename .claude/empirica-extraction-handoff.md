# Empirica Extraction Handoff

Generated: 2026-03-19 from audit session. Use this to blueprint a claude-sail native epistemic tracking system.

## The Goal

Extract the valuable math/philosophy from Empirica, ditch the MCP plumbing, build a simpler native version for claude-sail.

## What Empirica Does That's Valuable

### 1. Epistemic Vector Tracking (13 dimensions)
- `engagement, know, do, context, clarity, coherence, signal, density, state, change, completion, impact, uncertainty`
- Each scored 0.0-1.0 by Claude (self-assessed) at session start (preflight) and end (postflight)
- Deltas computed: postflight - preflight per vector

### 2. Bayesian Belief Calibration (~250 lines of real math)
- Location: `/home/nick/.local/share/pipx/venvs/empirica/lib/python3.13/site-packages/empirica/core/bayesian_beliefs.py`
- Standard Bayesian update: `posterior_mean = (prior_var * observation + obs_var * prior_mean) / (prior_var + obs_var)`
- Tracks how well Claude's self-assessments predict actual outcomes over time
- Feeds back calibration adjustments: "you tend to overestimate `know` by 0.15"
- Requires >= 3 observations per vector before adjustments kick in
- Caps corrections at +/- 0.25 to prevent drift

### 3. Calibration Insights Analyzer (~335 lines)
- Location: `/home/nick/.local/share/pipx/venvs/empirica/lib/python3.13/site-packages/empirica/core/post_test/calibration_insights.py`
- Detects patterns over >= 5 observations:
  - `chronic_overestimate` / `chronic_underestimate`: same-direction bias in >70% of records
  - `evidence_gap`: vector has low evidence count
  - `phase_mismatch`: large gap in one phase but not the other
  - `volatile`: gap direction flips frequently (noisy self-assessment)

### 4. Findings/Mistakes/Dead-ends Logging
- Simple structured capture: finding text + optional impact score + session linkage
- Mistakes and dead-ends are just tagged findings in practice (zero usage of separate categories in 30 days)

### 5. Grounded Verifications
- Compares postflight self-assessment against actual evidence (test results, finding confirmations/contradictions)
- Feeds into calibration loop

## What Empirica Does That's NOT Valuable (for our purposes)

- 150 CLI commands (we need ~5)
- MCP server that shells out to CLI (introduces the subprocess failure chain)
- 47 SQLite tables across 7 fragmented databases
- Transaction files, sentinel hooks, investigation branches, cascade workflow
- Session resolution logic (complex project path discovery)
- Dual-table storage where preflights go to `reflexes` but reporting queries `epistemic_snapshots`
- Project bootstrap, workspace overview, identity/crypto, messaging, agent spawning

## Current State of Empirica Data

### Databases (7 total)
| Location | Sessions | Findings | Preflights | Postflights | Paired |
|----------|----------|----------|------------|-------------|--------|
| `~/.empirica/` (global) | 129 | 87 | 14 | 107 | 11 |
| `claude-sail/.empirica/` | 70 | 28 | 16 | 59 | 11 |
| `project_scout/.empirica/` | 51 | 22 | 3 | 48 | 2 |
| `s4-notion-portal/.empirica/` | 4 | 7 | 2 | 2 | 2 |
| `s3-project/.empirica/` | 1 | 1 | 1 | 1 | 1 |
| `s4-docs/.empirica/` | 8 | 0 | 0 | 1 | 0 |
| `claude-sail-addons/.empirica/` | — | — | — | — | — |

Key: Preflights are in `reflexes` table, NOT `epistemic_snapshots`. The `epistemic_snapshots` table only has postflight data.

### Orphaned Insights on Disk (678 total)
| Location | Lines | Sync Status |
|----------|-------|-------------|
| `~/.empirica/insights.jsonl` | 526 | 97% have no sync flag |
| `claude-sail/.empirica/insights.jsonl` | 95 | no sync flags |
| `project_scout/.empirica/insights.jsonl` | 51 | 14 synced, 2 unsynced, 35 no flag |
| `claude-sail-addons/.empirica/insights.jsonl` | 3 | — |
| `s4-docs/.empirica/insights.jsonl` | 3 | — |

### Bayesian Beliefs in DB
```sql
-- Global DB has 91 bayesian_belief records
-- Calibration trajectory has 72 records
-- These contain the actual Bayesian prior/posterior data
```

## Why Empirica Fails Mechanically

1. **MCP → CLI subprocess chain**: Every tool call spawns `empirica <command> --flags`. Session resolution, DB lookup, transaction management all happen per-call.
2. **Dual-table storage bug**: Preflights stored in `reflexes`, reporting queries `epistemic_snapshots`. Preflights appear to vanish.
3. **7 fragmented databases**: No cross-project querying. Global DB is a catch-all for sessions that can't resolve a project path (127/129 sessions have no project_id).
4. **15% pairing rate**: Only 27/~180 sessions achieve both preflight AND postflight. Preflights fail more (bootstrap timing), postflights fail more (session ID lost after compaction).

## Obsidian Vault (Working Well — The Complementary System)

- 225 notes total: 115 findings, 75 sessions, 29 blueprints, 3 decisions, 1 idea, 0 patterns
- Obsidian MCP is reliable — every call succeeds
- Already has cross-project visibility (one vault, all projects)
- Session logs link to findings, findings have confidence scores
- Missing: vector tracking, calibration computation

## Design Constraints for Replacement

1. **Single SQLite DB** — one file, all projects tagged, no fragmentation
2. **Direct DB writes** — no subprocess chain, no CLI-as-intermediary
3. **Obsidian as the human-readable layer** — session notes get vector frontmatter
4. **Hook-triggered** — preflight on SessionStart, postflight on session end
5. **~600 lines of core math** to extract and adapt (Bayesian beliefs + calibration insights)
6. **Must handle context compaction** — session ID needs to survive losing context
7. **Graceful degradation** — if anything fails, session continues unblocked (fail-open, like hooks)

## Files to Extract Math From

```
/home/nick/.local/share/pipx/venvs/empirica/lib/python3.13/site-packages/empirica/core/bayesian_beliefs.py  (~250 lines)
/home/nick/.local/share/pipx/venvs/empirica/lib/python3.13/site-packages/empirica/core/post_test/calibration_insights.py  (~335 lines)
```

## Migration Path

1. Build new system
2. Import existing paired sessions from `reflexes` tables (27 sessions with pre+post data)
3. Import existing Bayesian beliefs (91 records from `bayesian_beliefs` table)
4. Import orphaned findings where possible (678 lines, use Obsidian sessions for context)
5. Deprecate Empirica MCP (remove from `~/.claude/mcp.json`)
6. Update claude-sail hooks to use new system
7. Update CLAUDE.md instructions
