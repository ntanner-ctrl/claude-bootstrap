# Prior Art Report — test-debt-in-prism

**Run at:** 2026-05-01
**Scope:** Test-debt classification taxonomies, periodic test-failure triage tools, vocabulary. Plus adjacent platform-feasibility check on Claude Code subagent hooks.
**Queries:** 6 web searches, 4 deep-dive WebFetches.

---

## Part A — Test-Debt Classification (the prior-art question)

### Problem

Nick's brief proposes a 4-category classification for failing tests in `/prism` Stage 5.5: **real-issue / drift / abandoned / quarantine candidate**. The question: has anyone built a tool or established a vocabulary for periodic test-failure classification beyond flaky-vs-real?

### Candidates evaluated

```
┌─────────────────────────────────────────────────────────────────┐
│ [1] Trunk Flaky Tests — trunk.io/flaky-tests                    │
│     Fit: L  Maturity: H  Integration: L  Risk: M                │
│     Classifies tests on a single axis (flaky probability via    │
│     statistical analysis of CI runs). No "abandoned" or "drift" │
│     concept. SaaS, CI-bound. Wrong shape for prism.             │
│                                                                 │
│ [2] Atlassian Flakinator — internal Atlassian tool              │
│     Fit: L  Maturity: H  Integration: N/A (not OSS)             │
│     Multi-signal Bayesian flakiness scoring. Outputs a          │
│     0–1 flakiness score. Doesn't distinguish drift/abandoned.   │
│     Conceptually adjacent — closest thing to "classification    │
│     beyond binary" but along the wrong axis.                    │
│                                                                 │
│ [3] Snowflake (teddyking/snowflake) — github.com/teddyking      │
│     Fit: L  Maturity: M  Integration: L  Risk: L                │
│     Reporter + server + UI for tracking flaky test history.     │
│     Single bucket: "flaky." No taxonomy beyond that.            │
│                                                                 │
│ [4] BuildPulse / TestDino / Datadog CI Visibility               │
│     Fit: L  Maturity: H  Integration: L  Risk: L–M (SaaS)       │
│     All flaky-detection-shaped. Track test stability over time, │
│     surface flakes. None classify why a non-flaky test fails.   │
│                                                                 │
│ [5] govuk-rfcs/rfc-069 — tech debt classification framework    │
│     Fit: M  Maturity: H (RFC, not tooling)  Integration: H      │
│     Two-axis (impact × effort) classification with H/M/L per    │
│     axis. NOT test-specific, but the structure is borrowable    │
│     for our 4-category severity ordering.                       │
└─────────────────────────────────────────────────────────────────┘
```

### Vocabulary findings

| Term | Industry usage | Verdict for our domain |
|------|---------------|------------------------|
| **Flaky** | Universal, well-defined (test that fails non-deterministically on unchanged code) | **Adopt as-is** — maps directly to our "quarantine candidate" |
| **Test rot** | Informal; conflates several issues (stale data, outdated assertions, env mismatch) | Skip — too vague |
| **Stale tests** | Informal; usually means assertions referencing old behavior | Sub-concept of our "drift" |
| **Drifted tests** | NOT a term of art. "Drift" is used for environmental drift, not test drift | Our usage is non-standard; document the meaning |
| **Abandoned tests** | NOT a term of art. Closest industry equivalent: "stale" with "remove cases that haven't detected defects in 6 months" (per Ranorex audit guidance) | Our usage is novel — define explicitly |
| **Real bug** / "real-issue" | Implicit in all flaky-test tooling (the negative class — "if not flaky, it's a real failure") | Standard, just not formally named |

**Key takeaway:** The industry has converged on **flaky-vs-real** as the dominant binary, plus a strong tooling ecosystem for detecting flakes via retry/statistical analysis. The 4-way split (real / drift / abandoned / quarantine) is **not standard vocabulary** and doesn't have direct prior tooling.

### Detection signals worth borrowing

| Signal | Source | Use in our design |
|--------|--------|-------------------|
| Retry-based flakiness detection (fail then pass on rerun) | Trunk, Atlassian, Currents, Playwright built-in | Strong signal for "quarantine candidate" classification — we can run failed tests twice and check |
| Statistical analysis across runs | Flakinator (Bayesian), Trunk | Probably over-engineered for single-shot prism; flag as future extension |
| Git blame on test file vs symbol-under-test | (Not seen in tools — usually manual) | Useful for distinguishing "abandoned" (test file old, symbol gone) from "drift" (test file recent, symbol moved) |
| Symbol resolution (does the symbol the test exercises still exist?) | (Not seen in tools — usually manual) | Core to our "drift" vs "abandoned" distinction |

