# Specification: wizard-standardization

## Goal

Standardize all Workflow Wizard commands to match the structural rigor established by `/blueprint` and `/prism`. Fix pre-mortem skippability in blueprint. Update README categorization.

## Wizard Paradigm Checklist

> **Canonical reference.** This table is the authoritative definition of what constitutes a Workflow Wizard. Implementers creating or verifying wizard commands should check against this checklist. After execution, a copy will be promoted to `docs/WIZARD-PARADIGM.md` for discoverability.

The following structural elements define a Workflow Wizard (derived from blueprint + prism):

**Scope distinction for elements 5 and 6:**
- **Failure Modes** = recoverable runtime errors (what can go wrong and how to recover). Schema: `What Could Fail | Detection | Recovery` (matching prism.md).
- **Known Limitations** = permanent constraints on what the command can or cannot assess (scope boundaries, not error states).

| # | Element | Blueprint | Prism | Required For All |
|---|---------|-----------|-------|-----------------|
| 1 | Cognitive Traps section | ✓ | ✗ | Yes — prevents rationalized skipping |
| 2 | Structured Overview (stage progression) | ✓ | ✓ | Yes |
| 3 | Stage headers (`━━━` format) | ✓ | ✓ | Yes |
| 4 | Progress narration between stages | ✓ | ✓ | Yes |
| 5 | Failure Modes table | ✓ (implicit via HALT/regression) | ✓ (explicit table) | Yes — explicit table |
| 6 | Known Limitations section | ✗ | ✓ | Yes |
| 7 | Vault awareness (check for prior work) | ✓ | ✓ | Yes |
| 8 | Integration section | ✓ | ✓ | Yes (already present in all) |
| 9 | Structured output format | ✓ | ✓ | Yes (already present in all) |
| 10 | Skip handling with reason logging | ✓ | N/A (no skippable stages) | Where applicable |

## Audit Results

### `/clarify`

| # | Element | Present | Gap |
|---|---------|---------|-----|
| 1 | Cognitive Traps | ✗ | Add |
| 2 | Structured Overview | ✓ | — |
| 3 | Stage headers | Partial (summary only) | Add to each step |
| 4 | Progress narration | ✗ | Add between steps |
| 5 | Failure Modes | ✗ | Add table |
| 6 | Known Limitations | ✗ | Add section |
| 7 | Vault awareness | ✗ | Add — check for prior brainstorms/decisions on topic |
| 8 | Integration | ✓ | — |
| 9 | Output format | ✓ | — |
| 10 | Skip handling | ✓ (conditional steps) | — |

### `/review`

| # | Element | Present | Gap |
|---|---------|---------|-----|
| 1 | Cognitive Traps | ✗ | Add |
| 2 | Structured Overview | ✓ | — |
| 3 | Stage headers | ✓ | Fix numbering ("Stage 1 of 4" but has 5 stages) |
| 4 | Progress narration | Partial | Enhance between stages |
| 5 | Failure Modes | ✗ | Add table |
| 6 | Known Limitations | ✗ | Add section |
| 7 | Vault awareness | ✗ | Add — check for prior reviews of same target |
| 8 | Integration | ✓ | — |
| 9 | Output format | ✓ | — |
| 10 | Skip handling | ✓ | — |

### `/test`

| # | Element | Present | Gap |
|---|---------|---------|-----|
| 1 | Cognitive Traps | ✓ | — (already present, well done) |
| 2 | Structured Overview | ✓ | — |
| 3 | Stage headers | ✓ | — |
| 4 | Progress narration | ✗ | Add between stages |
| 5 | Failure Modes | ✗ | Add table |
| 6 | Known Limitations | ✗ | Add section |
| 7 | Vault awareness | ✗ | Add — check for prior test specs on same feature |
| 8 | Integration | ✓ | — |
| 9 | Output format | ✓ | — |
| 10 | Skip handling | ✓ (TDD pre-check) | — |

### `/prism`

| # | Element | Present | Gap |
|---|---------|---------|-----|
| 1 | Cognitive Traps | ✗ | Add |
| 2 | Structured Overview | ✓ | Stage 0 + Waves 1-2 + Synthesis + Report |
| 3 | Stage headers | ✓ | `━━━ Wave 1:` / `━━━ Stage N:` format |
| 4 | Progress narration | ✓ | Progress updates after each wave/stage |
| 5 | Failure Modes | ✓ | Explicit table (7 rows) |
| 6 | Known Limitations | ✓ | Explicit section (6 items) |
| 7 | Vault awareness | ✓ | Checks for prior prism reports in Stage 0 |
| 8 | Integration | ✓ | Decision guide (prism vs quality-sweep) |
| 9 | Output format | ✓ | Full report template with themes |
| 10 | Skip handling | N/A | No skippable stages (all agents run or timeout) |

## Work Units

### WU-1: Fix pre-mortem skippability in blueprint.md

**Complexity:** Low
**TDD:** false
**Files:** `commands/blueprint.md`

