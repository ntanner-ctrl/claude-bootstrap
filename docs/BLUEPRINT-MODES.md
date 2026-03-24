# Blueprint Challenge Modes

How the `/blueprint` command challenges your plans — four modes for different needs.

---

## The Four Modes

The blueprint workflow includes adversarial stages (Challenge and Edge Cases) that
stress-test your specification before implementation. These stages can operate in
four modes, selected once at blueprint creation.

### Vanilla Mode

The original behavior. A single agent reviews the spec from one perspective per stage.

- **Stage 3 (Challenge):** Runs `/devils-advocate` — assumption-based challenge
- **Stage 4 (Edge Cases):** Runs `/edge-cases` — boundary condition mapping

**When to use:** Quick reviews, smaller changes, when token budget is tight.

**Cost:** ~1 subagent call per stage (2 total for Stages 3+4).

### Debate Mode

A three-round sequential critique chain. Each round's agent sees all prior output,
creating escalating depth.

**Stage 3 (Challenge):**
1. **Challenger** — Attacks assumptions, finds the weakest points
2. **Defender** — Responds: validates, refutes, or downgrades each finding. Adds missed items.
3. **Judge** — Synthesizes into a final verdict with severity, convergence, and action ratings

**Stage 4 (Edge Cases):**
1. **Boundary Explorer** — Maps every boundary: input, state, concurrency, time, scale
2. **Stress Tester** — Tests each boundary: just below, at, just above, far beyond
3. **Synthesizer** — Prioritizes by impact x likelihood, flags architectural implications

**When to use:** Good for token-constrained reviews or when historical vault context isn't needed.
The debate structure catches issues that single-perspective review misses — the Defender's
response to the Challenger is particularly valuable because it forces nuanced assessment
instead of a raw list of complaints.

**Cost:** ~3 subagent calls per stage (6 total for Stages 3+4). Uses sonnet model.

### Family Mode (Default — Generational Debate)

A multi-round generational critique structure with five specialized agents. Each round
builds on the previous, with an Elder Council that queries historical vault data to
determine when the analysis has converged.

**Round structure (per stage):**
```
Round N:
  ├── Child-Defend (parallel) ──┐
  ├── Child-Assert  (parallel) ──┤
  │                              ▼
  ├── Mother (serial: receives both children)
  ├── Father (serial: receives mother's synthesis)
  │                              ▼
  └── Elder Council (serial: receives father + queries vault)
       │
       ├── CONVERGED → Stop, emit final analysis
       └── CONTINUE  → Round N+1
            Children receive: refined spec + elder's carry_forward context
```

**Agents:**
- **Child-Defend** — Argues the spec is sound, defends design decisions
- **Child-Assert** — Argues the spec has gaps, attacks design decisions
- **Mother** — Synthesizes strengths from both children's positions
- **Father** — Identifies weaknesses and provides directional guidance
- **Elder Council** — Queries the Obsidian vault for historical analogies, validates against
  past decisions, and issues a CONVERGED or CONTINUE verdict

**Stage 3 (Challenge):** Children debate **design decisions**. Mother synthesizes design
strengths. Father finds design weaknesses. Elders validate against historical design decisions.

**Stage 4 (Edge Cases):** Children debate **boundary behavior**. Child-Defend argues
boundaries and error handling are sufficient. Child-Assert finds inputs, states, and
conditions that will break the system.

**When to use:** Deep specifications where historical context matters. The vault integration
means the Elder Council can surface lessons from past projects, making this mode particularly
valuable for teams with an established Obsidian vault of engineering findings.

**Cost:** ~5 agents per round, up to 3 rounds per stage (max ~30 agent calls for Stages 3+4).
Highest token usage of all modes, but produces the deepest analysis.

**Hard limits:**
- Maximum rounds: 3 per stage (hardcoded)
- Per-agent timeout: 3 minutes
- Round timeout: 10 minutes (all 5 agents combined)
- Total mode timeout: 25 minutes (all rounds combined)

**Convergence:** The Elder Council issues CONVERGED when: (1) no historical red flags remain
unaddressed, (2) Father's proposed changes are directionally sound, and (3) no critical
unresolved tensions between children's positions. If max rounds are exhausted without
convergence, confidence is set to 0.3 and regression is suggested if critical items remain.

**Output:** Same structure as debate mode — curated findings to `adversarial.md` (organized
by round), raw transcript to `debate-log.md`. Progress tracked via `family_progress` in
`state.json`.

### Guided Walkthrough (Planned — Not Yet Implemented)

A future Stage 7 implementation option that would provide interactive human review at each
work unit boundary. Deferred pending design of the interactive protocol (pause/resume state,
permission inheritance, context accumulation management). When implemented, this would be
the third implementation option alongside Sequential and Parallel dispatch.

