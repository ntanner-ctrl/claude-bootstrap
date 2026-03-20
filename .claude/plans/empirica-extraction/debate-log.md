# Family Mode Debate Log — empirica-extraction

## Round 1

### Child-Defend (Generation 1)

**Defended positions:**

1. **Single flat JSON file** — Cross-project calibration visible, no binary dependency (SQLite), auditable with `cat | jq`. Fragmentation was Empirica's #1 architectural failure.

2. **Behavioral instructions paired with corrections** — Claude doesn't have executive function that sees a number and independently decides to change behavior. Instructions are prompt-engineering artifacts that shape behavior at the moment when behavior can be shaped. Numbers without instructions are vanity metrics.

3. **Rolling mean delta over Bayesian** — Epistemically honest given 27 data points across 13 vectors. Same data structure feeds future Bayesian upgrade. The 91 existing Bayesian records are artifacts of incompatible computation.

4. **`paired` flag requirement** — Prevents survivorship bias. If postflight completion correlates with session success, unpaired sessions skew calibration toward "sessions that went well."

5. **Three-layer session ID persistence** — Directly addresses the documented 15% pairing rate failure. The file layer survives context compaction because it exists on disk.

6. **Minimum 5 paired sessions threshold** — Prevents volatile single-session deltas from producing incoherent behavioral instructions.

7. **Context-sensitive familiarity warnings** — Prevents calibration from becoming an overconfidence machine in novel contexts. Projects false precision at the exact moment epistemic humility is most warranted.

8. **Four-hook decomposition** — Maps to Claude Code's event model (SessionStart vs PostToolUse are different events). Single-responsibility makes debugging possible.

9. **Not migrating Bayesian beliefs** — Methodologically correct. Importing pre-cooked beliefs from a different algorithm would corrupt data integrity.

10. **Migration script in `scripts/` not installed** — Correct release hygiene. One-time tools shouldn't be permanently distributed.

11. **Keeping the ritual itself** — The self-assessment prompt is where the calibration loop closes behaviorally. Automatic instrumentation would preserve data collection while destroying the primary value.

**Acknowledged weakness:** Behavioral instruction templates are static and only cover 5 of 13 vectors. The catch-all template is thin. Templates need to grow with the data.

---

### Child-Assert (Generation 1)

**Challenges:**

1. **PostToolUse hooks can't capture prose output** (HIGH) — PostToolUse hooks receive tool call payloads, not Claude's free-form messages. Without an MCP tool or slash command being invoked, there's no event to trigger vector capture. The spec doesn't define what tool call triggers these hooks. System stores zero data.

2. **15% pairing rate unresolved** (HIGH) — None of the listed mitigations address the structural issue: sessions end when the user closes the terminal. Claude is not in the loop at termination. CLAUDE.md instructions are "suggestions only" per the spec's own enforcement tiers. Core value proposition may never activate.

3. **Single-file JSON corruption risk** (HIGH) — Read-modify-write via jq with no locking, no temp-file-then-rename pattern specified. Hook interrupted mid-write = corrupted JSON = silent total data loss on next session. Empirica used append-only JSONL, which was safer.

4. **Behavioral templates only cover 5/13 vectors** (MEDIUM) — Need 26 combinations (13 vectors × 2 directions), only have 5. The "key innovation" fires for at most 38% of cases.

5. **`.current-session` clobbers with parallel worktrees** (MEDIUM) — Single global path, no namespacing. Two simultaneous sessions corrupt each other's calibration data.

6. **Migration assumes wrong SQLite schema** (MEDIUM) — Empirica hooks may write JSONL, not the assumed `reflexes`/`epistemic_snapshots` tables. Migration could produce 0 records.

