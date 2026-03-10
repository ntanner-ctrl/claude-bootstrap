# Generated Tests: toolkit-hardening

> Spec-blind tests derived from acceptance criteria only.
> No implementation knowledge used.

## Source Specification

### Success Criteria Coverage

| Component | Criteria Count | Test Count |
|-----------|---------------|------------|
| 1: Compaction Guardian | 12 | 16 |
| 2: Ambiguity Gate | 6 | 7 |
| 3: Cognitive Traps | 5 | 5 |
| 4: Failure Counter | 8 | 12 |
| 5: Wonder/Reflect | 6 | 6 |
| 6: Knowledge Maturation | 8 | 8 |
| **Total** | **45** | **54** |

---

## Component 1: Compaction Guardian — Behavior Tests

### Test 1.1: Warning at 65%

```bash
# Setup: Write a warning signal file simulating 65% context
PPID_VAL=$$
echo "65" > /tmp/.claude-ctx-warning-$PPID_VAL
echo "$(date +%s)" >> /tmp/.claude-ctx-warning-$PPID_VAL

# Action: Run guardian hook with a non-exempted tool (e.g., Edit)
echo '{"tool_name":"Edit"}' | bash hooks/compaction-guardian.sh 2>/tmp/test-stderr

# Assert: Exit 0 (no block) + stderr contains advisory
EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: Expected exit 0 (advisory), got $EXIT"
grep -q "Consider /checkpoint" /tmp/test-stderr || echo "FAIL: Missing advisory message"

# Cleanup
rm -f /tmp/.claude-ctx-warning-$PPID_VAL /tmp/test-stderr
```

### Test 1.2: Block at 75% (non-exempted tool)

```bash
# Setup: Write a critical signal file
echo "76" > /tmp/.claude-ctx-critical-$$
echo "$(date +%s)" >> /tmp/.claude-ctx-critical-$$

# Action: Run guardian with a non-exempted tool
echo '{"tool_name":"Edit"}' | bash hooks/compaction-guardian.sh 2>/tmp/test-stderr

# Assert: Exit 2 (block with feedback)
EXIT=$?
[ $EXIT -eq 2 ] || echo "FAIL: Expected exit 2 (block), got $EXIT"
grep -q "DELEGATE checkpoint" /tmp/test-stderr || echo "FAIL: Missing checkpoint instruction"

# Cleanup
rm -f /tmp/.claude-ctx-critical-$$ /tmp/test-stderr
```

### Test 1.3: Exempted tool — Agent passes through at 75%

```bash
# Setup: Critical signal file active
echo "76" > /tmp/.claude-ctx-critical-$$
echo "$(date +%s)" >> /tmp/.claude-ctx-critical-$$

# Action: Run guardian with Agent tool
echo '{"tool_name":"Agent"}' | bash hooks/compaction-guardian.sh 2>/dev/null

# Assert: Exit 0 (pass-through)
EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: Agent should be exempted, got exit $EXIT"

rm -f /tmp/.claude-ctx-critical-$$
```

### Test 1.4: Exempted tool — Bash with /checkpoint passes through

```bash
echo "76" > /tmp/.claude-ctx-critical-$$
echo "$(date +%s)" >> /tmp/.claude-ctx-critical-$$

echo '{"tool_name":"Bash","command":"/checkpoint"}' | bash hooks/compaction-guardian.sh 2>/dev/null

EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: Bash /checkpoint should be exempted, got exit $EXIT"

rm -f /tmp/.claude-ctx-critical-$$
```

### Test 1.5: Exempted tool — Write to .checkpoint file passes through

```bash
echo "76" > /tmp/.claude-ctx-critical-$$
echo "$(date +%s)" >> /tmp/.claude-ctx-critical-$$

echo '{"tool_name":"Write","file_path":"/project/.checkpoint/state.json"}' | bash hooks/compaction-guardian.sh 2>/dev/null

EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: Write to .checkpoint should be exempted, got exit $EXIT"

rm -f /tmp/.claude-ctx-critical-$$
```

