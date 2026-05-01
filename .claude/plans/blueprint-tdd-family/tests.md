# Spec-Blind Test Assertions

Generated from spec.md without reading any implementation files.

## Category A: TDD Removal from Stage 7

A1. `grep -c "TDD-enforced" commands/blueprint.md` = 0
    (TDD is no longer a Stage 7 option name)

A2. The Stage 7 completion block in blueprint.md contains exactly 2 implementation options
    (Sequential and Parallel — Guided Walkthrough is deferred)

A3. `grep -c "tdd.*plan-context" commands/blueprint.md` = 0 in the Stage 7 completion block
    (The old `--plan-context` Stage 7 wiring is removed)

A4. The Stage 7 completion block includes a "WUs with tdd:true:" summary line

## Category B: TDD as WU Property

B1. `grep "tdd" docs/PLANNING-STORAGE.md` returns matches in the work_unit schema
    (The `tdd` field is defined in the work-graph.json schema)

B2. PLANNING-STORAGE.md describes `tdd` as a boolean type, not string

B3. PLANNING-STORAGE.md notes that absent `tdd` defaults to `false`

B4. `grep -c "tdd" commands/spec-change.md` > 0
    (The TDD annotation heuristic exists in spec-change.md)

B5. spec-change.md contains the module characteristic heuristic table
    (mapping I/O boundary, error contract, etc. to tdd: true/false)

B6. `grep "tdd.*true" commands/delegate.md` returns matches in Step 3
    (Delegate reads tdd annotation from work-graph.json)

B7. delegate.md's TDD injection references work-graph.json, not a flag or global setting

B8. delegate.md specifies the fallback: missing tdd field or missing work-graph.json = standard implementation

B9. `grep "RED.*GREEN.*REFACTOR\|test-driven" commands/delegate.md` returns matches
    (The TDD instructions template exists in the implementer prompt section)

B10. tdd.md mentions WU-level invocation or work-unit-level usage

## Category C: Default Challenge Mode

C1. `grep -ri "debate.*default\|default.*debate" commands/ docs/ README.md .claude/CLAUDE.md` returns 0 matches
    (No reference to debate as the default)

C2. `grep -ri "family.*default\|default.*family" commands/ docs/` returns matches
    (Family is referenced as the default)

C3. blueprint.md frontmatter argument description says "family" as default, not "debate"

C4. BLUEPRINT-MODES.md comparison table marks family as "(Default)", not debate

C5. BLUEPRINT-MODES.md FAQ has an entry explaining why family is the default

C6. README.md example shows `# family mode (default)` not `# debate mode (default)`

C7. `grep "challenge_mode.*vanilla" commands/blueprint.md` still returns matches
    (Pre-v2 migration still defaults to vanilla — NOT affected by default change)

C8. blueprint.md resume logic explicitly reads challenge_mode from state.json

## Category D: Family Mode Scaffolding

D1. `grep "steelman\|strongest possible case" commands/blueprint.md` returns matches
    (Child-Defend uses steelman framing)

D2. `grep -c "genuinely believes" commands/blueprint.md` = 0
    (Old sycophantic framing removed from Child-Defend)

D3. blueprint.md has a complexity-adaptive rounds table with Simple/Medium/Complex signals

D4. The complexity signal uses WU count and WU complexity distribution (no "risk_flags")

D5. `grep -c "risk_flag" commands/blueprint.md` = 0
    (risk_flags removed from complexity signal)

D6. blueprint.md Elder Council section has graceful degradation for vault-unavailable
    ("draw on general software engineering principles" or equivalent)

D7. blueprint.md timeout section does NOT have a per-round hard timeout (10min removed)

D8. blueprint.md timeout section does NOT have a total hard timeout (25min removed)

D9. blueprint.md retains per-agent liveness check (3min)

D10. blueprint.md describes progress checks between agents (output verification)

## Category E: Documentation & Consistency

E1. `grep "family" docs/BLUEPRINT-MODES.md` appears more frequently than `grep "debate"`
    (Family is now the primary mode in docs)

E2. BLUEPRINT-MODES.md comparison table has a "Token Cost" or cost-related row

E3. README.md Stage 7 references are updated (no "TDD-enforced" option)

E4. .claude/CLAUDE.md challenge mode references say family, not debate

E5. `bash test.sh` passes with 0 failures

## Category F: Backward Compatibility

F1. work-graph.json schema change is additive only — existing required fields unchanged

F2. state.json schema is additive only — no fields removed

F3. The `--challenge=debate` flag is still documented and accepted

F4. The `--challenge=vanilla` flag is still documented and accepted

F5. Pre-v2 migration block in blueprint.md is unchanged (still defaults to vanilla)