Changes:
1. **Status display (line ~193):** Change `○ 4.5 Pre-Mortem  (optional)` to `○ 4.5 Pre-Mortem` (no label — path table is the authoritative signal)
2. **Stage table (line ~219):** Change `Can Skip?` from `Yes` to `Recommended` (matching Stage 5 Review language)
3. **Path rules (line ~334-337):** Replace "recommended, skippable" with: "Elevated on Full path — if skipped, reason must be logged and a regression warning fires before Stage 5. Recommended on Standard path. Not shown on Light path."
4. **Overlap Detection section (lines ~997-1003):** Remove "suggest skipping pre-mortem on future blueprints." Replace with: "High overlap indicates prior rounds were thorough. Log `premortem_overlap: high` as a quality signal. Pre-mortem still runs — it may surface operationally distinct failures."
5. **Skippability section (lines ~1005-1008):** Rewrite: "Skippable on all paths with reason required. On Full path, skipping triggers a regression warning displayed before Stage 5 proceeds. On Standard path, skip is permitted without warning. Not shown on Light path."

**Enforcement note:** Pre-mortem elevation uses the regression warning mechanism (the highest enforcement tier available in markdown commands). A PreToolUse hook gate is out of scope but could be a future enhancement.

### WU-2: Add Cognitive Traps to prism.md

**Complexity:** Low
**TDD:** false
**Files:** `commands/prism.md`

Add a Cognitive Traps section after the YAML frontmatter, before the title. Pattern from blueprint:

| Rationalization | Why It's Wrong |
|---|---|
| "The project is too small for a full prism" | Small projects have the highest concentration of patterns — prism catches them early before they scale. |
| "I already know what's wrong" | You know what's VISIBLE. Prism's value is cross-cutting themes that emerge from 11 independent perspectives. |
| "This will take too long" | Prism runs agents in parallel. The time cost is less than the cost of missing a systemic pattern. |

### WU-3: Upgrade /clarify to wizard standard

**Complexity:** Medium
**TDD:** false
**Files:** `commands/clarify.md`

Add:
1. **Cognitive Traps section** (after frontmatter, before title). Draft rows:

| Rationalization | Why It's Wrong |
|---|---|
| "I already know what I need — just let me plan" | If you knew, you wouldn't be uncertain. /clarify exists because "I know" and "I can articulate it precisely" are different things. |
| "This will slow me down — I'll figure it out during implementation" | Ambiguity discovered during implementation costs 10x more to resolve than ambiguity discovered during clarification. |
| "The requirements are clear enough" | "Clear enough" is the most expensive phrase in engineering. What's obvious to you may be ambiguous to the spec. |

2. **Stage headers** for each step (Step 1 through Step 6 get `━━━` headers)
3. **Progress narration** between steps (brief status of what was completed)
4. **Vault awareness** in Step 1 (Assess): Mirror vault pattern from `blueprint.md`. "Vault available" for read paths means: `VAULT_ENABLED=1`, `VAULT_PATH` is non-empty, and `[ -d "$VAULT_PATH" ]` returns true. If any condition fails, skip silently (fail-open). Search for prior brainstorms, decisions, or findings related to the topic. When `$ARGUMENTS` is empty, use conversation context keywords as search terms.
5. **Failure Modes table** using schema `What Could Fail | Detection | Recovery` (matching prism.md)
6. **Known Limitations section**

### WU-4: Upgrade /review to wizard standard

**Complexity:** Medium
**TDD:** false
**Files:** `commands/review.md`

Add:
1. **Cognitive Traps section** (after frontmatter, before title). Draft rows:

| Rationalization | Why It's Wrong |
|---|---|
| "The blueprint already challenged this thoroughly" | Blueprint challenges the PLAN. Review challenges the IMPLEMENTATION. Different artifacts, different failure modes. |
| "I'll just do a quick look instead of running the full workflow" | A "quick look" misses what structured adversarial review catches: the things you don't think to look for. |
| "This is a small change, review is overkill" | Small changes in critical paths cause the biggest incidents. The review is proportional to risk, not size. |

2. **Fix stage numbering** — currently says "Stage 1 of 4" but has 5 stages. Should be "Stage X of 5" (or dynamic based on plugin detection)
3. **Progress narration** between stages
4. **Vault awareness** before Step 1: Mirror vault pattern from `blueprint.md`. "Vault available" for read paths means: `VAULT_ENABLED=1`, `VAULT_PATH` is non-empty, and `[ -d "$VAULT_PATH" ]` returns true. If any condition fails, skip silently (fail-open). Search for prior reviews, decisions, or findings related to the target.
5. **Failure Modes table** using schema `What Could Fail | Detection | Recovery` (matching prism.md)
6. **Known Limitations section**

### WU-5: Upgrade /test to wizard standard

**Complexity:** Low
**TDD:** false
**Files:** `commands/test.md`

Add:
1. **Progress narration** between stages (Stage 1 → 2 → 3 transitions)
2. **Vault awareness** in Stage 1: Mirror vault pattern from `blueprint.md`. "Vault available" for read paths means: `VAULT_ENABLED=1`, `VAULT_PATH` is non-empty, and `[ -d "$VAULT_PATH" ]` returns true. If any condition fails, skip silently (fail-open). Search for prior test specs, findings, or edge case discoveries related to the feature.
3. **Failure Modes table** using schema `What Could Fail | Detection | Recovery` (matching prism.md)
4. **Known Limitations section**