### Recommendation: **Inform** (not Adopt or Build-from-scratch)

No tool solves the 4-category periodic-classification problem. But:

- **Borrow retry-based detection** for the flake/quarantine axis — well-established, simple to implement
- **Borrow severity-axis structure** from govuk-rfcs/rfc-069 (impact × effort gives natural severity ordering)
- **Document that "drift" and "abandoned" are our terms of art** — not industry-standard, so the agent prompt and synthesis output should define them up front

**Don't borrow:**
- Bayesian/statistical multi-signal scoring (Flakinator) — over-engineered for single-shot prism
- Persistent test-history tracking (Snowflake, Trunk) — prism is stateless across runs; that's a different product

### Adjacent insight — the gap is real

The fact that **no industry tool classifies why a non-flaky test is failing** validates the brief's framing. Existing tools assume "if it's failing and not flaky, a human will look at it." Our `/prism` is the human (or augments the human) — so the classification work has to happen in the tool. The market gap is genuine.

---

## Part B — Hook Feasibility Check (front-loaded by the user)

### Question

The brief's per-agent Bash allowlist requires a `PreToolUse` hook that knows **which subagent** invoked the Bash call (so `test-debt-reviewer` can run `pytest` while the lens agents can't). Is this mechanically possible in Claude Code?

### Evidence — contradictory

**Source 1 — Official Claude Code hooks docs (code.claude.com/docs/en/hooks):**
> `agent_id` — Unique identifier for the subagent. Present only when the hook fires inside a subagent call. Use this to distinguish subagent hook calls from main-thread calls.
>
> `agent_type` — Agent name (for example, `"Explore"` or `"security-reviewer"`). Present when the session uses `--agent` or the hook fires inside a subagent.

**Implies:** hooks DO fire inside subagent calls, AND the schema exposes the subagent's identity. Per-agent allowlist is feasible as documented.

**Source 2 — GitHub issue #34692 (anthropics/claude-code), status: OPEN, version: 2.1.76:**
> PreToolUse and PostToolUse hooks configured in `~/.claude/settings.json` do not fire for tool calls made by subagents spawned via the Agent tool. Only tool calls from the main session thread trigger hooks.
>
> ✅ Direct main-session Bash calls → hooks fire
> ❌ Subagent Bash calls → hooks silently bypassed

**Implies:** the documented behavior is broken in practice. Per-agent allowlist is infeasible until this is fixed.

### Verdict — RESOLVED EMPIRICALLY (2026-05-01)

**Hooks DO fire on subagent Bash calls. `agent_id` and `agent_type` ARE populated.** Issue #34692 is either stale or environment-specific; the official docs are accurate for our installation.

**Test method:** Instrumented the existing wired `dangerous-commands.sh` hook to dump full stdin to `/tmp/hook-debug.log`, then dispatched a `general-purpose` subagent to run a sentinel `echo` Bash command. Reverted the instrumentation cleanly (diff vs `claude-sail/hooks/dangerous-commands.sh` shows zero drift).

**Captured stdin from the subagent's Bash call:**
```json
{
  "session_id": "09926b10-faed-48aa-8aa1-cc9544d9ac18",
  "transcript_path": "...",
  "cwd": "/home/nick/claude-sail",
  "permission_mode": "acceptEdits",
  "agent_id": "ac26988a8eb1f12b9",
  "agent_type": "general-purpose",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": {"command": "echo \"SUBAGENT_BASH_SENTINEL_X8K9P2\"", ...},
  "tool_use_id": "toolu_..."
}
```

For comparison, main-session Bash calls produce the same payload **without** `agent_id`/`agent_type` — exactly as documented.

**Implication for design:** The per-agent allowlist pattern in the brief works as specified. The PreToolUse hook can match on `agent_type == "test-debt-reviewer"` and apply a different allowlist than for the lens/domain reviewer agents. No architectural fallback needed.

### Recommendation for the blueprint