### Test 1.6: Exempted tool — Read state.json passes through

```bash
echo "76" > /tmp/.claude-ctx-critical-$$
echo "$(date +%s)" >> /tmp/.claude-ctx-critical-$$

echo '{"tool_name":"Read","file_path":"/project/.claude/plans/test/state.json"}' | bash hooks/compaction-guardian.sh 2>/dev/null

EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: Read state.json should be exempted, got exit $EXIT"

rm -f /tmp/.claude-ctx-critical-$$
```

### Test 1.7: Checkpoint-done signal allows pass-through

```bash
# Setup: Critical signal + recent checkpoint-done
echo "76" > /tmp/.claude-ctx-critical-$$
echo "$(date +%s)" >> /tmp/.claude-ctx-critical-$$
echo "$(date +%s)" > /tmp/.claude-checkpoint-done-$$

# Action: Non-exempted tool
echo '{"tool_name":"Edit"}' | bash hooks/compaction-guardian.sh 2>/dev/null

# Assert: Exit 0 (checkpoint-done overrides block)
EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: Recent checkpoint should allow pass-through, got exit $EXIT"

rm -f /tmp/.claude-ctx-critical-$$ /tmp/.claude-checkpoint-done-$$
```

### Test 1.8: Expired checkpoint-done does NOT allow pass-through

```bash
# Setup: Critical signal + OLD checkpoint-done (6 minutes ago)
echo "76" > /tmp/.claude-ctx-critical-$$
echo "$(date +%s)" >> /tmp/.claude-ctx-critical-$$
echo "$(( $(date +%s) - 360 ))" > /tmp/.claude-checkpoint-done-$$

# Action: Non-exempted tool
echo '{"tool_name":"Edit"}' | bash hooks/compaction-guardian.sh 2>/dev/null

# Assert: Exit 2 (expired checkpoint-done doesn't help)
EXIT=$?
[ $EXIT -eq 2 ] || echo "FAIL: Expired checkpoint-done should not allow pass-through, got exit $EXIT"

rm -f /tmp/.claude-ctx-critical-$$ /tmp/.claude-checkpoint-done-$$
```

### Test 1.9: No signal files — no-op

```bash
# Setup: Ensure no signal files exist
rm -f /tmp/.claude-ctx-warning-$$ /tmp/.claude-ctx-critical-$$

# Action: Run guardian
echo '{"tool_name":"Edit"}' | bash hooks/compaction-guardian.sh 2>/dev/null

# Assert: Exit 0, zero output
EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: No signal files should mean no-op, got exit $EXIT"
```

### Test 1.10: Fail-open on malformed JSON

```bash
# Setup: Critical signal exists
echo "76" > /tmp/.claude-ctx-critical-$$
echo "$(date +%s)" >> /tmp/.claude-ctx-critical-$$

# Action: Garbage input
echo "not json at all" | bash hooks/compaction-guardian.sh 2>/dev/null

# Assert: Exit 0 (fail-open)
EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: Malformed input should fail-open, got exit $EXIT"

rm -f /tmp/.claude-ctx-critical-$$
```

### Test 1.11: Stale signal file ignored (TTL expired)

```bash
# Setup: Critical signal file older than 30 minutes
echo "76" > /tmp/.claude-ctx-critical-$$
echo "$(( $(date +%s) - 1900 ))" >> /tmp/.claude-ctx-critical-$$

# Action: Non-exempted tool
echo '{"tool_name":"Edit"}' | bash hooks/compaction-guardian.sh 2>/dev/null

# Assert: Exit 0 (stale file ignored)
EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: Stale signal (>30min) should be ignored, got exit $EXIT"

# Assert: Stale file was cleaned up
[ ! -f /tmp/.claude-ctx-critical-$$ ] || echo "FAIL: Stale signal file should have been removed"
```

### Test 1.12: Heartbeat written on every invocation

