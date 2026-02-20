# Bootstrap Enforcement Upgrade - Master Roadmap

## Triage

**Change Type:** Program of Work (multiple independent tracks)
**Recommended Path:** Custom - individual plans per track
**Risk Level:** Medium-High (architectural changes to core behavior)

## Problem Statement

Analysis of competing projects (Superpowers, Turkey-Build, ZacheryGlass/.claude) revealed that claude-bootstrap has **comprehensive content** but **weak enforcement**. We have excellent planning workflows, adversarial pipelines, and security layers - but Claude doesn't reliably use them because:

1. No bootstrap mechanism teaches Claude it has these powers
2. Command descriptions summarize instead of triggering
3. No consequences for skipping workflows
4. No subagent isolation for implementation work

## Program Structure

This work is organized into **5 tracks** with different timelines and complexity:

### Track A: Quick Wins (1-2 sessions)
Priorities 1, 5, 6, 7 bundled together.

| Priority | What | Effort |
|----------|------|--------|
| P1 | Bootstrap Mechanism | Low |
| P5 | Two-Stage Review | Medium |
| P6 | Quality Gate | Low |
| P7 | Protect CLAUDE.md Hook | Low |

### Track B: Enforcement Language Audit (Priority 2)
**Dedicated planning + implementation session required**

- Audit all 30+ command descriptions
- Rewrite from summaries → trigger conditions
- Apply Cialdini-style persuasion psychology
- Pressure-test compliance

### Track C: TDD Enforcement (Priority 3)
**Dedicated planning + implementation session required**

- Create `/tdd` command with teeth
- Implement test-first verification
- Add consequence mechanism (code deletion in aggressive mode)
- Integrate with existing `/test` workflow

### Track D: Subagent Orchestration (Priority 4)
**Most complex - may need multiple sessions**

- Research Claude Code's subagent API capabilities
- Design orchestration model (coordinator + workers)
- Implement fresh-context spawning
- Add two-stage review routing
- Handle failure/retry scenarios

### Track E: Exploratory
| Item | Nature |
|------|--------|
| P8: Self-Improvement | Experimental - `/write-command` meta-skill |
| Maturity Models | Research - compare our assessment vs greenfield/iteration |

## Dependencies

```
Track A (Quick Wins)
  └── P1 Bootstrap → enables all other enforcement

Track B (Language Audit)
  └── Should happen AFTER bootstrap is in place

Track C (TDD)
  └── Independent, but benefits from enforcement language patterns

Track D (Subagents)
  └── Partially blocked until we understand Claude Code's subagent capabilities
  └── Two-stage review (P5) should be designed first

Track E (Exploratory)
  └── No blockers, can proceed in parallel
```

## Recommended Execution Order

```
Week 1: Track A (Quick Wins)
        ├── Bootstrap mechanism (P1) - FIRST
        ├── Protect CLAUDE.md (P7)
        ├── Quality Gate (P6)
        └── Two-Stage Review spec (P5)

Week 2: Track B (Enforcement Language Audit)
        └── Full audit and rewrite

Week 3: Track C (TDD Enforcement)
        └── Full planning and implementation

Week 4+: Track D (Subagent Orchestration)
         └── Research → Design → Implement

Parallel: Track E (Exploratory)
          └── As time permits
```

## Success Criteria

The program is successful when:

1. **Bootstrap works**: New Claude sessions automatically know commands exist
2. **Commands are triggered**: Description audit shows MUST language throughout
3. **TDD is enforced**: Cannot write implementation before tests
4. **Reviews are split**: Spec compliance and code quality are separate passes
5. **Quality gates block**: Below-threshold work cannot proceed
6. **Subagents isolate**: Implementation work happens in fresh contexts

## Risk Factors

| Risk | Mitigation |
|------|------------|
| Bootstrap injection might not work with Claude Code's architecture | Research session-start hooks first |
| Enforcement language might make commands feel hostile | Balance MUST with helpful context |
| TDD deletion might be too aggressive | Make it opt-in/configurable |
| Subagent API might have limitations we don't know about | Research before committing to design |

---

**Next:** Create individual plans for Tracks B, C, D
**Plan file:** `.claude/plans/bootstrap-enforcement-upgrade/`
