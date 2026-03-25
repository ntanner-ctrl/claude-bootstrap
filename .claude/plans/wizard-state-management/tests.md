# Test Specifications: wizard-state-management

Generated spec-blind from spec.md + adversarial findings. These tests verify the feature works correctly WITHOUT knowing implementation details.

## Category A: Schema Validation (test.sh Category 6)

### A1: Wizard state.json is valid JSON
```
GIVEN: Any file matching .claude/wizards/*/state.json exists
WHEN: Parsed with jq
THEN: Parse succeeds (exit 0)
```

### A2: Wizard state.json has required fields
```
GIVEN: A wizard state.json exists
WHEN: Checked for required schema fields
THEN: Contains all of: wizard, version, session_id, status, current_step, steps, created_at, updated_at
```

### A3: Wizard state.json status enum valid
```
GIVEN: A wizard state.json with top-level status field
WHEN: Status is read
THEN: Value is one of: active, complete, abandoned, error
```

### A4: Wizard state.json step status enum valid
```
GIVEN: A wizard state.json with steps object
WHEN: Each step's status is read
THEN: Value is one of: pending, active, complete, skipped, error
```

### A5: Version field is exactly 1
```
GIVEN: A wizard state.json
WHEN: version field is read
THEN: Value is integer 1
```

## Category B: Structural Enforcement (test.sh Category 4)

### B1: All wizard commands reference state management
```
GIVEN: commands/{prism,review,test,clarify}.md exist
WHEN: Searched for wizard state references
THEN: Each contains "wizards/" or ".claude/wizards"
```

### B2: All wizard commands have stage progression display
```
GIVEN: commands/{prism,review,test,clarify}.md exist
WHEN: Searched for progression markers
THEN: Each contains "✓" AND "→" AND "○" (the stage display characters)
```

### B3: All wizard commands have resume protocol
```
GIVEN: commands/{prism,review,test,clarify}.md exist
WHEN: Searched for resume references
THEN: Each contains "Resume" AND "Abandon" (the resume prompt choices)
```

### B4: WIZARD-STATE.md documentation exists
```
GIVEN: Implementation complete
WHEN: docs/WIZARD-STATE.md checked
THEN: File exists and contains JSON schema definition
```

## Category C: Success Criteria Verification

### C1: Resume produces valid context under 1000 tokens (prism)
```
GIVEN: A prism state.json with 7 completed steps, each with output_summary
WHEN: All output_summaries are concatenated with context object
THEN: Total token count < 1000 tokens
```

### C2: Resume produces valid context under 500 tokens (short wizards)
```
GIVEN: A clarify/review/test state.json with completed steps
WHEN: All output_summaries concatenated with context
THEN: Total token count < 500 tokens
```

### C3: Single active session enforced
```
GIVEN: An active wizard session exists
WHEN: The same wizard type is re-invoked
THEN: User is prompted with Resume/Abandon choice (not silently started)
```

### C4: Completed session does not prompt resume
```
GIVEN: A wizard session with status: "complete"
WHEN: The same wizard type is invoked
THEN: New session created without prompting
```

### C5: Abandoned session does not prompt resume
```
GIVEN: A wizard session with status: "abandoned"
WHEN: The same wizard type is invoked
THEN: New session created without prompting
```

### C6: Error session shows error-specific prompt
```
GIVEN: A wizard session with status: "error"
WHEN: The same wizard type is invoked
THEN: Prompt mentions the error and offers "Resume from last complete step" / "Abandon"
```

## Category D: Adversarial Finding Coverage

### D1: output_summary content contracts (F1/G1)
```
GIVEN: A prism wizard completes wave1 step
WHEN: output_summary is written
THEN: Summary contains issue count per paradigm AND top critical findings
      (NOT just "12 issues found")
```

### D2: Partial-substep resume (G2)
```
GIVEN: A prism state.json with wave1 step active, 4/6 substeps complete
WHEN: Wizard resumes
THEN: Only the 2 pending substeps are re-run (not all 6)
```

### D3: current_step null on completion (G5)
```
GIVEN: A wizard completes all steps
WHEN: state.json is written at completion
THEN: current_step is null AND status is "complete"
```

### D4: Positive resumability check (A3)
```
GIVEN: A state.json with status: "error"
WHEN: Resume logic evaluates resumability
THEN: status == "active" check does NOT match "error"
      (error is handled distinctly, not treated as resumable)
```

### D5: Session ID has sub-minute precision (A1)
```
GIVEN: A new wizard session is created
WHEN: Session ID is generated
THEN: ID includes seconds or random suffix (not just HHMM)
```

### D6: Resume prompt shows session age (A5)
```
GIVEN: An active wizard session from 3 days ago
WHEN: Resume prompt is displayed
THEN: Prompt includes session age or created_at timestamp
```

### D7: Vault checkpoint is advisory (spec D5)
```
GIVEN: Vault is not configured or unavailable
WHEN: A vault checkpoint moment is reached
THEN: Wizard continues without error (fail-open)
```

### D8: .claude/wizards/ auto-created (spec Failure Modes)
```
GIVEN: .claude/wizards/ directory does not exist
WHEN: A wizard is invoked
THEN: Directory is created (mkdir -p equivalent) without error
```

## Category E: Pre-Mortem Coverage

### E1: Resume freshness heuristic (PM6)
```
GIVEN: An active session older than 24 hours (prism) or 4 hours (short wizard)
WHEN: Resume prompt is displayed
THEN: Staleness is prominently noted to the user
```

### E2: Resume quality baseline (PM1/PM3)
```
GIVEN: A prism wizard resumed from wave1
WHEN: The architecture review step runs after resume
THEN: The review references constraints from the wave1 output_summary
      (NOT starting from scratch as if wave1 never happened)
```

## Category F: Cleanup Behavior

### F1: (Conditional on A2 decision — add W9)
```
GIVEN: 3 completed wizard sessions older than 7 days
WHEN: A new wizard session is created
THEN: Old sessions are moved to _archive/ subdirectory
```

### F2: (Conditional on A2 decision — withdraw promise)
```
GIVEN: Multiple wizard sessions exist (some stale)
WHEN: Active session detection runs
THEN: Most-recent session by timestamp is selected (not arbitrary)
```

---

## Test Implementation Notes

- **Categories A-B** are automatable in `test.sh` as structural checks
- **Categories C-F** are behavioral and require manual verification or eval fixtures
- **D1-D2** are the highest-value tests — they validate the load-bearing F1/G1/G2 findings
- **F1/F2 are mutually exclusive** — which to implement depends on the A2 cleanup decision