(Cognitive traps already present — `/test` is ahead of the curve here.)

### WU-6: Update README.md Workflow Wizards

**Complexity:** Low
**TDD:** false
**Files:** `README.md`

Change line 42 from:
```
| **Workflow Wizards** | `/blueprint`, `/review`, `/test` |
```
To:
```
| **Workflow Wizards** | `/blueprint`, `/prism`, `/clarify`, `/review`, `/test` |
```

Also move `/prism` out of the Quality row (it can remain there as a cross-reference or be removed to avoid double-listing).

### WU-7: Update commands/README.md Workflow Wizards

**Complexity:** Low
**TDD:** false
**Files:** `commands/README.md`

Add `/prism` to the Workflow Wizards table (lines 17-24). Keep it cross-listed in Quality if appropriate.

### WU-8a: Extend test.sh with wizard structural checks [pre-mortem addition]

**Complexity:** Low
**TDD:** false
**Files:** `test.sh`
**Source:** Pre-mortem finding F6 (critical) — manual checklists get skipped in practice

Add wizard structural section checks to test.sh Category 4 (enforcement lint). For each file tagged as a Workflow Wizard, grep for required section markers:

**Wizard files:** `commands/blueprint.md`, `commands/prism.md`, `commands/clarify.md`, `commands/review.md`, `commands/test.md`

**Required section markers (grep patterns):**

| Section | Grep Pattern |
|---------|-------------|
| Cognitive Traps | `Cognitive Traps` |
| Failure Modes | `Failure Modes` or `What Could Fail` |
| Known Limitations | `Known Limitations` |
| Vault awareness | `vault-config.sh` |

**Logic:**
```bash
# Category 4 addition: Wizard structural checks
WIZARD_FILES="commands/blueprint.md commands/prism.md commands/clarify.md commands/review.md commands/test.md"
WIZARD_SECTIONS=("Cognitive Traps" "Failure Modes|What Could Fail" "Known Limitations" "vault-config.sh")

for file in $WIZARD_FILES; do
  for section in "${WIZARD_SECTIONS[@]}"; do
    if ! grep -q "$section" "$file"; then
      fail "Wizard $file missing required section: $section"
    fi
  done
done
```

This converts the manual structural checklist into automated enforcement, consistent with the toolkit's principle that deterministic checks beat behavioral guidance.

### WU-8b: Add pre-mortem regression warning text to blueprint.md [pre-mortem addition]

**Complexity:** Low
**TDD:** false
**Files:** `commands/blueprint.md`
**Source:** Pre-mortem finding F4 (medium) — warning UX not specified

Add draft regression warning text to the Pre-Mortem Skippability section:

```
⚠️ Pre-mortem was skipped on Full path.
  Stage 4.5 surfaces operational failures that design review (Stages 3-4) doesn't catch.
  Reason logged: "[user's skip reason]"

  Proceed to Stage 5 anyway? (Y/n)
```

### WU-8c: Verification

**Complexity:** Low
**TDD:** false
**Files:** None (verification only)

**Pass criteria (ALL must pass):**
1. `bash test.sh` exits 0 (including new Category 4 wizard structural checks from WU-8a)
2. No new escape-hatch language in any description fields
3. All 5 wizard files pass the automated structural section checks

## Work Graph

```
WU-1 ──┐
WU-2 ──┤
WU-3 ──┼── all independent ──→ WU-6 ──┐
WU-4 ──┤                       WU-7 ──┼──→ WU-8a ──→ WU-8c
WU-5 ──┘                       WU-8b ─┘
```

WU-1 through WU-5 are independent (different files, no shared state). WU-6, WU-7, and WU-8b **depend on WU-1 through WU-5 completing** — README prose must reflect final command state; WU-8b adds warning text to the same file WU-1 modifies. WU-8a (test.sh extension) depends on all command changes being complete so the grep checks have something to find. WU-8c is final verification.

**Parallelization width:** 5 (WU-1 through WU-5 can all run concurrently)
**Critical path:** Any WU → WU-6/7/8b → WU-8a → WU-8c (4 stages)

## Preservation Contract

- No existing command behavior removals — additions only, with one intentional correction:
  - **WU-1 (pre-mortem):** Changes from skippable to required on Full path. This is a defect fix — the current skippability undermines the operational review pre-mortem was designed to provide. Three independent vault findings confirm pre-mortems catch a genuinely different failure class than design review.
- No frontmatter `description` field changes (enforcement tier preserved)
- Integration sections remain accurate
- Existing vault export logic untouched
- Blueprint regression/feedback loops untouched (except pre-mortem skippability)

## Success Criteria

1. All 5 wizard commands have: Cognitive Traps, stage headers, progress narration, failure modes, known limitations, vault awareness, integration
2. Pre-mortem is required on Full path, recommended on Standard, not shown on Light
3. Pre-mortem overlap detection no longer suggests skipping
4. `/prism` and `/clarify` appear in Workflow Wizards in both READMEs
5. `bash test.sh` passes