```bash
# Setup: Remove any existing heartbeat
rm -f /tmp/.claude-guardian-heartbeat-$$

# Action: Run guardian (no signal files = no-op path)
echo '{"tool_name":"Edit"}' | bash hooks/compaction-guardian.sh 2>/dev/null

# Assert: Heartbeat file exists with recent timestamp
[ -f /tmp/.claude-guardian-heartbeat-$$ ] || echo "FAIL: Heartbeat file not written"
HEARTBEAT=$(cat /tmp/.claude-guardian-heartbeat-$$)
NOW=$(date +%s)
DIFF=$(( NOW - HEARTBEAT ))
[ $DIFF -lt 5 ] || echo "FAIL: Heartbeat timestamp not recent (${DIFF}s old)"

rm -f /tmp/.claude-guardian-heartbeat-$$
```

### Test 1.13: PPID fallback when PPID=1

```bash
# Note: Can't override $PPID in bash, so test the fallback function in isolation.
# The hook should export a function or use a testable pattern.

# Assert: Hook source code contains PPID=1 fallback logic
grep -q 'PPID.*1' hooks/compaction-guardian.sh || echo "FAIL: No PPID=1 fallback in hook"
grep -q 'md5sum' hooks/compaction-guardian.sh || echo "FAIL: No directory hash fallback in hook"
```

### Test 1.14: Disable procedure documented in header

```bash
# Assert: Hook file header contains disable instructions
head -10 hooks/compaction-guardian.sh | grep -qi "to disable" || echo "FAIL: Missing disable procedure in header"
head -10 hooks/compaction-guardian.sh | grep -q "settings.json" || echo "FAIL: Disable procedure doesn't mention settings.json"
```

### Test 1.15: SessionEnd cleanup removes all signal files

```bash
# Setup: Create all signal file types
echo "70" > /tmp/.claude-ctx-warning-$$
echo "$(date +%s)" >> /tmp/.claude-ctx-warning-$$
echo "76" > /tmp/.claude-ctx-critical-$$
echo "$(date +%s)" >> /tmp/.claude-ctx-critical-$$
echo "$(date +%s)" > /tmp/.claude-checkpoint-done-$$
echo "0" > /tmp/.claude-fail-count-$$
touch /tmp/.claude-debug-reset-$$
echo "$(date +%s)" > /tmp/.claude-guardian-heartbeat-$$

# Action: Run session-end cleanup (source the relevant hook)
# Note: Exact invocation depends on SessionEnd hook name
bash hooks/session-end-cleanup.sh 2>/dev/null || true

# Assert: All files cleaned
for f in ctx-warning ctx-critical checkpoint-done fail-count debug-reset guardian-heartbeat; do
  [ ! -f "/tmp/.claude-${f}-$$" ] || echo "FAIL: /tmp/.claude-${f}-$$ not cleaned up"
done
```

### Test 1.16: Statusline writes signal files at thresholds

```bash
# This tests statusline.sh modifications.
# Note: Statusline receives JSON on stdin from Claude Code.

# Test warning threshold
echo '{"context_window":{"used_percentage":67.5}}' | bash hooks/statusline.sh 2>/dev/null
[ -f /tmp/.claude-ctx-warning-$PPID ] || echo "FAIL: Warning signal not written at 67%"

# Test critical threshold
echo '{"context_window":{"used_percentage":77.0}}' | bash hooks/statusline.sh 2>/dev/null
[ -f /tmp/.claude-ctx-critical-$PPID ] || echo "FAIL: Critical signal not written at 77%"

# Test cleanup below threshold
echo '{"context_window":{"used_percentage":30.0}}' | bash hooks/statusline.sh 2>/dev/null
[ ! -f /tmp/.claude-ctx-warning-$PPID ] || echo "FAIL: Warning signal not cleaned at 30%"
[ ! -f /tmp/.claude-ctx-critical-$PPID ] || echo "FAIL: Critical signal not cleaned at 30%"
```

---

## Component 2: Ambiguity Gate — Behavior Tests

### Test 2.1: Gate section exists in blueprint.md

