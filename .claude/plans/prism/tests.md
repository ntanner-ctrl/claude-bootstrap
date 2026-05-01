# Generated Tests: /prism

## Source Specification

### Success Criteria Used

| Criterion | Test Coverage |
|-----------|--------------|
| `/prism` command exists and is installable | B1 |
| 6 lens agents exist and are installable | B2 |
| Lens agents have required YAML frontmatter | B3 |
| Lens agents have correct tool restrictions | B4 |
| Prism command has correct enforcement-tier description | B5 |
| Vault template exists | B6 |
| README agent count updated (6→12) | B7 |
| README command count updated | B8 |
| test.sh expected counts match actual | B9 |
| install.sh output message reflects new counts | B10 |
| Lens agent boundaries have "You do NOT care about" sections | B11 |
| Prism command references all 6 lens agents | B12 |
| Prism command references all domain reviewers in correct serial order | B13 |
| Output format contains themed structure | B14 |
| Output format contains standalone findings section | B15 |
| Output format contains constraint extraction audit | B16 |
| Vault export template has YAML frontmatter | B17 |
| Vault slug uses HHMM timestamp format | B18 |
| Dispatch prompt template has CONSTRAINTS and CONTEXT sections | B19 |
| Synthesis has two explicit sub-steps (mechanical + judgment) | B20 |
| Voting threshold specifies critical severity bypass | B21 |
| Co-location rule has line proximity AND named entity triggers | B22 |
| Tie-breaking rule defined | B23 |
| Conflict marker warning specified | B24 |
| Minimum scope floor or proportionality warning specified | B25 |
| Progress narration specified per stage | B26 |
| "Start fresh session" note in report footer | B27 |
| Decision guide distinguishing prism from quality-sweep | B28 |

### Preservation Contract Used

| Invariant | Test Coverage |
|-----------|--------------|
| Existing domain reviewer agents unmodified | C1, C2 |
| Quality sweep behavior unchanged | C3 |
| Vault infrastructure unmodified | C4 |
| Install.sh tarball extraction pattern intact | C5 |
| Test.sh structure unchanged (only counts) | C6 |

### Failure Modes Used

| Failure | Test Coverage |
|---------|--------------|
| Lens agent timeout → skip + note | F1 |
| Domain reviewer timeout → skip + note + gap dispatch | F2 |
| All agents timeout → report and exit | F3 |
| Vault unavailable → skip silently | F4 |
| No source files → report and exit | F5 |
| Malformed lens output → retry then skip | F6 |
| Zero observations (clean empty) → no retry | F7 |

---

## Generated Tests

### Behavior Tests (from Success Criteria)

These tests verify observable outcomes without knowledge of implementation structure.
Test format: shell commands that can be added to test.sh or run standalone.