### Team Mode (Experimental)

Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Falls back to debate if not enabled.

Spawns three concurrent agents with distinct perspectives:
- **Red Team** — Security, trust boundaries, attack vectors
- **Skeptic** — Complexity, YAGNI, hidden coupling, maintainability
- **Pragmatist** — Operational reality, deployment risks, monitoring gaps

Agents independently review, then read each other's findings and respond, then converge
on a consensus list.

**When to use:** Large, security-sensitive, or high-risk changes where concurrent diverse
perspectives justify the cost. Experimental — behavior may evolve.

**Cost:** 3 concurrent agents per stage (6 total). Highest token usage.

---

## Comparison

| Aspect | Vanilla | Debate | Family | Team |
|--------|---------|--------|--------|------|
| Perspectives | 1 | 3 (sequential) | 5 (generational, multi-round) | 3 (concurrent) |
| Token cost | Low (~2 calls) | Medium (~6 calls) | High (~10-30 calls) | High (~6 agents) |
| Depth | Surface | Deep (escalating context) | Deepest (historical + generational) | Broad (diverse views) |
| Speed | Fast | Moderate | Slow (multi-round convergence) | Depends on agent coordination |
| Best for | Quick reviews | Token-constrained reviews | Most work (default) | High-risk, security-critical |
| Requires | Nothing | Nothing | Obsidian vault (recommended) | Experimental flag |
| Relative cost | 1x | 3x | 5-15x (complexity-adaptive) | 3x |

---

## Output Format

All four modes produce the same output structure:

- **`adversarial.md`** — Canonical source of truth. Curated findings with severity ratings.
- **`debate-log.md`** — Raw transcript (debate/family/team mode only). Debug artifact, not primary.

The Judge/Synthesizer in debate mode, Elder Council in family mode, and the lead agent in
team mode produce structured JSON output that feeds automatic regression triggers. See
`docs/PLANNING-STORAGE.md` for the schema.

---

## Mode Selection

```bash
/blueprint feature-auth                      # family mode (default)
/blueprint feature-auth --challenge=vanilla  # single-agent
/blueprint feature-auth --challenge=debate   # sequential debate chain
/blueprint feature-auth --challenge=family   # explicit family (same as default)
/blueprint feature-auth --challenge=team     # experimental teams
```

The mode is set once at creation and locked for the blueprint's lifecycle.
On regression, the same mode is reused — no re-prompting.

---

## Backward Compatibility

- Pre-v2 plans (created before this enhancement) default to `vanilla` mode on migration
- The vanilla mode output is identical to the pre-v2 challenge behavior
- No existing workflows are broken — debate is additive

---

## FAQ

**Q: Why is family the default instead of debate?**
A: Family mode catches significantly more critical bugs than debate — in testing, it found
6 critical/high bugs that debate/vanilla would have missed (0.90 empirical confidence).
The Mother's synthesis role catches compound failures where two individually-safe things
interact dangerously. The token cost is managed by complexity-adaptive rounds (S-1):
simple specs run only 1 round (~5 agent calls), comparable to debate's 3.

**Q: Family mode is more expensive than debate. Why make it the default?**
A: Complexity-adaptive rounds (S-1) scale cost to complexity: simple specs (≤3 WUs) get
1 round, medium specs get 2, complex specs get 3. For simple specs, the cost difference
vs debate is minimal (~5 agents vs ~3). For complex specs, the deeper analysis is worth
the additional tokens — these are the specs where critical bugs are most likely to hide.
Use `--challenge=debate` if you need to minimize token usage.

**Q: Can I switch modes mid-blueprint?**
A: No. The mode is locked at creation to ensure consistent adversarial depth across
the blueprint's lifecycle. Create a new blueprint if you need a different mode.

**Q: What happens if a debate agent times out?**
A: Each agent has a 5-minute timeout, each stage has 15 minutes total. On timeout,
the system falls back to vanilla mode for the remainder, preserving any completed rounds.

**Q: How does family mode differ from debate mode?**
A: Debate uses a linear Challenger→Defender→Judge chain. Family uses a generational
structure (Children→Mother→Father→Elder Council) that can run multiple rounds and
queries the Obsidian vault for historical context. Family mode produces deeper analysis
but costs significantly more tokens.

**Q: Does family mode require an Obsidian vault?**
A: No, but it's recommended. The Elder Council queries the vault for historical analogies
and past decisions. Without a vault, the Elder Council still synthesizes based on the
current round's findings but lacks historical grounding.

**Q: Why is team mode experimental?**
A: It requires Claude Code's experimental agent teams feature, which is still evolving.
The behavior and quality of concurrent agent coordination may change as the feature matures.
