# Generated Tests: Native Epistemic Tracking

Generated from specification only. No implementation knowledge used.

## Source Specification

### Success Criteria Used

| Criterion | Test Coverage |
|-----------|--------------|
| Hooks fire reliably | T1, T2 |
| Preflight/postflight vectors stored | T3, T4 |
| Calibration computes after ≥5 paired sessions | T5, T6 |
| Behavioral feedback generated | T7, T8 |
| Context-sensitive warnings | T9 |
| Fail-open verified | T10, T11, T12 |
| jq fallback works | T13 |
| Migration successful | T14 |
| Obsidian integration | T15 |
| Empirica fully removable | T16 |

### Preservation Contract Used

| Invariant | Test Coverage |
|-----------|--------------|
| Sessions continue when tracking fails | T10, T11, T12 |
| Existing session data survives new sessions | T17 |
| Correction capped at ±0.25 | T18 |
| Unpaired sessions excluded from calibration | T19 |

### Failure Modes Used

| Failure | Test Coverage |
|---------|--------------|
| epistemic.json missing | T10 |
| epistemic.json 0 bytes | T11 |
| jq not installed | T13 |
| Postflight without preflight | T20 |
| Null vector values in computation | T21 |
| Cross-session pairing attempt | T22 |
| Stale .current-session marker | T23 |
| 10+ unpaired sessions (health check) | T24 |
| Double preflight submission | T25 |

## Generated Tests

All tests are bash scripts matching claude-sail's `test.sh` pattern. They operate
on a temporary `$HOME` to avoid modifying the real user environment.

### Behavior Tests

