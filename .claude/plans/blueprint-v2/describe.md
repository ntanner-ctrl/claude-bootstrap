# Blueprint v2: Change Description

## What
Major enhancement to the claude-bootstrap planning workflow:
- Rename `/plan` → `/blueprint`, `/plans` → `/blueprints`
- Three challenge modes: vanilla (original), debate (default), team (experimental)
- Feedback loops with stage regression
- Token-dense manifest storage (manifest.json)
- Pre-mortem analysis stage (4.5)
- Confidence scoring with Empirica integration
- Parallelization-aware work graphs
- Spec diff tracking across revisions

## Steps
1. Rename commands and update all cross-references
2. Implement debate mode (three-round sequential critique chain)
3. Implement team mode (agent team, experimental fallback)
4. Add pre-mortem stage
5. Add regression/feedback loop mechanics
6. Define and enforce manifest.json format
7. Add work-graph.json for parallelization
8. Integrate Empirica for confidence scoring
9. Add spec diff tracking
10. Write documentation (BLUEPRINT-MODES.md, update all READMEs)

## Risk Flags
- **Scope**: Large — touches 37+ files, 2 hooks, 3+ doc files, and the core workflow
- **Behavioral**: Changes default behavior (debate mode replaces vanilla as default)
- **Integration**: Empirica enforcement creates a new mandatory dependency during planning
- **Experimental**: Team mode depends on experimental Claude Code feature

## Triage
- Steps: 10
- Risk flags: 4 (scope, behavioral, integration, experimental)
- **Path: Full** — All planning stages recommended

## Notes
Brainstormed extensively in conversation on 2026-02-07. All design decisions confirmed by user before specification. The storage path `.claude/plans/` intentionally kept unchanged despite command rename.