7. **2-second timing budget not enforced** (MEDIUM) — On WSL2/NTFS (user's platform), no `timeout` wrapper specified. Silent hook timeout means no calibration context.

---

### Mother — Strength Synthesizer (Generation 2)

**Genuinely strong (both children agree):**
1. Single flat JSON file — correct for bash toolkit constraints
2. Behavioral instructions as core mechanism — the right insight about AI behavior change
3. Rolling means over Bayesian at current density — epistemically honest
4. `paired` flag — prevents survivorship bias
5. Not migrating Bayesian beliefs — methodologically correct
6. Four-hook decomposition principle — correct event model mapping
7. Keeping the ritual — primary value is self-assessment, not data

**Genuinely needs work:**
1. PostToolUse capture mechanism undefined (CRITICAL) — load-bearing ambiguity
2. Atomic writes not specified — dangerous anti-pattern in code examples
3. Template coverage gap — 5/26 combinations, "key innovation" mostly generic
4. `.current-session` not namespaced — worktree collision risk
5. Migration schema not verified — JSONL vs SQLite uncertainty
6. Timing budget not enforced — WSL2/NTFS risk
7. Pairing rate mitigations not ranked — creates false confidence

**Deepest tension:** The spec assumes hooks can scan prose output. They cannot.

---

### Father — Weakness Analyst & Guide (Generation 2)

**Spec changes required (5):**

| Item | Direction |
|------|-----------|
| PostToolUse trigger | Choose slash command (`/preflight-submit`) or Bash-write; specify exact trigger surface. Slash command is cleaner. |
| Atomic writes | Rewrite code examples to temp-file-then-rename; mark as required |
| Pairing rate | Rank mitigations; state realistic target (50-60%); elevate `/end` as primary mechanism |
| Migration schema | Mark tentative; require verification; specify JSONL fallback path |
| Timing budget | Add `timeout 1.5s` wrapper; specify graceful fallback output |

**Acceptable risk (2):**

| Item | Rationale |
|------|-----------|
| Template coverage at 5/13 | Acceptable for v1. Reframe as "priority templates," don't expand prematurely |
| `.current-session` global path | Single-user acceptable risk. Note limitation and future namespacing path |

**Confidence: 70%** — Solid everywhere except vector capture (Sections 5.3/5.4).

**Unresolved tension:** Postflight submission depends on user running `/end`. Terminal-close bypasses Claude entirely. This is a structural constraint, not a solvable engineering problem. Frame as usage discipline, not a bug.

---

### Elder Council (Generation 3)

**Vault evidence reviewed:** 9 Empirica-specific findings, 1 architecture decision, 1 audit session.

**Historical support for Father's changes:** All 5 supported. No contradictions.

| Change | Support | Key Evidence |
|--------|---------|-------------|
| Slash command for vector capture | Supported | 2026-03-13: Empirica stdin hang proves implicit triggers create invisible failures |
| Atomic writes | Supported | Two independent signals: project_scout heartbeat-v2 + split-brain finding |
| Rank pairing mitigations | Supported | 15% measured rate; CLAUDE.md = "suggestions only" by own taxonomy |
| Migration tentative | Supported | 2026-03-19: dual-table bug proves `epistemic_snapshots` is effectively empty |
| Timeout wrapper | Supported | 2026-03-12: empirica-mcp had NO subprocess timeout, causing silent hangs |

**Additional risk not in Father's list:**
- `.current-session` stale marker file can deadlock session creation if previous session crashed without cleanup. Direct analogue: 2026-03-10 Empirica resolver deadlock. SessionStart hook MUST overwrite stale markers, not fail.
- Migration should query `reflexes` for BOTH phases (not reflexes + epistemic_snapshots), since the dual-table finding shows epistemic_snapshots is empty.

**Verdict: CONVERGED** — Confidence 0.85

**Quote:** "A 50% pairing rate with reliable data is worth more than a 100% target with corrupt data."

---

## Stage 4: Edge Cases — Round 1

### Child-Defend (Generation 1)

**7 boundaries defended as sufficient:**
1. Vector value inputs — AI user + natural damping (rolling avg + clamp) make validators net-negative
2. JSON file states — Fast path + atomic writes eliminate realistic failures; file size bounded by design
3. Session lifecycle — Unconditional overwrite historically proven; alternatives require unavailable state
4. jq availability — Graceful skip preserves data; awk fallback is higher risk than skip
5. Obsidian vault — JSON is authoritative; Obsidian is a recoverable projection, not write-through cache
6. Concurrent worktrees — Accepted risk at correct severity; fix would add latency
7. Rolling window — jq slice `[-50:]` correct for all N; 5-session threshold guards empty array

**Key insight:** "The boundaries that received the most defensive engineering attention are exactly the boundaries where the historical record shows real failures."

---

### Child-Assert (Generation 1)

**20 edge cases identified. Top 6 by severity:**

1. **Postflight against missing preflight** (HIGH/Critical) — No preflight in epistemic.json for this session, null deltas stored, observation_count inflated with garbage
2. **Missing vectors** (HIGH/High) — Partial submission means some vectors never reach 5-session threshold
3. **0-byte epistemic.json** (HIGH/High) — Fast path checks existence, not empty file; jq fails on 0 bytes
4. **First-ever pairing** (HIGH/High) — `add/length` on empty `last_deltas` produces null before threshold guard fires
5. **~/.claude/ not writable on WSL2** (HIGH/High) — .current-session write fails silently, every session unpaired
6. **Cross-session delta pairing** (MEDIUM/High) — "Latest unpaired session" fallback pairs yesterday's preflight with today's postflight

**Three gaps identified:**
- Gap A: No input validation on vector values
- Gap B: Empty `last_deltas` computation path produces null before threshold check
- Gap C: Cross-session delta pairing semantics under-specified

---

### Mother — Strength Synthesizer (Generation 2)

**Key insight:** "Defender's defenses are correct for the *output surface* (what calibration
instructions get generated). Challenger's bugs are real at the *storage surface* (what gets
written to epistemic.json). Two distinct safety layers; spec only fully defends one."

4 items need work: null propagation, empty array guard, 0-byte fast path, cross-session pairing.

### Father — Weakness Analyst & Guide (Generation 2)

4 spec changes needed + 3 refinements. All are one-line or small additions — no architectural changes.
Confidence: 82%.

Key refinement: "Fail-open on the session (exit 0), but fail-loudly to Claude (stderr warning)."

### Elder Council (Generation 3)

**Verdict: CONVERGED** — Confidence 0.90
8 vault analogues support all changes. Zero contradictions.
Nuance: null guard should filter field-level nulls, not discard entire records.
