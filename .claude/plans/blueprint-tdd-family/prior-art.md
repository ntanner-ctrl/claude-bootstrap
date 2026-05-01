# Prior Art Report

## Problem

Two internal architecture changes to claude-sail's blueprint workflow:
1. Per-work-unit TDD annotation (replacing global TDD path choice)
2. Default challenge mode change (debate → family)

## Stack

Pure bash/markdown toolkit (no package manager, no runtime dependencies)

## Search Summary

Queries: 2 GitHub/web searches

### Candidates Evaluated

**[1] claude-flow TDD agents** — github.com/ruvnet/claude-flow
- Fit: Low — orchestrates TDD phases (red/green/refactor) as separate agents, but applies TDD globally, not per-task
- Maturity: Medium — documented wiki, active repo
- Integration: None — different architecture (Claude Flow runtime vs markdown commands)
- Risk: N/A
- Notes: Confirms the TDD-as-agent-phases pattern exists in ecosystem. Does NOT solve per-WU annotation.

**[2] Adversarial Planning for Spec-Driven Development** — dev.to/marcosomma
- Fit: Low — describes adversarial spec review patterns similar to claude-sail's debate mode
- Maturity: Medium — blog post with conceptual framework
- Integration: None — conceptual, not a library
- Notes: Validates the multi-perspective adversarial approach. No concept of "default mode selection" — uses a single fixed approach.

**[3] Adversarial Code Review (ASDLC.io pattern)** — asdlc.io/patterns/adversarial-code-review
- Fit: Low — Builder/Critic agent pattern for code review, not spec review
- Maturity: Medium — documented pattern
- Integration: None — different phase (code review vs spec challenge)
- Notes: "Council mode spawns disposable lenses — task-scoped perspectives selected based on what could break." This is conceptually similar to family mode's role-based agents.

**[4] awesome-agent-skills TDD** — github.com/kodustech/awesome-agent-skills
- Fit: Low — TDD enforcement as a global agent skill, not per-task annotation
- Maturity: Medium — curated list
- Integration: None — skill format, not WU annotation
- Notes: Confirms TDD-as-skill is common pattern. No granularity below "entire session."

## Recommendation: Build

**Rationale:** No existing solution addresses either problem at the right granularity. The ecosystem has:
- TDD agent orchestration (global, not per-WU)
- Adversarial review patterns (fixed mode, not configurable defaults)
- Multi-agent review (but not generational/family architecture)

Claude-sail's specific innovations — work-graph-level TDD annotation and the family mode generational debate — are novel in this space. The changes are internal configuration/architecture decisions that can only be solved by modifying the toolkit's own markdown commands.

**Patterns worth borrowing:**
- The "council mode" concept (ASDLC.io) of spawning task-scoped perspectives rather than permanent personas — validates family mode's per-stage agent instantiation
- The Builder/Critic separation — reinforces that TDD enforcement should be at the atomic execution level, not a global session flag

## Sources
- [claude-flow TDD](https://github.com/ruvnet/claude-flow/wiki/CLAUDE-MD-TDD)
- [Adversarial Planning for Spec Driven Development](https://dev.to/marcosomma/adversarial-planning-for-spec-driven-development-4c3n)
- [Adversarial Code Review pattern](https://asdlc.io/patterns/adversarial-code-review/)
- [awesome-agent-skills](https://github.com/kodustech/awesome-agent-skills)
