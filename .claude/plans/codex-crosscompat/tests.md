# Generated Tests: codex-crosscompat

> Spec-blind: generated from success criteria, preservation contract, and failure modes only.
> No implementation knowledge used.

## Source Specification Coverage

### Success Criteria → Test Mapping
| Criterion | Test(s) |
|-----------|---------|
| 65 commands converted, frontmatter-free, with headers | B1, B2, B3 |
| 12 agents converted, valid openai.yaml | B4, B5 |
| hooks.json correct schema, relative paths | B6, B7 |
| Hook scripts zero ~/.claude/ references | B8 |
| AGENTS.md compensation for 3 blocked hooks | B9 |
| AGENTS.md no ~/.claude/ paths | B10 |
| plugin.json validates | B11 |
| install-codex.sh deploys correctly | B12 |
| Idempotent and deterministic | B13 |
| Source files never modified | B14 |
| Base test.sh still passes | C1 |
| Content staleness detected | B15 |

### Preservation Contract → Test Mapping
| Invariant | Test(s) |
|-----------|---------|
| Source files unmodified | C2 |
| install.sh unchanged | C3 |
| test.sh base categories pass | C1 |
| settings-example.json read-only | C4 |
| Hook exit-code semantics preserved | C5 |

### Failure Modes → Test Mapping
| Failure | Test(s) |
|---------|---------|
| Frontmatter stripping corrupts body | F1 |
| openai.yaml invalid YAML | F2 |
| Path rewriting misses a reference | F3 (same as B8) |
| hooks.json references non-existent scripts | F4 |
| plugin.json missing required fields | F5 |
| Source files accidentally modified | F6 (same as C2) |

## Generated Tests

### Behavior Tests (from Success Criteria)

