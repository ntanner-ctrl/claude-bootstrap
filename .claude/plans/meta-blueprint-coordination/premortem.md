# Pre-Mortem: Meta-Blueprint Coordination

Premise: April 8, 2026. Feature shipped two weeks ago. Something went wrong.

## Findings

### PM-1: Context exhaustion confabulates debrief data (NEW — Critical)
Full-path family blueprint consumes most context by Stage 8. Auto-detection features (commits.jsonl read, spec.diff.md diff) confabulate when actual content has been compacted. Wrong data propagates to parent meta_units.

**Mitigation added:** Context-aware debrief — prefer manual input when session is heavy (>5 stages).

### PM-2: test.sh count drift after install (COVERED)
W5 explicitly handles command count updates.

### PM-3: Debrief prompt buried in completion output (NEW — High)
Stage 7 completion ceremony is ~40 lines of implementation options. Debrief transition prompt is lost in the noise. Users scroll past, start coding, never debrief.

**Mitigation added:** Debrief prompt visually separated from completion ceremony, appears AFTER implementation options with clear break.

### PM-4: Half-linked state undetected until debrief fails (NEW — High)
Session crash during /link-blueprint leaves half-linked state. User doesn't run --show. Debrief's META UPDATE silently fails weeks later.

**Mitigation added:** Debrief step 7 verifies bidirectional consistency before attempting parent update. Repairs half-linked state inline.

### PM-5: Hardcoded "7 stages" references across codebase (NEW — Medium)
README.md, CLAUDE.md, blueprint.md, and inline comments all say "7 stages" or "Stage 7 of 7". Users confused by unexpected Stage 8.

**Mitigation added:** W6 includes grep task for all "7 stages", "of 7" references.

## Summary

| Status | Count |
|--------|-------|
| NEW | 4 |
| COVERED | 1 |
| Overlap ratio | 0.20 (low — confirms pre-mortem surfaces different failure class) |
