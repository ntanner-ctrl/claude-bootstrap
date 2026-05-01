# Prior Art Report: prism

## Problem
Holistic code health assessment with paradigm lens swarm, serial domain review with accumulated context, and themed remediation plan output.

## Stack
Bash/Markdown (Claude Code toolkit)

## Searches
3 GitHub queries, 3 repo deep evaluations

## Candidates

### [1] claude-code-skills (levnikolaevich)
- **Source:** github.com/levnikolaevich/claude-code-skills
- **Fit:** Medium | **Maturity:** Medium | **Integration:** Low | **Risk:** Low
- Has paradigm lenses (DRY/KISS/YAGNI via code-principles-auditor) and 9 parallel auditors. Full Agile pipeline with Linear integration, multi-model review (Codex+Gemini), three-tier orchestration (L0 meta-orchestrator → L1 orchestrators → L2/L3 workers). Remediation is category-scoped, not themed. Review is parallel with cross-validation, not serial accumulation. Would require gutting most of it to extract the lens pattern.

### [2] Heavy3 code-audit
- **Source:** github.com/heavy3-ai/code-audit
- **Fit:** Low | **Maturity:** Low | **Integration:** Medium | **Risk:** Low
- Multi-model consensus (GPT 5.4, Gemini 3.1, Grok 4) reviewing correctness/performance/security. Change-scoped only (PRs, commits, diffs). No paradigm lenses. No remediation plans. Different problem space.

### [3] awesome-copilot tech-debt-remediation-plan
- **Source:** github.com/github/awesome-copilot
- **Fit:** Low-Medium | **Maturity:** Medium | **Integration:** Low | **Risk:** Low
- Single agent, analysis-only, structured output with ease/impact/risk scoring on 1-5 scale. Nice output format but no multi-lens approach, no serial accumulation, no paradigm awareness. Copilot agent.

### [4] Anthropic official code-review plugin
- **Source:** github.com/anthropics/claude-code/plugins/code-review
- **Fit:** Low | **Maturity:** High | **Integration:** High | **Risk:** Low
- Parallel agents for PR review with confidence scoring. Change-scoped, not whole-project. No paradigm lenses. Confidence-based filtering is a useful pattern.

## Recommendation: Inform

No candidate matches the core design — serial domain review with accumulated context where later agents respect earlier constraints. The unique value of prism is the blueprint-style serial pipeline applied to review, which none of these implement.

### Patterns Worth Borrowing
- **Ease/Impact/Risk scoring** (tech-debt-remediation) — useful for remediation plan prioritization
- **Confidence-based filtering** (Anthropic code-review) — reduce noise from low-confidence paradigm observations
- **Category-scoped remediation** (claude-code-skills) — validates the "themed" approach to grouping findings