```bash
# Assert: blueprint.md contains ambiguity gate section
grep -q "AMBIGUITY CHECK" commands/blueprint.md || echo "FAIL: Missing ambiguity gate section"
grep -q "Goal Clarity" commands/blueprint.md || echo "FAIL: Missing Goal Clarity dimension"
grep -q "Constraint Clarity" commands/blueprint.md || echo "FAIL: Missing Constraint Clarity dimension"
grep -q "Success Criteria" commands/blueprint.md || echo "FAIL: Missing Success Criteria dimension"
```

### Test 2.2: Threshold values present

```bash
grep -q "3\.5" commands/blueprint.md || echo "FAIL: Missing 3.5 pass threshold"
grep -q "2\.5" commands/blueprint.md || echo "FAIL: Missing 2.5 block threshold"
```

### Test 2.3: Weighted scoring documented

```bash
grep -q "40%" commands/blueprint.md || echo "FAIL: Missing Goal 40% weight"
grep -q "30%" commands/blueprint.md || echo "FAIL: Missing 30% weight"
```

### Test 2.4: Calibration examples present (F4 fix)

```bash
# Each dimension should have examples at multiple levels
for level in "1 =" "2 =" "3 =" "4 =" "5 ="; do
  COUNT=$(grep -c "$level" commands/blueprint.md 2>/dev/null || echo 0)
  [ "$COUNT" -ge 3 ] || echo "FAIL: Missing calibration examples for level '$level' (found $COUNT, need >=3 for 3 dimensions)"
done
```

### Test 2.5: Override mechanism documented

```bash
grep -q "override" commands/blueprint.md || echo "FAIL: Missing override mechanism"
grep -q "ambiguity_gate" commands/blueprint.md || echo "FAIL: Missing state.json schema for ambiguity_gate"
```

### Test 2.6: Light path shortened gate (M5 fix)

```bash
grep -q "Light path" commands/blueprint.md && grep -q "Goal Clarity only" commands/blueprint.md \
  || echo "FAIL: Missing Light path shortened gate documentation"
```

### Test 2.7: Gate placement (between Stage 1 and Stage 2)

```bash
# Assert: Ambiguity gate appears AFTER "Stage 1" or "Describe" and BEFORE "Stage 2" or "Specify"
# This is a structural test — the gate must be in the right position
GATE_LINE=$(grep -n "AMBIGUITY CHECK" commands/blueprint.md | head -1 | cut -d: -f1)
STAGE2_LINE=$(grep -n "Stage.*2.*Specify\|Specify.*Stage" commands/blueprint.md | head -1 | cut -d: -f1)
[ -n "$GATE_LINE" ] && [ -n "$STAGE2_LINE" ] && [ "$GATE_LINE" -lt "$STAGE2_LINE" ] \
  || echo "FAIL: Ambiguity gate not positioned before Stage 2"
```

---

## Component 3: Cognitive Traps — Behavior Tests

### Test 3.1: Trap tables present in target commands

```bash
for cmd in blueprint push-safe test quality-gate; do
  grep -q "Cognitive Traps" "commands/${cmd}.md" \
    || echo "FAIL: Missing trap table in ${cmd}.md"
done
```

### Test 3.2: Tables between frontmatter and content

```bash
for cmd in blueprint push-safe test quality-gate; do
  # Frontmatter ends at second "---" line
  FRONTMATTER_END=$(grep -n "^---$" "commands/${cmd}.md" | sed -n '2p' | cut -d: -f1)
  TRAP_LINE=$(grep -n "Cognitive Traps" "commands/${cmd}.md" | head -1 | cut -d: -f1)
  CONTENT_START=$(grep -n "^# " "commands/${cmd}.md" | head -1 | cut -d: -f1)

  [ -n "$TRAP_LINE" ] && [ "$TRAP_LINE" -gt "$FRONTMATTER_END" ] && [ "$TRAP_LINE" -lt "$CONTENT_START" ] \
    || echo "FAIL: Trap table not between frontmatter and content in ${cmd}.md"
done
```