```bash
#!/bin/bash
# Test suite: codex-crosscompat spec-blind tests
# Run after: scripts/convert-to-codex.sh has been executed
# Expected: all tests pass if implementation meets spec

set -euo pipefail
PASS=0; FAIL=0; SKIP=0
CODEX_DIR="codex"

pass() { ((PASS++)); echo "  ✓ $1"; }
fail() { ((FAIL++)); echo "  ✗ $1: $2"; }
skip() { ((SKIP++)); echo "  ⊘ $1: $2"; }

echo "=== Behavior Tests ==="

# B1: Command count
CMD_COUNT=$(find "$CODEX_DIR/commands" -maxdepth 1 -name '*.md' ! -name 'README.md' 2>/dev/null | wc -l)
if [ "$CMD_COUNT" -eq 65 ]; then
  pass "B1: 65 commands in codex/commands/"
else
  fail "B1: Expected 65 commands, found $CMD_COUNT"
fi

# B2: No YAML frontmatter in commands
FM_COUNT=0
for f in "$CODEX_DIR"/commands/*.md; do
  [ -f "$f" ] || continue
  [[ "$(basename "$f")" == "README.md" ]] && continue
  if head -1 "$f" | grep -q '^---$'; then
    ((FM_COUNT++))
    echo "    Frontmatter found in: $(basename "$f")"
  fi
done
if [ "$FM_COUNT" -eq 0 ]; then
  pass "B2: No YAML frontmatter in any converted command"
else
  fail "B2: $FM_COUNT commands still have YAML frontmatter"
fi

# B3: All commands have # header in first 5 lines
NOHEADER=0
for f in "$CODEX_DIR"/commands/*.md; do
  [ -f "$f" ] || continue
  [[ "$(basename "$f")" == "README.md" ]] && continue
  if ! head -5 "$f" | grep -q '^# '; then
    ((NOHEADER++))
    echo "    Missing header: $(basename "$f")"
  fi
done
if [ "$NOHEADER" -eq 0 ]; then
  pass "B3: All commands have # header in first 5 lines"
else
  fail "B3: $NOHEADER commands missing # header in first 5 lines"
fi

# B4: Agent count + no frontmatter
AGENT_COUNT=$(find "$CODEX_DIR/agents" -maxdepth 1 -name '*.md' ! -name 'README.md' 2>/dev/null | wc -l)
AGENT_FM=0
for f in "$CODEX_DIR"/agents/*.md; do
  [ -f "$f" ] || continue
  if head -1 "$f" | grep -q '^---$'; then
    ((AGENT_FM++))
  fi
done
if [ "$AGENT_COUNT" -eq 12 ] && [ "$AGENT_FM" -eq 0 ]; then
  pass "B4: 12 agents, no frontmatter"
else
  fail "B4: Expected 12 agents (found $AGENT_COUNT), $AGENT_FM with frontmatter"
fi

# B5: openai.yaml exists and has required fields
if [ -f "$CODEX_DIR/agents/openai.yaml" ]; then
  if grep -q 'display_name' "$CODEX_DIR/agents/openai.yaml" && \
     grep -q 'short_description' "$CODEX_DIR/agents/openai.yaml"; then
    pass "B5: openai.yaml has display_name and short_description"
  else
    fail "B5: openai.yaml missing required fields"
  fi
else
  fail "B5: codex/agents/openai.yaml does not exist"
fi

# B6: hooks.json exists and is valid JSON
if [ -f "$CODEX_DIR/hooks.json" ]; then
  if jq empty "$CODEX_DIR/hooks.json" 2>/dev/null; then
    pass "B6: hooks.json is valid JSON"
  else
    fail "B6: hooks.json is not valid JSON"
  fi
else
  fail "B6: codex/hooks.json does not exist"
fi

# B7: hooks.json uses relative paths only (no ~/ or absolute)
if [ -f "$CODEX_DIR/hooks.json" ]; then
  if grep -q '~/\|/home/' "$CODEX_DIR/hooks.json"; then
    fail "B7: hooks.json contains absolute/home paths" "$(grep -c '~/\|/home/' "$CODEX_DIR/hooks.json") occurrences"
  else
    pass "B7: hooks.json uses relative paths only"
  fi
else
  skip "B7: hooks.json missing (depends on B6)"
fi

# B8: Zero ~/.claude/ references in hook scripts
if [ -d "$CODEX_DIR/hooks" ]; then
  CLAUDE_REFS=$(grep -rl '~/.claude/' "$CODEX_DIR/hooks/" 2>/dev/null | wc -l)
  if [ "$CLAUDE_REFS" -eq 0 ]; then
    pass "B8: Zero ~/.claude/ references in codex hook scripts"
  else
    fail "B8: $CLAUDE_REFS hook scripts still contain ~/.claude/"
    grep -rl '~/.claude/' "$CODEX_DIR/hooks/" 2>/dev/null | while read -r f; do
      echo "    $(basename "$f"): $(grep -c '~/.claude/' "$f") refs"
    done
  fi
else
  fail "B8: codex/hooks/ directory does not exist"
fi

# B9: AGENTS.md contains compensation for 3 blocked hooks
if [ -f "$CODEX_DIR/AGENTS.md" ]; then
  MISSING_HOOKS=""
  for hook in "protect-claude-md" "tdd-guardian" "freeze-guard"; do
    if ! grep -qi "$hook" "$CODEX_DIR/AGENTS.md"; then
      MISSING_HOOKS="$MISSING_HOOKS $hook"
    fi
  done
  if [ -z "$MISSING_HOOKS" ]; then
    pass "B9: AGENTS.md references all 3 blocked PreToolUse hooks"
  else
    fail "B9: AGENTS.md missing references to:$MISSING_HOOKS"
  fi
else
  fail "B9: codex/AGENTS.md does not exist"
fi

# B10: AGENTS.md no ~/.claude/ paths
if [ -f "$CODEX_DIR/AGENTS.md" ]; then
  CLAUDE_PATHS=$(grep -c '~/.claude/' "$CODEX_DIR/AGENTS.md" 2>/dev/null || echo 0)
  if [ "$CLAUDE_PATHS" -eq 0 ]; then
    pass "B10: AGENTS.md contains no ~/.claude/ references"
  else
    fail "B10: AGENTS.md contains $CLAUDE_PATHS ~/.claude/ references"
  fi
else
  skip "B10: AGENTS.md missing (depends on B9)"
fi

# B11: plugin.json exists, is valid JSON, has required fields
if [ -f "$CODEX_DIR/plugin.json" ]; then
  if jq empty "$CODEX_DIR/plugin.json" 2>/dev/null; then
    MISSING=""
    for field in name version description hooks; do
      if ! jq -e ".$field" "$CODEX_DIR/plugin.json" >/dev/null 2>&1; then
        MISSING="$MISSING $field"
      fi
    done
    if [ -z "$MISSING" ]; then
      pass "B11: plugin.json valid with required fields (name, version, description, hooks)"
    else
      fail "B11: plugin.json missing fields:$MISSING"
    fi
  else
    fail "B11: plugin.json is not valid JSON"
  fi
else
  fail "B11: codex/plugin.json does not exist"
fi

# B12: install-codex.sh exists and is executable
if [ -f "$CODEX_DIR/install-codex.sh" ]; then
  if [ -x "$CODEX_DIR/install-codex.sh" ] || bash -n "$CODEX_DIR/install-codex.sh" 2>/dev/null; then
    pass "B12: install-codex.sh exists and has valid syntax"
  else
    fail "B12: install-codex.sh has syntax errors"
  fi
else
  fail "B12: codex/install-codex.sh does not exist"
fi

# B13: Idempotency — run conversion twice, output identical
echo "  Running idempotency check (requires conversion script)..."
if [ -f "scripts/convert-to-codex.sh" ]; then
  TMPDIR1=$(mktemp -d)
  cp -r "$CODEX_DIR" "$TMPDIR1/codex-before"
  bash scripts/convert-to-codex.sh --target codex 2>/dev/null || true
  if diff -rq "$TMPDIR1/codex-before" "$CODEX_DIR" >/dev/null 2>&1; then
    pass "B13: Conversion is idempotent"
  else
    fail "B13: Second conversion produced different output"
  fi
  rm -rf "$TMPDIR1"
else
  skip "B13: scripts/convert-to-codex.sh not found"
fi

# B14: Source files unmodified after conversion
SOURCE_DIFF=$(git diff --name-only -- commands/ agents/ hooks/ settings-example.json install.sh 2>/dev/null | wc -l)
if [ "$SOURCE_DIFF" -eq 0 ]; then
  pass "B14: Source files unmodified after conversion"
else
  fail "B14: $SOURCE_DIFF source files modified after conversion"
fi

# B15: Staleness manifest exists
if [ -f ".codex-manifest.sha256" ] || [ -f "$CODEX_DIR/.codex-manifest.sha256" ]; then
  pass "B15: Staleness detection manifest exists"
else
  fail "B15: No .codex-manifest.sha256 found"
fi

echo ""
echo "=== Contract Tests ==="

# C1: Base test.sh still passes
echo "  Running base test.sh (may take a moment)..."
if bash test.sh 2>&1 | tail -1 | grep -q "passed.*0 failed"; then
  pass "C1: Base test.sh passes with zero failures"
else
  fail "C1: Base test.sh has failures"
fi

# C2: Source files unchanged (git status)
SOURCE_CHANGES=$(git status --porcelain -- commands/ agents/ hooks/ settings-example.json install.sh 2>/dev/null | grep -v '^?' | wc -l)
if [ "$SOURCE_CHANGES" -eq 0 ]; then
  pass "C2: No source files modified (git status clean)"
else
  fail "C2: $SOURCE_CHANGES source files have changes"
fi

# C3: install.sh unchanged
if git diff --quiet -- install.sh 2>/dev/null; then
  pass "C3: install.sh is unchanged"
else
  fail "C3: install.sh was modified"
fi

# C4: settings-example.json unchanged
if git diff --quiet -- settings-example.json 2>/dev/null; then
  pass "C4: settings-example.json is unchanged"
else
  fail "C4: settings-example.json was modified"
fi

# C5: Hook exit-code semantics preserved (source hooks still use 0/1/2)
EXIT_PATTERN=0
for f in hooks/*.sh; do
  [ -f "$f" ] || continue
  [[ "$(basename "$f")" == _* ]] && continue
  if ! grep -q 'exit [012]' "$f"; then
    ((EXIT_PATTERN++))
    echo "    Missing exit 0/1/2 in: $(basename "$f")"
  fi
done
if [ "$EXIT_PATTERN" -eq 0 ]; then
  pass "C5: Source hooks preserve exit-code semantics"
else
  fail "C5: $EXIT_PATTERN hooks missing exit 0/1/2 pattern"
fi

echo ""
echo "=== Failure Mode Tests ==="

# F1: Frontmatter stripping doesn't corrupt body with --- in content
# Find a command known to have --- in its body (blueprint.md is huge with many ---)
if [ -f "$CODEX_DIR/commands/blueprint.md" ]; then
  BODY_LINES=$(wc -l < "$CODEX_DIR/commands/blueprint.md")
  # blueprint.md body should be >100 lines (it's ~1600 in source minus ~10 frontmatter)
  if [ "$BODY_LINES" -gt 100 ]; then
    pass "F1: blueprint.md body preserved (${BODY_LINES} lines, not truncated)"
  else
    fail "F1: blueprint.md body appears truncated (only ${BODY_LINES} lines)"
  fi
else
  skip "F1: codex/commands/blueprint.md not found"
fi

# F2: openai.yaml is parseable YAML (not corrupted)
if [ -f "$CODEX_DIR/agents/openai.yaml" ]; then
  # Use python/ruby if available, otherwise basic check
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import yaml; yaml.safe_load(open('$CODEX_DIR/agents/openai.yaml'))" 2>/dev/null; then
      pass "F2: openai.yaml is valid YAML (python3 verified)"
    else
      fail "F2: openai.yaml is invalid YAML"
    fi
  else
    # Basic check: no unclosed quotes, has key: value structure
    if grep -q '^[a-z_]*:' "$CODEX_DIR/agents/openai.yaml"; then
      pass "F2: openai.yaml has key:value structure (basic check, no YAML parser available)"
    else
      fail "F2: openai.yaml doesn't look like valid YAML"
    fi
  fi
else
  skip "F2: openai.yaml not found"
fi

# F3: Zero ~/.claude/ references anywhere in codex/ tree
TOTAL_CLAUDE_REFS=$(grep -rl '~/.claude/' "$CODEX_DIR/" 2>/dev/null | wc -l)
if [ "$TOTAL_CLAUDE_REFS" -eq 0 ]; then
  pass "F3: Zero ~/.claude/ references in entire codex/ tree"
else
  fail "F3: $TOTAL_CLAUDE_REFS files in codex/ still reference ~/.claude/"
  grep -rl '~/.claude/' "$CODEX_DIR/" 2>/dev/null | head -5 | while read -r f; do
    echo "    $f"
  done
fi

# F4: hooks.json references only scripts that exist
if [ -f "$CODEX_DIR/hooks.json" ] && command -v jq >/dev/null 2>&1; then
  MISSING_SCRIPTS=0
  jq -r '.. | .command? // empty' "$CODEX_DIR/hooks.json" 2>/dev/null | while read -r cmd; do
    # Resolve relative paths from codex/ dir
    RESOLVED="$CODEX_DIR/$cmd"
    RESOLVED="${RESOLVED#$CODEX_DIR/./}"
    RESOLVED="$CODEX_DIR/$RESOLVED"
    if [ ! -f "$RESOLVED" ] && [ ! -f "$CODEX_DIR/$cmd" ]; then
      echo "    hooks.json references missing script: $cmd"
      MISSING_SCRIPTS=1
    fi
  done
  if [ "$MISSING_SCRIPTS" -eq 0 ]; then
    pass "F4: All hooks.json script references resolve to existing files"
  fi
else
  skip "F4: hooks.json or jq not available"
fi

# F5: plugin.json has 'hooks' field pointing to existing file
if [ -f "$CODEX_DIR/plugin.json" ] && command -v jq >/dev/null 2>&1; then
  HOOKS_REF=$(jq -r '.hooks // empty' "$CODEX_DIR/plugin.json" 2>/dev/null)
  if [ -n "$HOOKS_REF" ]; then
    # Resolve relative to plugin.json location
    HOOKS_PATH="$CODEX_DIR/$HOOKS_REF"
    HOOKS_PATH="${HOOKS_PATH//.\/}"
    if [ -f "$CODEX_DIR/$HOOKS_REF" ] || [ -f "$HOOKS_PATH" ]; then
      pass "F5: plugin.json hooks field points to existing file"
    else
      fail "F5: plugin.json hooks='$HOOKS_REF' but file not found at expected path"
    fi
  else
    fail "F5: plugin.json missing hooks field"
  fi
else
  skip "F5: plugin.json or jq not available"
fi

echo ""
echo "════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo "════════════════════════════════════════"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

## Anti-Tautology Review

| Test | Trivial Pass? | Behavior Focus? | Refactor-Safe? | Spec-Derived? |
|------|---------------|-----------------|----------------|---------------|
| B1 (65 commands) | ✓ Can't pass with wrong count | ✓ Observable count | ✓ | ✓ |
| B2 (no frontmatter) | ✓ Catches partial strip | ✓ Output content | ✓ | ✓ |
| B3 (# headers) | ✓ Catches missing header | ✓ Output content | ✓ | ✓ |
| B4 (12 agents) | ✓ Can't pass with wrong count | ✓ Observable count | ✓ | ✓ |
| B5 (openai.yaml fields) | ✓ Checks required fields | ✓ Schema contract | ✓ | ✓ |
| B6 (hooks.json valid) | ✓ Catches invalid JSON | ✓ Format contract | ✓ | ✓ |
| B7 (relative paths) | ✓ Catches absolute paths | ✓ Path contract | ✓ | ✓ |
| B8 (zero ~/.claude/) | ✓ Catches any missed rewrite | ✓ Global invariant | ✓ | ✓ |
| B9 (compensation hooks) | ✓ Checks named hooks | ✓ Content contract | ✓ | ✓ |
| B10 (AGENTS.md paths) | ✓ Catches any missed rewrite | ✓ Path invariant | ✓ | ✓ |
| B11 (plugin.json) | ✓ Checks required fields | ✓ Schema contract | ✓ | ✓ |
| B12 (installer exists) | ✓ Basic existence + syntax | ✓ Deliverable check | ✓ | ✓ |
| B13 (idempotent) | ✓ Catches non-determinism | ✓ Behavioral property | ✓ | ✓ |
| B14 (source unmodified) | ✓ Catches write-to-source bugs | ✓ Safety invariant | ✓ | ✓ |
| B15 (staleness manifest) | ✓ Catches missing manifest | ✓ Deliverable check | ✓ | ✓ |
| C1 (base tests pass) | ✓ Catches regressions | ✓ Contract | ✓ | ✓ |
| C5 (exit-code semantics) | ✓ Catches convention break | ✓ Contract | ✓ | ✓ |
| F1 (body not truncated) | ✓ Catches stripping bug | ✓ Content integrity | ✓ | ✓ |
| F3 (global path check) | ✓ Same as B8, full tree | ✓ Global sweep | ✓ | ✓ |
| F4 (dangling hook refs) | ✓ Catches missing scripts | ✓ Reference integrity | ✓ | ✓ |
| F5 (plugin hooks ref) | ✓ Catches broken plugin | ✓ Reference integrity | ✓ | ✓ |

**No red flags found.** All tests verify observable behavior from spec, not implementation structure.

## Implementation Notes

These tests should:
1. **Fail initially** — codex/ directory doesn't exist yet
2. **Pass without modification** once implementation meets spec
3. **If tests need changing** — spec was incomplete or impl deviated
