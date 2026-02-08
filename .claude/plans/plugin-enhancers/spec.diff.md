# Specification Revision History

## Revision 0 (initial)
- Created: 2026-02-07T20:28:00Z
- Sections: Summary, Design Decisions, Components 1-7, Preservation Contract, Work Units, Failure Modes
- Work Units: 8 (W1-W8)
- Scope: All 7 commands modified simultaneously

## Revision 0 -> Revision 1
- Trigger: Debate chain REGRESS verdict — 2 critical findings (F1: detection mechanism undefined, F2: registry maintenance unsustainable)
- Date: 2026-02-07T20:35:00Z
- Sections added:
  - Detection via installed_plugins.json (addresses F1)
  - Registry Maintenance Model (addresses F2)
  - Phased Rollout (addresses F10)
  - Schema Changes with backward compatibility (addresses F4)
  - Execution Rollback Protocol (addresses M1, Phase 2)
  - Context Handoff Protocol (addresses M2, Phase 2)
  - W1-review Gate (addresses F8)
  - Logging Protocol (addresses F9)
- Sections modified:
  - Design Decisions: added 3 new subsections (detection, maintenance, renamed deps heading)
  - Component 1 (Registry): expanded with 5 explicit sections (detection protocol, capability slots, plugin-to-slot mapping, graceful degradation rules, plugin results format)
  - Component 2 (Blueprint Stage 5): reduced scope to Phase 1 (review only, removed Stage 7 execution engines)
  - Component 5 (Documentation): added GETTING_STARTED.md to update list
  - Preservation Contract: added item 8 (canonical detection mechanism)
  - Work Units: reduced from 8 to 6 (Phase 1 scope), added W1-review gate
  - Failure Modes: expanded from 6 to 15 scenarios across 4 categories
- Sections removed:
  - Component 6 (test.md modification) — moved to Phase 3
  - Component 7 (bootstrap-project modification) — moved to Phase 3
  - describe-change technology detection — moved to Phase 2
  - Blueprint Stage 7 execution engines — moved to Phase 2
- Sections unchanged:
  - Summary (minor update to add phased note)
  - Opt-In with Smart Defaults design decision
  - Single Registry File design decision
- Adversarial findings addressed: 16/18 (2 low findings deferred: M5, M7)
- Work units affected: All units rewritten for Phase 1 scope