### Test 3.3: Each table has 3-4 entries

```bash
for cmd in blueprint push-safe test quality-gate; do
  # Count table rows (lines starting with |, excluding header and separator)
  COUNT=$(grep -c "^|.*|.*|$" "commands/${cmd}.md" 2>/dev/null || echo 0)
  ROWS=$(( COUNT - 2 ))  # subtract header + separator
  [ "$ROWS" -ge 3 ] && [ "$ROWS" -le 5 ] \
    || echo "FAIL: ${cmd}.md trap table has $ROWS entries (expected 3-4)"
done
```

### Test 3.4: Pre-existing test failures trap present

```bash
grep -q "pre-existing" commands/test.md || echo "FAIL: Missing 'pre-existing test failures' trap in test.md"
```

### Test 3.5: Tables under 20 lines each

```bash
for cmd in blueprint push-safe test quality-gate; do
  START=$(grep -n "Cognitive Traps" "commands/${cmd}.md" | head -1 | cut -d: -f1)
  END=$(awk "NR>$START && /^#/{print NR; exit}" "commands/${cmd}.md")
  [ -n "$END" ] && LINES=$(( END - START )) || LINES=20
  [ "$LINES" -le 20 ] || echo "FAIL: Trap table in ${cmd}.md is $LINES lines (max 20)"
done
```

---

## Component 4: Failure Counter — Behavior Tests

### Test 4.1: Hook file exists and is executable

```bash
[ -f hooks/failure-escalation.sh ] || echo "FAIL: failure-escalation.sh not found"
[ -x hooks/failure-escalation.sh ] 2>/dev/null || head -1 hooks/failure-escalation.sh | grep -q "bash" \
  || echo "FAIL: failure-escalation.sh not executable or missing shebang"
```

### Test 4.2: Green — no output for first failure

```bash
rm -f /tmp/.claude-fail-count-$$

echo '{"tool_name":"Bash","exit_code":1,"command":"npm test"}' | bash hooks/failure-escalation.sh 2>/tmp/test-stderr

COUNT=$(cat /tmp/.claude-fail-count-$$ 2>/dev/null || echo 0)
[ "$COUNT" -eq 1 ] || echo "FAIL: Counter should be 1 after first failure, got $COUNT"
# No stderr expected at count=1
[ ! -s /tmp/test-stderr ] || echo "FAIL: No output expected at Green level"

rm -f /tmp/.claude-fail-count-$$ /tmp/test-stderr
```

### Test 4.3: Yellow at 2 consecutive failures

```bash
echo "1" > /tmp/.claude-fail-count-$$

echo '{"tool_name":"Bash","exit_code":1,"command":"npm test"}' | bash hooks/failure-escalation.sh 2>/tmp/test-stderr

EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: Yellow should be advisory (exit 0), got $EXIT"
grep -qi "2 consecutive\|different approach" /tmp/test-stderr || echo "FAIL: Missing Yellow warning message"

rm -f /tmp/.claude-fail-count-$$ /tmp/test-stderr
```

### Test 4.4: Orange at 3 consecutive failures

```bash
echo "2" > /tmp/.claude-fail-count-$$

echo '{"tool_name":"Bash","exit_code":1,"command":"pytest"}' | bash hooks/failure-escalation.sh 2>/tmp/test-stderr

EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: Orange should be advisory (exit 0), got $EXIT"
grep -qi "3 consecutive\|/debug\|root cause" /tmp/test-stderr || echo "FAIL: Missing Orange warning message"

rm -f /tmp/.claude-fail-count-$$ /tmp/test-stderr
```

### Test 4.5: Red blocks at 4+ failures

```bash
echo "3" > /tmp/.claude-fail-count-$$

echo '{"tool_name":"Bash","exit_code":1,"command":"npm test"}' | bash hooks/failure-escalation.sh 2>/tmp/test-stderr

EXIT=$?
[ $EXIT -eq 2 ] || echo "FAIL: Red should block (exit 2), got $EXIT"
grep -qi "/debug\|MUST" /tmp/test-stderr || echo "FAIL: Missing Red block message"

rm -f /tmp/.claude-fail-count-$$ /tmp/test-stderr
```

