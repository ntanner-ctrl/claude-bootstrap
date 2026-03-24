# Test Specifications: wizard-standardization

## Spec-Blind Test Derivation

Tests derived from success criteria and preservation contract only. Implementation not consulted.

## Test 1: Wizard Structural Section Presence (automated — test.sh Category 4)

For each wizard file in `commands/{blueprint,prism,clarify,review,test}.md`:

| Check | Pattern | Pass Condition |
|-------|---------|----------------|
| Cognitive Traps | `Cognitive Traps` | Present in all 5 files |
| Failure Modes | `Failure Modes\|What Could Fail` | Present in all 5 files |
| Known Limitations | `Known Limitations` | Present in all 5 files |
| Vault awareness | `vault-config.sh` | Present in all 5 files |

## Test 2: Pre-mortem NOT labeled optional (automated — test.sh Category 4)

File: `commands/blueprint.md`

| Check | Pattern | Pass Condition |
|-------|---------|----------------|
| No "(optional)" on pre-mortem status line | `Pre-Mortem.*optional` | NOT present |
| No "suggest skipping pre-mortem" | `suggest skipping pre-mortem` | NOT present |
| Regression warning text exists | `Pre-mortem was skipped on Full path` | Present |

## Test 3: README categorization (automated — test.sh Category 4)

| File | Check | Pattern | Pass Condition |
|------|-------|---------|----------------|
| `README.md` | Workflow Wizards includes prism | `Workflow Wizards.*prism` | Present |
| `README.md` | Workflow Wizards includes clarify | `Workflow Wizards.*clarify` | Present |
| `commands/README.md` | Wizard table includes prism | `/prism` in Workflow Wizards section | Present |

## Test 4: test.sh self-test (automated)

`bash test.sh` exits 0 after all changes applied, including the new Category 4 wizard checks.

## Test 5: Preservation contract (manual verification)

| Invariant | Verification Method |
|-----------|-------------------|
| No description field changes | `git diff --stat` shows no frontmatter changes |
| Integration sections accurate | Read each command's Integration section |
| Existing vault export logic untouched | `git diff commands/blueprint.md` shows no changes to "Vault Export" section |

## Anti-Tautology Review

| Test | Trivial Pass? | Behavior Focus? | Refactor-Safe? | Spec-Derived? |
|------|---------------|-----------------|----------------|---------------|
| Test 1 | ✓ No — requires actual section content | ✓ Yes | ✓ Yes | ✓ Yes |
| Test 2 | ✓ No — requires specific text removal/addition | ✓ Yes | ✓ Yes | ✓ Yes |
| Test 3 | ✓ No — requires README changes | ✓ Yes | ✓ Yes | ✓ Yes |
| Test 4 | ✓ No — integration test | ✓ Yes | ✓ Yes | ✓ Yes |
| Test 5 | ⚠️ Manual — could be skipped | ✓ Yes | ✓ Yes | ✓ Yes |
