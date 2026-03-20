# Prior Art Report: Epistemic Self-Assessment Tracking for AI Agents

## Problem
Session-level epistemic self-tracking for AI coding agents — tracking confidence
vectors over time, computing calibration from preflight/postflight deltas, generating
behavioral feedback. Specifically for Claude Code in a bash-only toolkit.

## Stack
Bash/shell (no Python runtime dependency allowed)

## Queries
3 GitHub searches, 1 package registry search, 3 README fetches

## Candidates

### [1] Empirica (Nubaeon/empirica)
Source: https://github.com/Nubaeon/empirica
Fit: **High** — this IS the system we're extracting from
Maturity: **Medium** — functional but has architectural issues (7 DBs, 15% pairing)
Integration: **Low** — MCP server with Python subprocess chain, can't be used as bash lib
Risk: **High** — the plumbing issues are why we're here
Notes: The ~600 lines of math (bayesian_beliefs.py + calibration_insights.py) are
the direct extraction target. The architecture around them is what we're discarding.

### [2] Brenner Bot (Dicklesworthstone/brenner_bot)
Source: https://github.com/Dicklesworthstone/brenner_bot
Fit: **Low** — focused on scientific reasoning methodology, not agent calibration
Maturity: **Medium** — structured, but different problem domain
Integration: **Low** — TypeScript, different architecture entirely
Risk: **Low**
Notes: Uses 7-dimension session scoring and assumption ledgers. Interesting concept
(explicit epistemic commitments) but solving a different problem (scientific research
methodology vs agent self-calibration). The "assumption ledger" pattern is worth noting.

### [3] Claude Copilot Confidence Scoring
Source: https://github.com/Everyone-Needs-A-Copilot/claude-copilot
Fit: **Low** — per-finding confidence scores, not session-level calibration over time
Maturity: **Unknown** — README 404'd
Integration: **Low** — different architecture
Risk: **N/A**
Notes: Attaches 0-1 confidence scores to individual work products. This is "how
confident am I about THIS output" not "how accurate are my self-assessments over time."

### [4] LLM Calibration Mechanism (Exploration-Lab)
Source: https://github.com/Exploration-Lab/LLM-Calibration-Mechanism
Fit: **None** — academic research on internal model layer calibration, offline analysis
Maturity: **High** (as research code)
Integration: **None** — fundamentally different problem (model internals vs agent behavior)
Risk: **N/A**
Notes: Measures how probability estimates evolve through neural network layers. Useful
for understanding model internals, completely irrelevant to runtime agent self-tracking.

### [5] DeepEval (confident-ai/deepeval)
Source: https://github.com/confident-ai/deepeval
Fit: **Low** — LLM output evaluation framework, not self-calibration
Maturity: **High** — popular, well-maintained
Integration: **Low** — Python library, evaluation-focused
Risk: **Low**
Notes: Evaluates LLM outputs against metrics (hallucination, relevance, etc.). Could
theoretically feed into calibration, but solves a different problem (external evaluation
vs self-assessment tracking).

## Academic Landscape

The academic literature on LLM calibration is robust but focuses on:
- Internal model calibration (logit-based, token probability)
- Fine-tuning approaches to improve calibration
- Prompt-based self-assessment adjustment

None of these are applicable to our use case: session-level agent self-assessment
tracked over time with behavioral feedback. This is a novel intersection of:
- Bayesian belief updating (well-understood math)
- Agent session lifecycle (specific to Claude Code/similar tools)
- Behavioral instruction generation (our innovation from conversation analysis)

---

## Recommendation: **Build**

**Rationale:** Empirica is the only system that solves this exact problem, and it IS
the system we're extracting from. No other library, framework, or tool provides
session-level epistemic vector tracking with calibration feedback for AI coding agents.
The academic research addresses fundamentally different problems (model internals,
output evaluation). The math we need exists in Empirica's source; the architecture
around it is what failed.

**Patterns worth borrowing:**
- Brenner Bot's "assumption ledger" concept — explicit epistemic commitments that
  can be audited. Could inform how we structure behavioral feedback.
- DeepEval's metric-based evaluation approach — if we ever want to ground
  calibration against objective measures (Layer 3 future work).

**Next step:** Proceed to spec (Stage 2).