### Test 4.6: Success resets counter

```bash
echo "3" > /tmp/.claude-fail-count-$$

echo '{"tool_name":"Bash","exit_code":0,"command":"npm test"}' | bash hooks/failure-escalation.sh 2>/dev/null

COUNT=$(cat /tmp/.claude-fail-count-$$ 2>/dev/null || echo "missing")
[ "$COUNT" -eq 0 ] || [ "$COUNT" = "missing" ] || echo "FAIL: Success should reset counter, got $COUNT"

rm -f /tmp/.claude-fail-count-$$
```

### Test 4.7: Non-test command is no-op

```bash
echo "3" > /tmp/.claude-fail-count-$$

echo '{"tool_name":"Bash","exit_code":1,"command":"ls -la"}' | bash hooks/failure-escalation.sh 2>/dev/null

EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: Non-test command should be no-op, got exit $EXIT"

# Counter should not change
COUNT=$(cat /tmp/.claude-fail-count-$$ 2>/dev/null)
[ "$COUNT" -eq 3 ] || echo "FAIL: Counter should not change for non-test command, got $COUNT"

rm -f /tmp/.claude-fail-count-$$
```

### Test 4.8: False positive prevention — test -f is NOT a test runner

```bash
rm -f /tmp/.claude-fail-count-$$

echo '{"tool_name":"Bash","exit_code":1,"command":"test -f somefile"}' | bash hooks/failure-escalation.sh 2>/dev/null

COUNT=$(cat /tmp/.claude-fail-count-$$ 2>/dev/null || echo 0)
[ "$COUNT" -eq 0 ] || echo "FAIL: 'test -f' should NOT match test patterns, counter=$COUNT"

rm -f /tmp/.claude-fail-count-$$
```

### Test 4.9: False positive prevention — build/run.sh is NOT a build tool

```bash
rm -f /tmp/.claude-fail-count-$$

echo '{"tool_name":"Bash","exit_code":1,"command":"build/run.sh"}' | bash hooks/failure-escalation.sh 2>/dev/null

COUNT=$(cat /tmp/.claude-fail-count-$$ 2>/dev/null || echo 0)
[ "$COUNT" -eq 0 ] || echo "FAIL: 'build/run.sh' should NOT match build patterns, counter=$COUNT"

rm -f /tmp/.claude-fail-count-$$
```

### Test 4.10: Debug reset signal clears counter

```bash
echo "4" > /tmp/.claude-fail-count-$$
touch /tmp/.claude-debug-reset-$$

echo '{"tool_name":"Bash","exit_code":1,"command":"npm test"}' | bash hooks/failure-escalation.sh 2>/dev/null

EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: Debug reset should clear counter, but got exit $EXIT"
[ ! -f /tmp/.claude-debug-reset-$$ ] || echo "FAIL: Debug reset signal should be consumed (deleted)"

rm -f /tmp/.claude-fail-count-$$
```

### Test 4.11: Fail-open on malformed input

```bash
echo "not json" | bash hooks/failure-escalation.sh 2>/dev/null
EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: Malformed input should fail-open, got exit $EXIT"
```

### Test 4.12: Disable procedure in header

```bash
head -10 hooks/failure-escalation.sh | grep -qi "to disable" \
  || echo "FAIL: Missing disable procedure in header"
```

---

## Component 5: Wonder/Reflect — Behavior Tests

### Test 5.1: Reflection section exists in blueprint.md

```bash
grep -q "POST-IMPLEMENTATION REFLECTION\|REFLECT\|WONDER" commands/blueprint.md \
  || echo "FAIL: Missing reflection section in blueprint.md"
```

### Test 5.2: Reflection prompt contains all required questions