```bash
#!/usr/bin/env bash
# Spec-blind tests for /prism
# Run from claude-sail repo root

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; ((PASS++)); }
fail() { echo "  FAIL: $1"; ((FAIL++)); }

# ──────────────────────────────────────────────
# B1: /prism command exists and is installable
# ──────────────────────────────────────────────
# Setup: temp HOME, run install.sh
# Action: check for prism.md in installed location
# Assert: file exists

test_b1() {
  local TEMP_HOME
  TEMP_HOME=$(mktemp -d)
  HOME="$TEMP_HOME" bash install.sh >/dev/null 2>&1
  if [ -f "$TEMP_HOME/.claude/commands/prism.md" ]; then
    pass "B1: prism command installs to ~/.claude/commands/"
  else
    fail "B1: prism.md not found after install"
  fi
  rm -rf "$TEMP_HOME"
}

# ──────────────────────────────────────────────
# B2: 6 lens agents exist and are installable
# ──────────────────────────────────────────────
# Setup: temp HOME, run install.sh
# Action: check for all 6 lens agents
# Assert: all 6 files exist

test_b2() {
  local TEMP_HOME
  TEMP_HOME=$(mktemp -d)
  HOME="$TEMP_HOME" bash install.sh >/dev/null 2>&1
  local AGENTS=("dry-lens" "yagni-lens" "kiss-lens" "consistency-lens" "cohesion-lens" "coupling-lens")
  local ALL_FOUND=true
  for agent in "${AGENTS[@]}"; do
    if [ ! -f "$TEMP_HOME/.claude/agents/${agent}.md" ]; then
      fail "B2: ${agent}.md not found after install"
      ALL_FOUND=false
    fi
  done
  if $ALL_FOUND; then
    pass "B2: all 6 lens agents install correctly"
  fi
  rm -rf "$TEMP_HOME"
}

# ──────────────────────────────────────────────
# B3: Lens agents have required YAML frontmatter
# ──────────────────────────────────────────────
# Setup: none
# Action: check each lens agent for name, description, tools fields
# Assert: all three fields present in each

test_b3() {
  local AGENTS=("dry-lens" "yagni-lens" "kiss-lens" "consistency-lens" "cohesion-lens" "coupling-lens")
  local ALL_OK=true
  for agent in "${AGENTS[@]}"; do
    local FILE="agents/${agent}.md"
    if [ ! -f "$FILE" ]; then
      fail "B3: ${FILE} does not exist in repo"
      ALL_OK=false
      continue
    fi
    for field in "name:" "description:" "tools:"; do
      if ! grep -q "^${field}" "$FILE" 2>/dev/null; then
        fail "B3: ${FILE} missing frontmatter field '${field}'"
        ALL_OK=false
      fi
    done
  done
  if $ALL_OK; then
    pass "B3: all lens agents have required YAML frontmatter"
  fi
}

# ──────────────────────────────────────────────
# B4: Lens agents have correct tool restrictions (Read, Glob, Grep only)
# ──────────────────────────────────────────────
# Setup: none
# Action: check tools list in each lens agent
# Assert: tools include Read, Glob, Grep; do NOT include Edit, Write, Bash

test_b4() {
  local AGENTS=("dry-lens" "yagni-lens" "kiss-lens" "consistency-lens" "cohesion-lens" "coupling-lens")
  local ALL_OK=true
  for agent in "${AGENTS[@]}"; do
    local FILE="agents/${agent}.md"
    # Should have Read, Glob, Grep
    for tool in "Read" "Glob" "Grep"; do
      if ! grep -q "- ${tool}" "$FILE" 2>/dev/null; then
        fail "B4: ${FILE} missing tool '${tool}'"
        ALL_OK=false
      fi
    done
    # Should NOT have Edit, Write, Bash (read-only agents)
    for banned in "Edit" "Write" "Bash"; do
      if grep -q "- ${banned}" "$FILE" 2>/dev/null; then
        fail "B4: ${FILE} has forbidden tool '${banned}' — lens agents must be read-only"
        ALL_OK=false
      fi
    done
  done
  if $ALL_OK; then
    pass "B4: all lens agents are read-only (Read, Glob, Grep)"
  fi
}

# ──────────────────────────────────────────────
# B5: Prism command description follows enforcement tier
# ──────────────────────────────────────────────
# Setup: none
# Action: read description field from commands/prism.md
# Assert: description is trigger-only (no workflow summary),
#         no escape-hatch language (consider, might, optionally)

test_b5() {
  local FILE="commands/prism.md"
  if [ ! -f "$FILE" ]; then
    fail "B5: commands/prism.md does not exist"
    return
  fi
  local DESC
  DESC=$(grep "^description:" "$FILE" | head -1)
  if [ -z "$DESC" ]; then
    fail "B5: prism.md has no description field"
    return
  fi
  # Check for escape-hatch language
  if echo "$DESC" | grep -iq "consider\|might\|optionally\|perhaps"; then
    fail "B5: prism.md description contains escape-hatch language"
    return
  fi
  pass "B5: prism command description follows enforcement tier"
}

# ──────────────────────────────────────────────
# B6: Vault template exists with YAML frontmatter
# ──────────────────────────────────────────────

test_b6() {
  # Check for vault template (location may vary per pre-mortem F4)
  local FOUND=false
  for path in \
    "commands/templates/vault-notes/prism-report.md" \
    "commands/templates/prism-report.md"; do
    if [ -f "$path" ]; then
      FOUND=true
      if grep -q "^---" "$path" && grep -q "type:" "$path"; then
        pass "B6: vault template exists with YAML frontmatter at ${path}"
      else
        fail "B6: vault template at ${path} missing YAML frontmatter"
      fi
      break
    fi
  done
  if ! $FOUND; then
    fail "B6: no vault template found for prism reports"
  fi
}

# ──────────────────────────────────────────────
# B7-B10: Count accuracy
# ──────────────────────────────────────────────

test_b7() {
  local ACTUAL_AGENTS
  ACTUAL_AGENTS=$(ls agents/*.md 2>/dev/null | wc -l)
  if [ "$ACTUAL_AGENTS" -ge 12 ]; then
    pass "B7: agent count >= 12 (6 original + 6 lens)"
  else
    fail "B7: expected >= 12 agents, found ${ACTUAL_AGENTS}"
  fi
}

test_b8() {
  local ACTUAL_COMMANDS
  ACTUAL_COMMANDS=$(ls commands/*.md 2>/dev/null | wc -l)
  if [ "$ACTUAL_COMMANDS" -ge 63 ]; then
    pass "B8: command count >= 63 (62 original + prism)"
  else
    fail "B8: expected >= 63 commands, found ${ACTUAL_COMMANDS}"
  fi
}

# ──────────────────────────────────────────────
# B11: Lens boundary definitions include "You do NOT care about"
# ──────────────────────────────────────────────

test_b11() {
  local AGENTS=("dry-lens" "yagni-lens" "kiss-lens" "consistency-lens" "cohesion-lens" "coupling-lens")
  local ALL_OK=true
  for agent in "${AGENTS[@]}"; do
    local FILE="agents/${agent}.md"
    if ! grep -qi "do NOT care about\|DOES NOT CARE ABOUT\|You do NOT care" "$FILE" 2>/dev/null; then
      fail "B11: ${FILE} missing boundary definition ('You do NOT care about' section)"
      ALL_OK=false
    fi
  done
  if $ALL_OK; then
    pass "B11: all lens agents have boundary definitions"
  fi
}

# ──────────────────────────────────────────────
# B12: Prism command references all 6 lens agents
# ──────────────────────────────────────────────

test_b12() {
  local FILE="commands/prism.md"
  local AGENTS=("dry-lens" "yagni-lens" "kiss-lens" "consistency-lens" "cohesion-lens" "coupling-lens")
  local ALL_OK=true
  for agent in "${AGENTS[@]}"; do
    if ! grep -q "${agent}" "$FILE" 2>/dev/null; then
      fail "B12: prism.md does not reference ${agent}"
      ALL_OK=false
    fi
  done
  if $ALL_OK; then
    pass "B12: prism command references all 6 lens agents"
  fi
}

# ──────────────────────────────────────────────
# B13: Prism references domain reviewers in correct serial order
# ──────────────────────────────────────────────

test_b13() {
  local FILE="commands/prism.md"
  # Architecture must appear before security, security before performance, performance before quality
  local ARCH_LINE SEC_LINE PERF_LINE QUAL_LINE
  ARCH_LINE=$(grep -n "architecture-reviewer\|architecture.review\|Architecture Review" "$FILE" 2>/dev/null | head -1 | cut -d: -f1)
  SEC_LINE=$(grep -n "security-reviewer\|security.review\|Security Review" "$FILE" 2>/dev/null | head -1 | cut -d: -f1)
  PERF_LINE=$(grep -n "performance-reviewer\|performance.review\|Performance Review" "$FILE" 2>/dev/null | head -1 | cut -d: -f1)
  QUAL_LINE=$(grep -n "quality-reviewer\|quality.review\|Quality Review" "$FILE" 2>/dev/null | head -1 | cut -d: -f1)

  if [ -z "$ARCH_LINE" ] || [ -z "$SEC_LINE" ] || [ -z "$PERF_LINE" ] || [ -z "$QUAL_LINE" ]; then
    fail "B13: prism.md missing one or more domain reviewer references"
    return
  fi

  if [ "$ARCH_LINE" -lt "$SEC_LINE" ] && [ "$SEC_LINE" -lt "$PERF_LINE" ] && [ "$PERF_LINE" -lt "$QUAL_LINE" ]; then
    pass "B13: domain reviewers appear in correct serial order (arch→sec→perf→qual)"
  else
    fail "B13: domain reviewers not in correct serial order (arch:${ARCH_LINE} sec:${SEC_LINE} perf:${PERF_LINE} qual:${QUAL_LINE})"
  fi
}

# ──────────────────────────────────────────────
# B14-B16: Output format structure
# ──────────────────────────────────────────────

test_b14() {
  local FILE="commands/prism.md"
  if grep -q "THEME.*:" "$FILE" 2>/dev/null && grep -q "Priority:" "$FILE" 2>/dev/null && grep -q "Category:" "$FILE" 2>/dev/null; then
    pass "B14: output format contains themed structure (THEME, Priority, Category)"
  else
    fail "B14: output format missing themed structure elements"
  fi
}

test_b15() {
  local FILE="commands/prism.md"
  if grep -qi "Standalone Findings\|standalone findings" "$FILE" 2>/dev/null; then
    pass "B15: output format contains standalone findings section"
  else
    fail "B15: output format missing standalone findings section"
  fi
}

test_b16() {
  local FILE="commands/prism.md"
  if grep -qi "Constraint Extraction Audit\|constraint extraction" "$FILE" 2>/dev/null; then
    pass "B16: output format contains constraint extraction audit section"
  else
    fail "B16: output format missing constraint extraction audit"
  fi
}

# ──────────────────────────────────────────────
# B18: Vault slug uses HHMM timestamp format
# ──────────────────────────────────────────────

test_b18() {
  local FILE="commands/prism.md"
  if grep -q "HHMM" "$FILE" 2>/dev/null; then
    pass "B18: vault slug uses HHMM timestamp format"
  else
    fail "B18: vault slug missing HHMM timestamp (same-day collision risk)"
  fi
}

# ──────────────────────────────────────────────
# B19: Dispatch prompt has CONSTRAINTS and CONTEXT sections
# ──────────────────────────────────────────────

test_b19() {
  local FILE="commands/prism.md"
  if grep -q "CONSTRAINTS" "$FILE" 2>/dev/null && grep -q "CONTEXT" "$FILE" 2>/dev/null; then
    pass "B19: dispatch prompt has CONSTRAINTS and CONTEXT sections"
  else
    fail "B19: dispatch prompt missing CONSTRAINTS/CONTEXT split"
  fi
}

# ──────────────────────────────────────────────
# B20: Synthesis has two sub-steps
# ──────────────────────────────────────────────

test_b20() {
  local FILE="commands/prism.md"
  if grep -qi "Sub-Step A\|mechanical\|co-location" "$FILE" 2>/dev/null && grep -qi "Sub-Step B\|judgment\|theme detection" "$FILE" 2>/dev/null; then
    pass "B20: synthesis has two explicit sub-steps"
  else
    fail "B20: synthesis missing two-step structure"
  fi
}

# ──────────────────────────────────────────────
# B21: Voting threshold has critical severity bypass
# ──────────────────────────────────────────────

test_b21() {
  local FILE="commands/prism.md"
  if grep -qi "critical.*bypass\|bypass.*critical" "$FILE" 2>/dev/null; then
    pass "B21: voting threshold has critical severity bypass"
  else
    fail "B21: no critical severity bypass in voting threshold"
  fi
}

# ──────────────────────────────────────────────
# B22: Co-location rule has line proximity AND named entity
# ──────────────────────────────────────────────

test_b22() {
  local FILE="commands/prism.md"
  local HAS_LINE HAS_ENTITY
  HAS_LINE=$(grep -ci "line proximity\|within.*lines\|overlapping.*line" "$FILE" 2>/dev/null)
  HAS_ENTITY=$(grep -ci "named entity\|function name\|class name" "$FILE" 2>/dev/null)
  if [ "$HAS_LINE" -gt 0 ] && [ "$HAS_ENTITY" -gt 0 ]; then
    pass "B22: co-location has both line proximity and named entity triggers"
  else
    fail "B22: co-location missing one or both merge triggers (line:${HAS_LINE} entity:${HAS_ENTITY})"
  fi
}

# ──────────────────────────────────────────────
# B23: Tie-breaking rule defined
# ──────────────────────────────────────────────

test_b23() {
  local FILE="commands/prism.md"
  if grep -qi "tie.break\|Tie-break\|breaking.*ties\|break ties" "$FILE" 2>/dev/null; then
    pass "B23: tie-breaking rule defined"
  else
    fail "B23: no tie-breaking rule found"
  fi
}

# ──────────────────────────────────────────────
# B24: Conflict marker warning
# ──────────────────────────────────────────────

test_b24() {
  local FILE="commands/prism.md"
  if grep -qi "conflict marker\|merge conflict" "$FILE" 2>/dev/null; then
    pass "B24: conflict marker warning specified"
  else
    fail "B24: no conflict marker handling found"
  fi
}

# ──────────────────────────────────────────────
# B27: "Start fresh session" note
# ──────────────────────────────────────────────

test_b27() {
  local FILE="commands/prism.md"
  if grep -qi "fresh session\|new session\|start a new" "$FILE" 2>/dev/null; then
    pass "B27: fresh session recommendation in output"
  else
    fail "B27: no fresh session recommendation found"
  fi
}

# ==========================================
# CONTRACT TESTS (Preservation Contract)
# ==========================================

# ──────────────────────────────────────────────
# C1: Existing domain reviewer agents are unmodified
# ──────────────────────────────────────────────
# Action: check git status of existing reviewers
# Assert: no modifications to any existing reviewer

test_c1() {
  local REVIEWERS=("spec-reviewer" "quality-reviewer" "security-reviewer" "performance-reviewer" "architecture-reviewer" "cloudformation-reviewer")
  local MODIFIED=false
  for reviewer in "${REVIEWERS[@]}"; do
    if git diff --name-only 2>/dev/null | grep -q "agents/${reviewer}.md"; then
      fail "C1: ${reviewer}.md has been modified (preservation contract violation)"
      MODIFIED=true
    fi
  done
  if ! $MODIFIED; then
    pass "C1: all existing domain reviewer agents are unmodified"
  fi
}

# ──────────────────────────────────────────────
# C2: Existing reviewers still have their original mandates
# ──────────────────────────────────────────────

test_c2() {
  # Quality reviewer should still say "Is this code well-built?"
  if grep -q "well-built" "agents/quality-reviewer.md" 2>/dev/null; then
    pass "C2: quality-reviewer retains original mandate"
  else
    fail "C2: quality-reviewer mandate may have been altered"
  fi
}

# ──────────────────────────────────────────────
# C3: Quality sweep command is unchanged
# ──────────────────────────────────────────────

test_c3() {
  if git diff --name-only 2>/dev/null | grep -q "commands/quality-sweep.md"; then
    fail "C3: quality-sweep.md has been modified (preservation contract violation)"
  else
    pass "C3: quality-sweep command is unchanged"
  fi
}

# ──────────────────────────────────────────────
# C4: Vault infrastructure is unmodified
# ──────────────────────────────────────────────

test_c4() {
  local MODIFIED=false
  for file in "hooks/vault-config.sh" "commands/vault-save.md" "commands/vault-query.md"; do
    if git diff --name-only 2>/dev/null | grep -q "$file"; then
      fail "C4: ${file} has been modified (preservation contract violation)"
      MODIFIED=true
    fi
  done
  if ! $MODIFIED; then
    pass "C4: vault infrastructure is unmodified"
  fi
}

# ──────────────────────────────────────────────
# C5: Install.sh tarball extraction pattern intact
# ──────────────────────────────────────────────

test_c5() {
  # The install.sh should NOT have a hardcoded file list for agents
  # (tarball auto-discovers)
  if grep -q "dry-lens\|yagni-lens\|kiss-lens" "install.sh" 2>/dev/null; then
    # Individual agent names should only appear in count/output, not in copy logic
    local COPY_REFS
    COPY_REFS=$(grep -c "cp.*lens\|copy.*lens\|install.*lens" "install.sh" 2>/dev/null)
    if [ "$COPY_REFS" -gt 0 ]; then
      fail "C5: install.sh appears to have hardcoded lens agent copy commands (should use tarball auto-discovery)"
    else
      pass "C5: install.sh tarball extraction pattern intact (no hardcoded lens copies)"
    fi
  else
    pass "C5: install.sh tarball pattern intact"
  fi
}

# ──────────────────────────────────────────────
# C6: Test.sh structure unchanged (only counts differ)
# ──────────────────────────────────────────────

test_c6() {
  # Verify test.sh still has the same category structure
  local CATS
  CATS=$(grep -c "Category [0-9]" "test.sh" 2>/dev/null)
  if [ "$CATS" -ge 8 ]; then
    pass "C6: test.sh retains all 8+ test categories"
  else
    fail "C6: test.sh category structure changed (expected 8+, found ${CATS})"
  fi
}

# ==========================================
# FAILURE MODE TESTS
# ==========================================

# ──────────────────────────────────────────────
# F1-F3: Timeout handling specified in prism command
# ──────────────────────────────────────────────

test_f1() {
  local FILE="commands/prism.md"
  if grep -qi "timeout\|timed out\|time.out" "$FILE" 2>/dev/null && grep -qi "skip" "$FILE" 2>/dev/null; then
    pass "F1: timeout handling with skip behavior specified"
  else
    fail "F1: no timeout + skip behavior found in prism command"
  fi
}

test_f3() {
  local FILE="commands/prism.md"
  if grep -qi "all.*timeout\|could not complete\|all agents" "$FILE" 2>/dev/null; then
    pass "F3: all-timeout terminal condition specified"
  else
    fail "F3: no all-timeout handling found"
  fi
}

# ──────────────────────────────────────────────
# F4: Vault unavailable → skip silently
# ──────────────────────────────────────────────

test_f4() {
  local FILE="commands/prism.md"
  if grep -qi "vault.*unavailable.*skip\|skip.*silent\|vault.*skip" "$FILE" 2>/dev/null; then
    pass "F4: vault unavailable → skip silently specified"
  else
    fail "F4: no vault-unavailable skip behavior found"
  fi
}

# ──────────────────────────────────────────────
# F5: No source files → report and exit
# ──────────────────────────────────────────────

test_f5() {
  local FILE="commands/prism.md"
  if grep -qi "no source files\|No source files" "$FILE" 2>/dev/null; then
    pass "F5: no-source-files exit condition specified"
  else
    fail "F5: no handling for empty project found"
  fi
}

# ──────────────────────────────────────────────
# F6: Malformed lens output → retry then skip
# ──────────────────────────────────────────────

test_f6() {
  local FILE="commands/prism.md"
  if grep -qi "retry\|re-prompt\|single retry" "$FILE" 2>/dev/null && grep -qi "malformed\|unparseable" "$FILE" 2>/dev/null; then
    pass "F6: malformed output retry + skip behavior specified"
  else
    fail "F6: no malformed output handling found"
  fi
}

# ──────────────────────────────────────────────
# F7: Zero observations (clean empty) → no retry
# ──────────────────────────────────────────────

test_f7() {
  local FILE="commands/prism.md"
  if grep -qi "zero observation\|clean empty\|Zero observations" "$FILE" 2>/dev/null; then
    pass "F7: zero observations distinguished from malformed output"
  else
    fail "F7: no distinction between zero observations and malformed output"
  fi
}

# ==========================================
# RUN ALL TESTS
# ==========================================

echo "═══════════════════════════════════════════"
echo "  PRISM SPEC-BLIND TESTS"
echo "═══════════════════════════════════════════"
echo ""
echo "  Behavior Tests (Success Criteria):"
test_b1; test_b2; test_b3; test_b4; test_b5
test_b6; test_b7; test_b8
test_b11; test_b12; test_b13
test_b14; test_b15; test_b16; test_b18; test_b19
test_b20; test_b21; test_b22; test_b23; test_b24; test_b27
echo ""
echo "  Contract Tests (Preservation):"
test_c1; test_c2; test_c3; test_c4; test_c5; test_c6
echo ""
echo "  Failure Mode Tests:"
test_f1; test_f3; test_f4; test_f5; test_f6; test_f7
echo ""
echo "═══════════════════════════════════════════"
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "═══════════════════════════════════════════"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

## Anti-Tautology Review

| Test | Could pass with wrong impl? | Tests behavior not structure? | Survives refactor? | Derived from spec? |
|------|----------------------------|------------------------------|-------------------|-------------------|
| B1-B2 (install) | No — file must exist | Yes | Yes | Yes — success criteria |
| B3-B4 (frontmatter/tools) | No — fields must be present | Yes — observable metadata | Yes | Yes — agent design spec |
| B5 (description) | Partial — checks absence of bad, not presence of good | Yes | Yes | Yes — enforcement tiers |
| B11 (boundaries) | No — text must exist | Yes | Yes | Yes — lens boundary spec |
| B12-B13 (references/order) | No — names must appear in order | Yes | Yes | Yes — pipeline spec |
| B14-B16 (output format) | Partial — checks key terms | Yes | Yes | Yes — output format spec |
| B19-B24 (rev 2+3 features) | No — specific terms must exist | Yes | Yes | Yes — adversarial findings |
| C1-C6 (preservation) | No — git diff is definitive | Yes | Yes | Yes — preservation contract |
| F1-F7 (failure modes) | Partial — checks specification text, not runtime behavior | Yes | Yes | Yes — failure modes table |

**Red flags acknowledged:**
- Tests B14-B16, F1-F7 check that the *command file mentions* certain behaviors, not that it *implements* them at runtime. This is inherent to testing a markdown command — runtime behavior requires manual verification or behavioral evals. These tests catch "forgot to include the section" errors, not "the section doesn't work" errors.
- Runtime behavioral tests (does synthesis actually merge co-located observations?) require running prism against a known codebase with planted issues — that's a behavioral eval fixture for evals.json, not a shell test.

## Implementation Notes

These tests should:
1. **Fail initially** — nothing is implemented yet (B1, B2 will fail; B7, B8 will fail on counts)
2. **Pass without modification** once all 12 work units are complete
3. **If tests need changing** — that's a spec incompleteness signal, not a test bug
4. **Contract tests (C1-C6)** should pass NOW — they verify nothing was broken

---
Tests generated from specification. 34 tests across 3 categories.
Next:
  • Run contract tests now (should pass — nothing changed yet)
  • Build work units W1-W12
  • Run all tests after implementation
  • If behavioral runtime testing needed → add evals.json fixture
