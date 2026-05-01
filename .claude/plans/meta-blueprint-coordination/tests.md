# Test Specifications: Meta-Blueprint Coordination

Generated spec-blind from spec.md (rev 1.2) before implementation.

## Category A: File Count Validation (test.sh Category 3)

These are automatable in test.sh.

### T-A1: Command count update
- **Pre-condition:** New `/link-blueprint` command created
- **Expected:** CMD_EXPECTED increases from 63 → 64
- **Verification:** `ls commands/*.md | grep -v README | wc -l` equals 64

### T-A2: link-blueprint frontmatter validation
- **Pre-condition:** `commands/link-blueprint.md` exists
- **Expected:** File has `description:` in YAML frontmatter
- **Verification:** `grep -q "^description:" commands/link-blueprint.md`

### T-A3: link-blueprint enforcement tier
- **Pre-condition:** `commands/link-blueprint.md` exists
- **Expected:** Description uses "Use when" language (Utility tier, not Safety-Critical)
- **Verification:** Description does not contain escape-hatch language (consider, might, optionally)

## Category B: Schema Validation (test.sh Category 6)

### T-B1: PLANNING-STORAGE.md current_stage type corrected
- **Pre-condition:** W2 complete
- **Expected:** `current_stage` type is `"string"` (not `"integer"`)
- **Verification:** grep PLANNING-STORAGE.md for `current_stage` type definition

### T-B2: debrief stage in schema
- **Pre-condition:** W2 complete
- **Expected:** `stages` properties include `"debrief"` with `"skippable": false`
- **Verification:** grep PLANNING-STORAGE.md for `debrief` in stages section

### T-B3: state.json schema includes new root fields
- **Pre-condition:** W2 complete
- **Expected:** Schema includes `parent`, `meta_units`, `completed`, `completed_at` as optional properties
- **Verification:** grep PLANNING-STORAGE.md for each field name in properties section

### T-B4: commits.jsonl schema documented
- **Pre-condition:** W2 complete
- **Expected:** File naming conventions table includes `commits.jsonl` with schema description
- **Verification:** grep PLANNING-STORAGE.md for `commits.jsonl`

### T-B5: debrief.md in artifact table
- **Pre-condition:** W2 complete
- **Expected:** File naming conventions table includes `debrief.md`
- **Verification:** grep PLANNING-STORAGE.md for `debrief.md`

## Category C: Blueprint.md Integration (manual/behavioral)

### T-C1: Stage count references
- **Pre-condition:** W1 + W6 complete
- **Expected:** All "7 stages", "Stage 7 of 7", "of 7" references updated to 8
- **Verification:** `grep -rn "7 stages\|Stage 7 of 7\|of 7\b" commands/blueprint.md` returns 0 matches (or only valid references)

### T-C2: Debrief stage appears in blueprint overview
- **Pre-condition:** W1 complete
- **Expected:** Blueprint overview section lists Stage 8: Debrief
- **Verification:** grep blueprint.md for "Stage 8" or "Debrief"

### T-C3: Debrief is non-skippable in stage table
- **Pre-condition:** W1 complete
- **Expected:** Stage execution table shows debrief with "No" for skip
- **Verification:** Manual inspection of stage table in blueprint.md

### T-C4: Execute completion triggers debrief prompt
- **Pre-condition:** W1 complete
- **Expected:** Stage 7 completion section includes debrief transition prompt
- **Verification:** grep blueprint.md for "Debrief pending" or "Stage 8"

### T-C5: Debrief prerequisites documented
- **Pre-condition:** W1 complete
- **Expected:** Debrief section states execute must be complete as prerequisite
- **Verification:** grep blueprint.md for "execute" + "complete" in debrief section

### T-C6: Session recovery for debrief
- **Pre-condition:** W1 complete
- **Expected:** Resume logic includes check for execute complete + debrief pending
- **Verification:** grep blueprint.md for debrief-pending recovery logic

## Category D: /link-blueprint Command (manual/behavioral)

### T-D1: Link creates bidirectional references
- **Pre-condition:** Two blueprints exist in .claude/plans/
- **Action:** Run `/link-blueprint child --parent parent`
- **Expected:** Child state.json has `parent` field, parent state.json has `meta_units.child` entry
- **Verification:** Read both state.json files after link

### T-D2: Link validates both blueprints exist
- **Action:** `/link-blueprint nonexistent --parent also-nonexistent`
- **Expected:** Error message, no state.json mutations
- **Verification:** Neither directory modified

### T-D3: Link prevents self-reference
- **Action:** `/link-blueprint foo --parent foo`
- **Expected:** Error message, no mutation
- **Verification:** state.json unchanged

### T-D4: Link prevents empty name
- **Action:** `/link-blueprint --parent parent` (no child name)
- **Expected:** Error message about missing name
- **Verification:** No phantom "" key in parent's meta_units