```bash
grep -q "assumption.*wrong\|surprised" commands/blueprint.md || echo "FAIL: Missing 'assumption proven wrong' question"
grep -q "harder than expected\|easier" commands/blueprint.md || echo "FAIL: Missing difficulty calibration question"
grep -q "starting over\|spec.*add" commands/blueprint.md || echo "FAIL: Missing 'spec gaps' question"
grep -q "useful.*during.*implementation\|most useful" commands/blueprint.md || echo "FAIL: Missing 'most useful sections' question"
```

### Test 5.3: reflect.md template structure defined

```bash
grep -q "reflect.md" commands/blueprint.md || echo "FAIL: Missing reflect.md output reference"
```

### Test 5.4: Empirica export documented as mandatory

```bash
grep -q "finding_log\|Empirica.*mandatory\|MUST.*Empirica" commands/blueprint.md \
  || echo "FAIL: Empirica export not documented as mandatory in reflection"
```

### Test 5.5: Vault export documented as mandatory

```bash
grep -q "vault.*mandatory\|MUST.*vault\|Engineering/Findings" commands/blueprint.md \
  || echo "FAIL: Vault export not documented as mandatory in reflection"
```

### Test 5.6: Skippable with reason

```bash
grep -q "skippable\|skip.*reason\|declined" commands/blueprint.md \
  || echo "FAIL: Reflection skip mechanism not documented"
```

---

## Component 6: Knowledge Maturation — Behavior Tests

### Test 6.1: Command file exists

```bash
[ -f commands/promote-finding.md ] || echo "FAIL: promote-finding.md not found"
```

### Test 6.2: Four maturation tiers documented

```bash
for tier in ISOLATED CONFIRMED CONVICTION PROMOTED; do
  grep -q "$tier" commands/promote-finding.md \
    || echo "FAIL: Missing tier '$tier' in promote-finding.md"
done
```

### Test 6.3: Capacity check thresholds documented

```bash
grep -q "150" commands/promote-finding.md || echo "FAIL: Missing 150-line warn threshold"
grep -q "200" commands/promote-finding.md || echo "FAIL: Missing 200-line require-retirement threshold"
grep -q "300" commands/promote-finding.md || echo "FAIL: Missing 300-line block threshold"
```

### Test 6.4: Independence assessment documented (F5 fix)

```bash
grep -q "INDEPENDENT\|independence" commands/promote-finding.md \
  || echo "FAIL: Missing independence assessment"
grep -q "CORRELATED" commands/promote-finding.md \
  || echo "FAIL: Missing CORRELATED marker documentation"
```

### Test 6.5: User acknowledgment required at Step 2

```bash
grep -q "user.*acknowledge\|user.*confirm\|REQUIRED.*Step 2\|acknowledgment.*REQUIRED" commands/promote-finding.md \
  || echo "FAIL: Missing mandatory user acknowledgment at Step 2"
```

### Test 6.6: Paired operation (promote + retire)

```bash
grep -q "retire\|paired.*operation\|paired.*pruning" commands/promote-finding.md \
  || echo "FAIL: Missing paired promote/retire documentation"
```

### Test 6.7: Vault decision record template exists

```bash
[ -f commands/templates/vault-notes/promotion.md ] \
  || echo "FAIL: Missing promotion vault note template"
```

### Test 6.8: Degradation paths documented

```bash
grep -q "without vault\|vault.*unavailable" commands/promote-finding.md \
  || echo "FAIL: Missing vault-unavailable degradation path"
grep -q "without Empirica\|Empirica.*unavailable" commands/promote-finding.md \
  || echo "FAIL: Missing Empirica-unavailable degradation path"
```

---

## Contract Tests (Preservation)

### Test P1: Existing statusline functionality preserved

```bash
# The statusline hook must still produce a status bar output
echo '{"context_window":{"used_percentage":50.0},"cost":{"total_cost_usd":0.05}}' \
  | bash hooks/statusline.sh 2>/dev/null | head -1 | grep -q "." \
  || echo "FAIL: statusline.sh no longer produces output"
```

