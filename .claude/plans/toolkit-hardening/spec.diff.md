# Specification Revision History

## Revision 1 (initial)
- Created: 2026-03-10
- Components: 6 (Compaction Guardian, Ambiguity Gate, Cognitive Traps, Failure Counter, Wonder/Reflect, Knowledge Maturation)
- Work Units: 15 files across 4 phases

## Revision 1 → Revision 2
- Trigger: Debate stage regression — 2 critical findings (F2/M1: guardian livelock)
- Date: 2026-03-10

### Sections Added
- Component 1: Guardian Exemption List (F2/M1 fix)
- Component 1: Checkpoint Completion Signal (M3 fix)
- Component 1: Signal File TTL and Cleanup (F10 fix)
- Component 1: Statusline Integration Verification (M2 fix)
- Work Graph: blueprint.md Atomic Edit Pass (F9 fix)
- Work Graph: Phase D Integration Test (M4 fix)

### Sections Modified
- Component 1: Guardian flow diagram — added exemption check as first branch
- Component 1: PPID fallback — replaced fixed path with user+directory hash discriminator (F1)
- Component 1: Checkpoint JSON — replaced free-text `key_context_summary` with structured `key_context` object (F7)
- Component 1: Acceptance criteria — expanded from 6 to 10 items
- Component 2: Scoring prompt — added calibration examples at each level for all 3 dimensions (F4)
- Component 2: Light path — changed from "skip" to "shortened gate (Goal Clarity only)" (M5)
- Component 4: Pattern matching — removed broad catchall, enumerated specific patterns only (F3)
- Component 5: Integration points — made Empirica export mandatory loop, vault export mandatory (F6)
- Component 6: Step 2 — added independence assessment and required user acknowledgment (F5)
- Work Graph: Critical path — included Component 3 in atomic pass

### Sections Unchanged
- Component 3: Cognitive Trap Tables (F8 accepted as-is — compliance layer, not enforcement)
- Component 1: Subagent Lifeboat Strategy (confirmed valid by defender)
- Component 1: Threshold Rationale (65%/75%/85% confirmed)
- All component Problem statements
- Phase structure (A/B/C/D)

### Adversarial Findings Addressed: 14/15
- F8 (traps unenforceable) accepted — intentionally behavioral, not deterministic

## Revision 2 → Revision 2.1 (Edge Case Patches)
- Trigger: Stage 4 Edge Cases — PASS_WITH_NOTES (0 critical, 2 medium, 5 low)
- Date: 2026-03-10

### Sections Modified
- Component 1: Statusline description — corrected "300ms poll" to "event-driven" (B8)
- Component 1: Cleanup threshold — changed `< 65` to `< 75` with rationale (B2)
- Component 1: Checkpoint JSON — added atomic write requirement (B7)
- Component 4: Acceptance criterion 3 — clarified Red blocks matched test/build only, not all Bash (B1)
- Component 4: /debug reset — replaced state-index.json with signal file pattern (B5)

### Sections Added
- Component 4: Known Limitations section (B3 compound commands, B4 piped commands, B6 first-call gap)

### Sections Unchanged
- All component Problem statements
- All other acceptance criteria
- Work graph and phase structure
- Components 2, 3, 5, 6 (no edge case findings)

### Edge Case Findings Addressed: 8/8
- 5 required spec updates applied (B1, B2, B5, B7, B8)
- 3 documented as known limitations (B3, B4, B6)