### T-D5: Link blocks parent-is-complete
- **Pre-condition:** Parent has `completed: true`
- **Action:** `/link-blueprint child --parent completed-parent`
- **Expected:** Block with error about completed parent
- **Verification:** No meta_units entry created

### T-D6: Link warns child-is-complete
- **Pre-condition:** Child has `completed: true`
- **Action:** `/link-blueprint completed-child --parent parent`
- **Expected:** Warning displayed but link proceeds
- **Verification:** Both state.json files updated

### T-D7: Show displays linked children
- **Pre-condition:** Parent has 2+ linked children
- **Action:** `/link-blueprint --show parent`
- **Expected:** Table showing all children with status
- **Verification:** All children listed with correct status

### T-D8: Show handles no children
- **Pre-condition:** Blueprint has no `meta_units`
- **Action:** `/link-blueprint --show solo-blueprint`
- **Expected:** "No linked children" message
- **Verification:** No error, clean message

### T-D9: Unlink blocks when completed
- **Pre-condition:** Child has `completed: true`
- **Action:** `/link-blueprint child --unlink`
- **Expected:** Block with message about completed blueprints
- **Verification:** Both state.json files unchanged

### T-D10: Unlink with --force on completed
- **Pre-condition:** Child has `completed: true`
- **Action:** `/link-blueprint child --unlink --force`
- **Expected:** Unlink proceeds, logged
- **Verification:** Both references removed

## Category E: Commit Signal (manual/behavioral)

### T-E1: No prompt when SAIL_BLUEPRINT_ACTIVE unset
- **Pre-condition:** No SAIL_BLUEPRINT_ACTIVE environment variable
- **Action:** Run commit
- **Expected:** No blueprint-related prompt, zero friction
- **Verification:** Commit completes without blueprint mention

### T-E2: Append to commits.jsonl when flag set
- **Pre-condition:** `SAIL_BLUEPRINT_ACTIVE=my-blueprint`, blueprint directory exists
- **Action:** Run commit
- **Expected:** New line appended to commits.jsonl with hash, message, timestamp
- **Verification:** Read commits.jsonl, last line has correct hash

### T-E3: Ghost directory prevention
- **Pre-condition:** `SAIL_BLUEPRINT_ACTIVE=nonexistent-blueprint`
- **Action:** Run commit
- **Expected:** Warning logged, no directory created, no commits.jsonl written
- **Verification:** No `.claude/plans/nonexistent-blueprint/` directory

## Category F: Debrief Flow (behavioral eval)

### T-F1: Debrief reads commits.jsonl for ship references
- **Pre-condition:** Blueprint with commits.jsonl containing 3 entries
- **Action:** Enter debrief stage
- **Expected:** Ship reference step auto-populates with 3 commit hashes
- **Verification:** Debrief output shows the hashes from commits.jsonl

### T-F2: Debrief falls back when commits.jsonl missing
- **Pre-condition:** Blueprint with no commits.jsonl
- **Action:** Enter debrief stage
- **Expected:** Ship reference step prompts user for manual entry
- **Verification:** No error, manual prompt appears

### T-F3: Debrief reads spec.diff.md for spec delta
- **Pre-condition:** Blueprint with spec.diff.md from regression
- **Action:** Enter debrief stage
- **Expected:** Spec delta step presents diff summary
- **Verification:** Diff content matches spec.diff.md

### T-F4: Debrief sets completed:true only after all steps
- **Pre-condition:** Blueprint at debrief stage
- **Action:** Complete all debrief steps
- **Expected:** state.json has `completed: true` and `stages.debrief.status: "complete"`
- **Verification:** Read state.json after debrief

### T-F5: Debrief updates parent meta_units for linked blueprint
- **Pre-condition:** Linked child blueprint at debrief
- **Action:** Complete debrief
- **Expected:** Parent's meta_units shows child as complete with ship_commit and discoveries
- **Verification:** Read parent state.json

### T-F6: Debrief repairs half-linked state
- **Pre-condition:** Child has parent ref, but parent's meta_units is missing child entry
- **Action:** Enter debrief, reach META UPDATE step
- **Expected:** Half-linked state detected, repair offered, then parent updated
- **Verification:** Parent meta_units now includes child entry

## Test Count Summary

| Category | Count | Automatable |
|----------|-------|-------------|
| A: File counts | 3 | Yes (test.sh) |
| B: Schema validation | 5 | Yes (grep-based) |
| C: Blueprint integration | 6 | Partial (grep) |
| D: Link-blueprint | 10 | Behavioral |
| E: Commit signal | 3 | Behavioral |
| F: Debrief flow | 6 | Behavioral |
| **Total** | **33** | |

Categories A-B: automatable in test.sh (~8 new checks).
Categories C-F: behavioral — require manual verification or eval fixtures.