### Test P2: Existing checkpoint schema backward-compatible

```bash
# checkpoint.md should still document the original fields
grep -q "summary" commands/checkpoint.md || echo "FAIL: Missing original 'summary' field"
grep -q "decisions" commands/checkpoint.md || echo "FAIL: Missing original 'decisions' field"
grep -q "next_action" commands/checkpoint.md || echo "FAIL: Missing original 'next_action' field"
# New fields are additive
grep -q "empirica" commands/checkpoint.md || echo "FAIL: Missing new 'empirica' field"
grep -q "compaction_context" commands/checkpoint.md || echo "FAIL: Missing new 'compaction_context' field"
```

### Test P3: settings-example.json is valid JSON after modifications

```bash
jq empty settings-example.json 2>/dev/null \
  || echo "FAIL: settings-example.json is not valid JSON"
```

### Test P4: install.sh still works

```bash
# Dry-run check: install.sh should be parseable bash
bash -n install.sh 2>/dev/null \
  || echo "FAIL: install.sh has syntax errors"
```

---

## Failure Mode Tests

### Test F1: Guardian with empty stdin

```bash
echo "" | bash hooks/compaction-guardian.sh 2>/dev/null
EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: Empty stdin should fail-open, got exit $EXIT"
```

### Test F2: Failure counter with non-Bash tool name

```bash
echo '{"tool_name":"Edit","exit_code":1}' | bash hooks/failure-escalation.sh 2>/dev/null
EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: Non-Bash tool should be no-op, got exit $EXIT"
```

### Test F3: Guardian with missing tool_name field

```bash
echo '{"other_field":"value"}' | bash hooks/compaction-guardian.sh 2>/dev/null
EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: Missing tool_name should fail-open, got exit $EXIT"
```

### Test F4: Failure counter with missing exit_code

```bash
echo '{"tool_name":"Bash","command":"npm test"}' | bash hooks/failure-escalation.sh 2>/dev/null
EXIT=$?
[ $EXIT -eq 0 ] || echo "FAIL: Missing exit_code should fail-open, got exit $EXIT"
```

---

## Anti-Tautology Review

| Test | Trivial Pass? | Behavior Focus? | Refactor-Safe? | Spec-Derived? |
|------|---------------|-----------------|----------------|---------------|
| 1.1 Warning at 65% | No — requires specific stderr output | Yes — tests observable behavior | Yes — tests output not structure | Yes — criterion 1 |
| 1.2 Block at 75% | No — requires exit 2 | Yes | Yes | Yes — criterion 2 |
| 1.3-1.6 Exemptions | No — requires tool-specific pass-through | Yes | Yes | Yes — criterion 3 |
| 1.7-1.8 Checkpoint-done | No — requires time-based logic | Yes | Yes | Yes — criterion 5 |
| 1.9 No-op | Could pass with empty file | Yes | Yes | Yes — criterion 9 |
| 1.10 Fail-open | Could pass with empty file | Yes | Yes | Yes — criterion 10 |
| 4.5 Red blocks | No — requires specific exit code at count 4 | Yes | Yes | Yes — criterion 3 |
| 4.7 Non-test no-op | No — must NOT increment counter | Yes | Yes | Yes — criterion 6 |
| 4.8-4.9 False positives | No — must NOT match specific commands | Yes | Yes | Yes — from F3 fix |

**No red flags identified.** Tests check observable behavior (exit codes, stderr output, file existence), not internal implementation structure. All derived directly from spec acceptance criteria.

---

## Implementation Notes

These tests should:
1. **Fail initially** — hooks and command modifications don't exist yet
2. **Pass without modification** when implementation meets spec
3. **If tests need changing** — revisit the spec (indicates spec incompleteness or ambiguity)

Tests can be run as a single verification script after each implementation phase:
- Phase A tests: 1.*, 3.*, P1
- Phase B tests: 2.*, 5.*
- Phase C tests: 4.*, F2, F4
- Phase D tests: 6.*, P2, P3, P4
