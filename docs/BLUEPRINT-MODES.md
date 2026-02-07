# Blueprint Challenge Modes

How the `/blueprint` command challenges your plans — three modes for different needs.

---

## The Three Modes

The blueprint workflow includes adversarial stages (Challenge and Edge Cases) that
stress-test your specification before implementation. These stages can operate in
three modes, selected once at blueprint creation.

### Vanilla Mode

The original behavior. A single agent reviews the spec from one perspective per stage.

- **Stage 3 (Challenge):** Runs `/devils-advocate` — assumption-based challenge
- **Stage 4 (Edge Cases):** Runs `/edge-cases` — boundary condition mapping

**When to use:** Quick reviews, smaller changes, when token budget is tight.

**Cost:** ~1 subagent call per stage (2 total for Stages 3+4).

### Debate Mode (Default)

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

**When to use:** Default for most work. The debate structure catches issues that single-perspective
review misses — the Defender's response to the Challenger is particularly valuable because
it forces nuanced assessment instead of a raw list of complaints.

**Cost:** ~3 subagent calls per stage (6 total for Stages 3+4). Uses sonnet model.

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

| Aspect | Vanilla | Debate | Team |
|--------|---------|--------|------|
| Perspectives | 1 | 3 (sequential) | 3 (concurrent) |
| Token cost | Low (~2 calls) | Medium (~6 calls) | High (~6 agents) |
| Depth | Surface | Deep (escalating context) | Broad (diverse views) |
| Speed | Fast | Moderate | Depends on agent coordination |
| Best for | Quick reviews | Most work (default) | High-risk, security-critical |
| Requires | Nothing | Nothing | Experimental flag |

---

## Output Format

All three modes produce the same output structure:

- **`adversarial.md`** — Canonical source of truth. Curated findings with severity ratings.
- **`debate-log.md`** — Raw transcript (debate/team mode only). Debug artifact, not primary.

The Judge/Synthesizer in debate mode and the lead agent in team mode produce structured
JSON output that feeds automatic regression triggers. See `docs/PLANNING-STORAGE.md`
for the schema.

---

## Mode Selection

```bash
/blueprint feature-auth                      # debate (default)
/blueprint feature-auth --challenge=vanilla  # single-agent
/blueprint feature-auth --challenge=debate   # explicit debate
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

**Q: Why is debate the default instead of vanilla?**
A: The three-round chain catches significantly more issues than single-perspective review.
The Defender round is particularly valuable — it prevents false positives by forcing each
finding to withstand scrutiny, and it identifies things the Challenger missed.

**Q: Can I switch modes mid-blueprint?**
A: No. The mode is locked at creation to ensure consistent adversarial depth across
the blueprint's lifecycle. Create a new blueprint if you need a different mode.

**Q: What happens if a debate agent times out?**
A: Each agent has a 5-minute timeout, each stage has 15 minutes total. On timeout,
the system falls back to vanilla mode for the remainder, preserving any completed rounds.

**Q: Why is team mode experimental?**
A: It requires Claude Code's experimental agent teams feature, which is still evolving.
The behavior and quality of concurrent agent coordination may change as the feature matures.