- **Containment design is unblocked** — describe stage proceeds with the per-agent allowlist as the brief specifies
- **No fallback ADR needed** — the contingency designs (env-flag, trust-prompt, etc.) are off the table for v1; document them in a comment block as "alternatives considered, rejected because per-agent matching is feasible"
- **Hook implementation note:** the PreToolUse hook reads `agent_type` from stdin JSON via `jq -r '.agent_type // empty'`. When matched against `"test-debt-reviewer"`, apply the test-runner allowlist; when null/empty/other, fall through (don't enforce on lens agents that don't use Bash anyway)

### Scope clarification (added 2026-05-01)

Per Nick: the test-debt-reviewer's v1 mandate is narrow — **"run the test suite, classify pre-existing failures by why-they-fail."** That is the *only* problem we're solving in this blueprint. Adjacent test-debt concerns are explicit non-goals for v1:

| Future expansion | v1 status |
|------------------|-----------|
| Coverage gaps | NON-GOAL — different problem (what's missing vs what's broken) |
| Test staleness (last-run, last-failed timestamps) | NON-GOAL — needs persistent state we don't have |
| Mutation testing | NON-GOAL — different scale of investment |
| Flaky-detection via re-run statistics | PARTIAL — single re-run is in scope as the "quarantine candidate" classification signal; multi-run Bayesian analysis is not |
| Test-debt management as a continuous discipline | NON-GOAL — prism is periodic, not continuous; the question we answer is "what's broken right now," not "how is debt trending" |

This narrows industry-borrowing too: of the prior-art tools surveyed, **none are a fit for adoption** because they're all change-scoped (CI) or trend-scoped (multi-run). What we're building is point-in-time-classification, which the industry doesn't tool. Confirms the **Build (with informed borrowing)** recommendation.

---

## Summary for the user

| Question | Answer |
|----------|--------|
| Does prior tooling solve our problem? | **No.** Industry has flaky-detection ecosystems (Trunk, Atlassian, Buildpulse) but none classify on the 4-axis taxonomy we want. The gap is real. |
| Is the 4-category classification industry-standard vocabulary? | **No.** "Flaky" is. "Drift" / "abandoned" / "real-issue" are our terms of art — must be defined explicitly in agent prompt and synthesis. |
| Should we borrow anything? | **Yes** — retry-based flake detection, govuk-rfcs/rfc-069 severity-axis structure. Skip statistical scoring and persistent history (wrong shape for prism). |
| Is per-agent Bash allowlist feasible? | **YES — empirically confirmed 2026-05-01.** Subagent Bash calls fire PreToolUse hooks with `agent_id`/`agent_type` populated. Issue #34692 does not reproduce on our installation. |
| Build vs Adopt? | **Build (with informed borrowing).** No tool to adopt; vocabulary and signals to inform our own design. |

---

## Sources

### Hook feasibility
- [Claude Code Hooks docs](https://code.claude.com/docs/en/hooks)
- [Issue #34692 — PreToolUse/PostToolUse hooks do not fire for subagent tool calls](https://github.com/anthropics/claude-code/issues/34692)
- [Issue #7881 — SubagentStop hook cannot identify which specific subagent finished](https://github.com/anthropics/claude-code/issues/7881)
- [Claude Code Hooks Mastery](https://github.com/disler/claude-code-hooks-mastery)

### Test-debt prior art
- [Atlassian Flakinator blog post](https://www.atlassian.com/blog/atlassian-engineering/taming-test-flakiness-how-we-built-a-scalable-tool-to-detect-and-manage-flaky-tests)
- [Trunk Flaky Tests](https://trunk.io/flaky-tests)
- [Snowflake (teddyking/snowflake)](https://github.com/teddyking/snowflake)
- [9 Best Flaky Test Detection Tools 2026 — TestDino](https://testdino.com/blog/flaky-test-detection-tools/)
- [Test flakiness multivocal review (ScienceDirect)](https://www.sciencedirect.com/science/article/pii/S0164121223002327)
- [govuk-rfcs/rfc-069 tech debt classification](https://github.com/alphagov/govuk-rfcs/blob/main/rfc-069-classifying-and-measuring-tech-debt.md)
- [Flakinator at GitHub Marketplace (Flaptastic)](https://github.com/marketplace/flaptastic)
- [Test Failure Analysis — TestDino](https://testdino.com/blog/test-failure-analysis/)