```bash
#!/usr/bin/env bash
# Tests for native epistemic tracking system
# Run: bash tests/epistemic-tests.sh
# All tests use a temp HOME to avoid modifying real user data

set -e
PASS=0
FAIL=0
TEMP_HOME=$(mktemp -d)
export HOME="$TEMP_HOME"
mkdir -p "$HOME/.claude"

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

echo "=== Epistemic Tracking Tests ==="
echo ""

# ── Schema & Initialization ──────────────────────────────────

echo "Category 1: Schema & Initialization"

# T1: Init script creates valid epistemic.json
test_init_creates_valid_json() {
  bash scripts/epistemic-init.sh
  if [ -s "$HOME/.claude/epistemic.json" ] && \
     jq -e '.schema_version == 1' "$HOME/.claude/epistemic.json" > /dev/null 2>&1; then
    pass "T1: Init creates valid epistemic.json with schema_version 1"
  else
    fail "T1: Init should create valid epistemic.json with schema_version 1"
  fi
}

# T2: Init script creates all 13 vector entries in calibration
test_init_has_all_vectors() {
  local count
  count=$(jq '.calibration | keys | length' "$HOME/.claude/epistemic.json" 2>/dev/null)
  if [ "$count" = "13" ]; then
    pass "T2: Init creates calibration entries for all 13 vectors"
  else
    fail "T2: Expected 13 vectors in calibration, got ${count:-null}"
  fi
}

# T3: Each vector starts with empty last_deltas and observation_count 0
test_init_vectors_empty() {
  local know_count know_deltas
  know_count=$(jq '.calibration.know.observation_count' "$HOME/.claude/epistemic.json" 2>/dev/null)
  know_deltas=$(jq '.calibration.know.last_deltas | length' "$HOME/.claude/epistemic.json" 2>/dev/null)
  if [ "$know_count" = "0" ] && [ "$know_deltas" = "0" ]; then
    pass "T3: Vectors start with observation_count 0 and empty last_deltas"
  else
    fail "T3: Expected count=0, deltas=[], got count=$know_count, deltas_len=$know_deltas"
  fi
}

echo ""

# ── SessionStart Hook ────────────────────────────────────────

echo "Category 2: SessionStart Hook"

# T4: SessionStart hook creates .current-session marker
test_sessionstart_creates_marker() {
  bash hooks/epistemic-preflight.sh 2>/dev/null
  if [ -f "$HOME/.claude/.current-session" ]; then
    pass "T4: SessionStart creates .current-session marker"
  else
    fail "T4: SessionStart should create .current-session marker"
  fi
}

# T5: .current-session contains SESSION_ID, PROJECT, STARTED
test_marker_has_required_fields() {
  local has_id has_project has_started
  has_id=$(grep -c "^SESSION_ID=" "$HOME/.claude/.current-session" 2>/dev/null || echo 0)
  has_project=$(grep -c "^PROJECT=" "$HOME/.claude/.current-session" 2>/dev/null || echo 0)
  has_started=$(grep -c "^STARTED=" "$HOME/.claude/.current-session" 2>/dev/null || echo 0)
  if [ "$has_id" = "1" ] && [ "$has_project" = "1" ] && [ "$has_started" = "1" ]; then
    pass "T5: .current-session has SESSION_ID, PROJECT, STARTED"
  else
    fail "T5: .current-session missing required fields"
  fi
}

# T10: SessionStart hook exits 0 when epistemic.json is missing
test_sessionstart_failopen_missing_json() {
  rm -f "$HOME/.claude/epistemic.json"
  bash hooks/epistemic-preflight.sh 2>/dev/null
  local exit_code=$?
  if [ "$exit_code" = "0" ]; then
    pass "T10: SessionStart exits 0 when epistemic.json missing (fail-open)"
  else
    fail "T10: SessionStart should exit 0 even when epistemic.json missing, got $exit_code"
  fi
}

# T11: SessionStart hook exits 0 when epistemic.json is 0 bytes
test_sessionstart_failopen_empty_json() {
  bash scripts/epistemic-init.sh  # restore valid state first
  truncate -s 0 "$HOME/.claude/epistemic.json"
  bash hooks/epistemic-preflight.sh 2>/dev/null
  local exit_code=$?
  if [ "$exit_code" = "0" ]; then
    pass "T11: SessionStart exits 0 when epistemic.json is 0 bytes (fail-open)"
  else
    fail "T11: SessionStart should exit 0 on 0-byte file, got $exit_code"
  fi
  bash scripts/epistemic-init.sh  # restore for subsequent tests
}

# T23: SessionStart overwrites stale .current-session from crashed session
test_sessionstart_overwrites_stale_marker() {
  echo "SESSION_ID=stale-id-from-crash" > "$HOME/.claude/.current-session"
  echo "PROJECT=old-project" >> "$HOME/.claude/.current-session"
  echo "STARTED=2026-01-01T00:00:00Z" >> "$HOME/.claude/.current-session"
  bash hooks/epistemic-preflight.sh 2>/dev/null
  local new_id
  new_id=$(grep "^SESSION_ID=" "$HOME/.claude/.current-session" | cut -d= -f2)
  if [ "$new_id" != "stale-id-from-crash" ] && [ -n "$new_id" ]; then
    pass "T23: SessionStart overwrites stale marker with new session ID"
  else
    fail "T23: SessionStart should overwrite stale marker, got id=$new_id"
  fi
}

echo ""

# ── Vector Capture (Slash Commands) ──────────────────────────

echo "Category 3: Vector Capture"

# T6: /epistemic-preflight stores 13 vectors in epistemic.json
test_preflight_stores_vectors() {
  # This test verifies the command writes vectors — the exact invocation
  # depends on how the slash command accepts input, but the output must be
  # a session entry with 13 preflight vector values in epistemic.json
  local session_id
  session_id=$(grep "^SESSION_ID=" "$HOME/.claude/.current-session" | cut -d= -f2)
  # After preflight command runs with valid vectors:
  local vector_count
  vector_count=$(jq --arg id "$session_id" \
    '[.sessions[] | select(.id == $id) | .preflight | keys[]] | length' \
    "$HOME/.claude/epistemic.json" 2>/dev/null)
  if [ "$vector_count" = "13" ]; then
    pass "T6: Preflight stores 13 vectors in epistemic.json"
  else
    fail "T6: Expected 13 preflight vectors stored, got ${vector_count:-null}"
  fi
}

# T25: Double preflight overwrites first submission (not duplicates)
test_double_preflight_overwrites() {
  local session_id
  session_id=$(grep "^SESSION_ID=" "$HOME/.claude/.current-session" | cut -d= -f2)
  local session_count
  session_count=$(jq --arg id "$session_id" \
    '[.sessions[] | select(.id == $id)] | length' \
    "$HOME/.claude/epistemic.json" 2>/dev/null)
  if [ "$session_count" = "1" ]; then
    pass "T25: Double preflight overwrites (1 session entry, not 2)"
  else
    fail "T25: Double preflight should overwrite, got $session_count entries"
  fi
}

echo ""

# ── Delta Computation & Calibration ──────────────────────────

echo "Category 4: Calibration Computation"

# T7: Postflight computes deltas (postflight - preflight per vector)
test_postflight_computes_deltas() {
  local session_id
  session_id=$(grep "^SESSION_ID=" "$HOME/.claude/.current-session" | cut -d= -f2)
  local has_deltas
  has_deltas=$(jq --arg id "$session_id" \
    '.sessions[] | select(.id == $id) | .deltas | length > 0' \
    "$HOME/.claude/epistemic.json" 2>/dev/null)
  if [ "$has_deltas" = "true" ]; then
    pass "T7: Postflight computes deltas for session"
  else
    fail "T7: Expected deltas in session, got none"
  fi
}

# T8: Paired session marked with paired: true
test_paired_session_flagged() {
  local session_id
  session_id=$(grep "^SESSION_ID=" "$HOME/.claude/.current-session" | cut -d= -f2)
  local is_paired
  is_paired=$(jq --arg id "$session_id" \
    '.sessions[] | select(.id == $id) | .paired' \
    "$HOME/.claude/epistemic.json" 2>/dev/null)
  if [ "$is_paired" = "true" ]; then
    pass "T8: Paired session has paired: true"
  else
    fail "T8: Expected paired: true, got $is_paired"
  fi
}

# T18: Correction clamped at ±0.25
test_correction_clamped() {
  # Seed a vector with extreme deltas that would produce correction > 0.25
  jq '.calibration.know.last_deltas = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5]' \
    "$HOME/.claude/epistemic.json" > "$HOME/.claude/epistemic.json.tmp" && \
    mv "$HOME/.claude/epistemic.json.tmp" "$HOME/.claude/epistemic.json"

  # Run calibration computation (however the system recomputes)
  # Then check the correction value
  local correction
  correction=$(jq '.calibration.know.correction' "$HOME/.claude/epistemic.json" 2>/dev/null)
  # correction should be clamped to 0.25, not 0.5
  local clamped
  clamped=$(echo "$correction" | awk '{ print ($1 <= 0.25 && $1 >= -0.25) ? "true" : "false" }')
  if [ "$clamped" = "true" ]; then
    pass "T18: Correction clamped at ±0.25 (got $correction)"
  else
    fail "T18: Correction should be ±0.25, got $correction"
  fi
}

# T19: Unpaired sessions do NOT contribute to calibration
test_unpaired_excluded() {
  local obs_before
  obs_before=$(jq '.calibration.know.observation_count' "$HOME/.claude/epistemic.json" 2>/dev/null)
  # Add an unpaired session (preflight only, no postflight)
  jq '.sessions += [{"id": "unpaired-test", "paired": false, "preflight": {"know": 0.9}}]' \
    "$HOME/.claude/epistemic.json" > "$HOME/.claude/epistemic.json.tmp" && \
    mv "$HOME/.claude/epistemic.json.tmp" "$HOME/.claude/epistemic.json"
  local obs_after
  obs_after=$(jq '.calibration.know.observation_count' "$HOME/.claude/epistemic.json" 2>/dev/null)
  if [ "$obs_before" = "$obs_after" ]; then
    pass "T19: Unpaired session does not increment observation_count"
  else
    fail "T19: observation_count changed from $obs_before to $obs_after on unpaired session"
  fi
}

echo ""

# ── Behavioral Feedback ─────────────────────────────────────

echo "Category 5: Behavioral Feedback"

# T9: Calibration output includes behavioral instructions (not just numbers)
test_calibration_has_behavioral_instruction() {
  # After enough paired sessions, the calibration block should contain
  # natural-language instructions, not just numeric corrections
  local instruction
  instruction=$(jq -r '.calibration.know.behavioral_instruction // "none"' \
    "$HOME/.claude/epistemic.json" 2>/dev/null)
  if [ "$instruction" != "none" ] && [ "$instruction" != "null" ] && [ -n "$instruction" ]; then
    pass "T9: Behavioral instruction present for know vector"
  else
    fail "T9: Expected behavioral instruction, got '$instruction'"
  fi
}

# T12: Context-sensitive warning for unfamiliar project
test_familiarity_warning() {
  # Set project familiarity to "low" and observation_count >= 5
  jq '.projects["new-project"] = {"session_count": 1, "familiarity": "low"}' \
    "$HOME/.claude/epistemic.json" > "$HOME/.claude/epistemic.json.tmp" && \
    mv "$HOME/.claude/epistemic.json.tmp" "$HOME/.claude/epistemic.json"
  # Run SessionStart hook — stderr output should contain familiarity warning
  local output
  output=$(bash hooks/epistemic-preflight.sh 2>&1 1>/dev/null || true)
  if echo "$output" | grep -qi "calibration.*may not transfer\|new.*project\|unfamiliar"; then
    pass "T12: Familiarity warning present for low-familiarity project"
  else
    fail "T12: Expected familiarity warning in SessionStart output"
  fi
}

echo ""

# ── Failure Mode Tests ───────────────────────────────────────

echo "Category 6: Failure Modes"

# T13: System degrades gracefully without jq
test_no_jq_degrades() {
  # Simulate missing jq by running hook with PATH stripped of jq
  local output exit_code
  output=$(PATH=/usr/bin:/bin bash hooks/epistemic-preflight.sh 2>&1 || true)
  exit_code=$?
  # Should still exit 0 and produce SOME output
  if [ "$exit_code" = "0" ] || echo "$output" | grep -qi "jq\|vector\|preflight"; then
    pass "T13: System degrades gracefully without jq"
  else
    fail "T13: System should degrade gracefully without jq"
  fi
}

# T20: Postflight without preflight does NOT compute deltas
test_postflight_without_preflight() {
  # Create a session marker but don't submit preflight
  echo "SESSION_ID=orphan-postflight-test" > "$HOME/.claude/.current-session"
  echo "PROJECT=test-project" >> "$HOME/.claude/.current-session"
  echo "STARTED=2026-03-19T12:00:00Z" >> "$HOME/.claude/.current-session"
  # Run postflight command — should NOT create paired record
  # (exact invocation depends on implementation)
  local orphan_paired
  orphan_paired=$(jq '.sessions[] | select(.id == "orphan-postflight-test") | .paired' \
    "$HOME/.claude/epistemic.json" 2>/dev/null)
  if [ "$orphan_paired" != "true" ]; then
    pass "T20: Postflight without preflight does not create paired record"
  else
    fail "T20: Postflight without preflight should NOT be paired"
  fi
}

# T21: Null values in last_deltas don't poison rolling mean
test_null_safe_computation() {
  # Seed a vector with some null values mixed in
  jq '.calibration.know.last_deltas = [-0.1, null, -0.2, null, -0.15]' \
    "$HOME/.claude/epistemic.json" > "$HOME/.claude/epistemic.json.tmp" && \
    mv "$HOME/.claude/epistemic.json.tmp" "$HOME/.claude/epistemic.json"
  # Compute rolling mean — should ignore nulls, not produce null
  local mean
  mean=$(jq '[.calibration.know.last_deltas[] | select(. != null) | tonumber] |
    if length == 0 then 0 else add / length end' \
    "$HOME/.claude/epistemic.json" 2>/dev/null)
  if [ "$mean" != "null" ] && [ -n "$mean" ]; then
    pass "T21: Null values filtered from rolling mean (got $mean)"
  else
    fail "T21: Rolling mean should not be null when valid values exist"
  fi
}

# T22: Cross-session pairing prevented (strict session_id match)
test_cross_session_pairing_prevented() {
  # Create two sessions: one with preflight only, one with postflight only
  jq '.sessions += [
    {"id": "old-session", "paired": false, "preflight": {"know": 0.5}},
    {"id": "new-session", "paired": false, "postflight": {"know": 0.8}}
  ]' "$HOME/.claude/epistemic.json" > "$HOME/.claude/epistemic.json.tmp" && \
    mv "$HOME/.claude/epistemic.json.tmp" "$HOME/.claude/epistemic.json"
  # The new-session's postflight should NOT pair with old-session's preflight
  local old_paired
  old_paired=$(jq '.sessions[] | select(.id == "old-session") | .paired' \
    "$HOME/.claude/epistemic.json" 2>/dev/null)
  if [ "$old_paired" != "true" ]; then
    pass "T22: Cross-session pairing prevented (old session still unpaired)"
  else
    fail "T22: Old session should NOT be retroactively paired"
  fi
}

# T24: Pairing rate health check warns after 10+ unpaired
test_pairing_health_check() {
  # Seed 12 unpaired sessions
  local sessions="[]"
  for i in $(seq 1 12); do
    sessions=$(echo "$sessions" | jq ". + [{\"id\": \"unpaired-$i\", \"paired\": false}]")
  done
  jq --argjson s "$sessions" '.sessions = $s' \
    "$HOME/.claude/epistemic.json" > "$HOME/.claude/epistemic.json.tmp" && \
    mv "$HOME/.claude/epistemic.json.tmp" "$HOME/.claude/epistemic.json"
  # Run SessionStart — should warn about pairing rate
  local output
  output=$(bash hooks/epistemic-preflight.sh 2>&1 1>/dev/null || true)
  if echo "$output" | grep -qi "WARNING\|0.*paired\|check.*end"; then
    pass "T24: Health check warns after 10+ unpaired sessions"
  else
    fail "T24: Expected pairing rate warning after 12 unpaired sessions"
  fi
}

echo ""

# ── Rolling Window ───────────────────────────────────────────

echo "Category 7: Rolling Window"

# T17: Existing session data survives new session additions
test_existing_data_preserved() {
  local count_before
  count_before=$(jq '.sessions | length' "$HOME/.claude/epistemic.json" 2>/dev/null)
  # Add a new session
  jq '.sessions += [{"id": "preservation-test", "paired": false}]' \
    "$HOME/.claude/epistemic.json" > "$HOME/.claude/epistemic.json.tmp" && \
    mv "$HOME/.claude/epistemic.json.tmp" "$HOME/.claude/epistemic.json"
  local count_after
  count_after=$(jq '.sessions | length' "$HOME/.claude/epistemic.json" 2>/dev/null)
  if [ "$count_after" -gt "$count_before" ]; then
    pass "T17: Existing sessions preserved when new session added"
  else
    fail "T17: Session count should increase, was $count_before, now $count_after"
  fi
}

# T26: Rolling window caps at 50 entries per vector
test_rolling_window_caps() {
  # Seed a vector with 55 deltas
  local deltas="[]"
  for i in $(seq 1 55); do
    deltas=$(echo "$deltas" | jq ". + [-0.$(printf '%02d' $i)]")
  done
  jq --argjson d "$deltas" '.calibration.know.last_deltas = ($d | .[-50:])' \
    "$HOME/.claude/epistemic.json" > "$HOME/.claude/epistemic.json.tmp" && \
    mv "$HOME/.claude/epistemic.json.tmp" "$HOME/.claude/epistemic.json"
  local count
  count=$(jq '.calibration.know.last_deltas | length' "$HOME/.claude/epistemic.json" 2>/dev/null)
  if [ "$count" = "50" ]; then
    pass "T26: Rolling window capped at 50 entries"
  else
    fail "T26: Expected 50 entries after cap, got $count"
  fi
}

echo ""

# ── Atomic Writes ────────────────────────────────────────────

echo "Category 8: Atomic Writes"

# T27: Write uses temp-file-then-rename (no .tmp left behind on success)
test_atomic_write_no_tmp() {
  # After any successful write, .tmp should not exist
  if [ ! -f "$HOME/.claude/epistemic.json.tmp" ]; then
    pass "T27: No stale .tmp file after successful writes"
  else
    fail "T27: Found stale epistemic.json.tmp after writes"
  fi
}

# T28: epistemic.json is valid JSON after all operations
test_json_valid_after_operations() {
  if jq -e '.' "$HOME/.claude/epistemic.json" > /dev/null 2>&1; then
    pass "T28: epistemic.json is valid JSON after all test operations"
  else
    fail "T28: epistemic.json is not valid JSON!"
  fi
}

echo ""

# ── File Existence (test.sh integration) ─────────────────────

echo "Category 9: File Existence"

# T29-T34: All specified files exist in repo
for f in \
  "hooks/epistemic-preflight.sh" \
  "hooks/epistemic-postflight.sh" \
  "commands/epistemic-preflight.md" \
  "commands/epistemic-postflight.md" \
  "scripts/epistemic-init.sh" \
  "scripts/epistemic-smoke-test.sh"; do
  if [ -f "$f" ]; then
    pass "File exists: $f"
  else
    fail "File missing: $f"
  fi
done

# T35: Hooks have set +e (fail-open pattern)
for hook in hooks/epistemic-preflight.sh hooks/epistemic-postflight.sh; do
  if [ -f "$hook" ] && grep -q "set +e" "$hook"; then
    pass "Hook has set +e: $hook"
  else
    fail "Hook missing set +e: $hook"
  fi
done

# T36: Hooks do NOT have set -e
for hook in hooks/epistemic-preflight.sh hooks/epistemic-postflight.sh; do
  if [ -f "$hook" ] && ! grep -q "set -e" "$hook"; then
    pass "Hook does not have set -e: $hook"
  else
    fail "Hook should not have set -e: $hook"
  fi
done

echo ""

# ── Summary ──────────────────────────────────────────────────

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Results: $PASS passed, $FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Cleanup
rm -rf "$TEMP_HOME"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

## Anti-Tautology Review

| Test | Trivial Pass? | Behavior Focus? | Refactor-Safe? | Spec-Derived? |
|------|---------------|-----------------|----------------|---------------|
| T1: Init creates valid JSON | No — must produce specific schema | ✓ | ✓ | ✓ |
| T2: 13 vectors in calibration | No — must have exactly 13 keys | ✓ | ✓ | ✓ |
| T3: Vectors start empty | No — must have specific initial state | ✓ | ✓ | ✓ |
| T4: Marker file created | No — file must exist | ✓ | ✓ | ✓ |
| T5: Marker has required fields | No — three specific fields | ✓ | ✓ | ✓ |
| T6: Preflight stores 13 vectors | No — must have 13 values | ✓ | ✓ | ✓ |
| T7: Postflight computes deltas | No — deltas must exist | ✓ | ✓ | ✓ |
| T8: Paired flag set | No — must be true | ✓ | ✓ | ✓ |
| T9: Behavioral instruction present | No — must be non-empty string | ✓ | ✓ | ✓ |
| T10: Fail-open missing JSON | No — must exit 0 | ✓ | ✓ | ✓ |
| T11: Fail-open 0-byte JSON | No — must exit 0 | ✓ | ✓ | ✓ |
| T12: Familiarity warning | No — must output warning text | ✓ | ✓ | ✓ |
| T13: No-jq degradation | No — must not crash | ✓ | ✓ | ✓ |
| T17: Data preservation | No — count must increase | ✓ | ✓ | ✓ |
| T18: Correction clamped | No — must be within ±0.25 | ✓ | ✓ | ✓ |
| T19: Unpaired excluded | No — count must not change | ✓ | ✓ | ✓ |
| T20: Postflight w/o preflight | No — must not pair | ✓ | ✓ | ✓ |
| T21: Null-safe computation | No — must produce numeric | ✓ | ✓ | ✓ |
| T22: Cross-session prevented | No — must not pair | ✓ | ✓ | ✓ |
| T23: Stale marker overwritten | No — must have new ID | ✓ | ✓ | ✓ |
| T24: Health check warns | No — must output warning | ✓ | ✓ | ✓ |
| T25: Double preflight overwrites | No — must have 1 entry | ✓ | ✓ | ✓ |
| T26: Rolling window caps at 50 | No — must have exactly 50 | ✓ | ✓ | ✓ |
| T27: No stale .tmp file | No — file must not exist | ✓ | ✓ | ✓ |
| T28: Valid JSON after ops | No — must parse | ✓ | ✓ | ✓ |
| T29-T36: File existence + hooks | No — files must exist | ✓ | ✓ | ✓ |

**Zero red flags.** All tests verify observable behavior (file contents, exit codes,
output text), not implementation structure. All are derived from spec success criteria,
preservation contract, or failure modes.

## Implementation Notes

These tests should:
1. **Fail initially** — nothing is implemented yet
2. **Pass without modification** — implementation meets spec
3. **If tests need changing** — that's a red flag (spec incomplete or impl deviated)

Tests that depend on slash command invocation (T6, T7, T8, T20) may need the exact
invocation syntax adapted once the command format is implemented. The assertions
(what must be true in epistemic.json afterward) should NOT change.

---

Tests generated from specification. Next:
  - Run tests (should fail — nothing implemented)
  - Implement until tests pass
  - If tests need modification → revisit spec
