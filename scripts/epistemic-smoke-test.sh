#!/usr/bin/env bash
# epistemic-smoke-test.sh — Post-install verification for epistemic tracking
#
# Runs a mock session lifecycle (init → preflight hook → store preflight →
# store postflight → verify pairing) against a temporary HOME.
#
# Usage: bash scripts/epistemic-smoke-test.sh
# DEV-ONLY: not part of the install path.
# Requires: jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
TEMP_HOME=$(mktemp -d)
export HOME="$TEMP_HOME"

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

cleanup() { rm -rf "$TEMP_HOME"; }
trap cleanup EXIT

echo "=== Epistemic Tracking Smoke Test ==="
echo "Temp HOME: $TEMP_HOME"
echo ""

# ── Guard ────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
    echo "ERROR: jq required but not found"
    exit 1
fi

# ── 1. Init ──────────────────────────────────────────────────
echo "Phase 1: Initialization"

bash "$REPO_ROOT/scripts/epistemic-init.sh" >/dev/null 2>&1
if [ -s "$HOME/.claude/epistemic.json" ] && \
   jq -e '.schema_version == 1' "$HOME/.claude/epistemic.json" >/dev/null 2>&1; then
    pass "Init creates valid epistemic.json"
else
    fail "Init failed to create valid epistemic.json"
fi

VECTOR_COUNT=$(jq '.calibration | keys | length' "$HOME/.claude/epistemic.json" 2>/dev/null)
if [ "$VECTOR_COUNT" = "13" ]; then
    pass "All 13 vectors present in calibration"
else
    fail "Expected 13 vectors, got $VECTOR_COUNT"
fi

echo ""

# ── 2. SessionStart Hook ────────────────────────────────────
echo "Phase 2: SessionStart Hook"

# Need to be in a git repo for project detection
mkdir -p "$TEMP_HOME/test-project/.git"
cd "$TEMP_HOME/test-project"
git init -q 2>/dev/null

bash "$REPO_ROOT/hooks/epistemic-preflight.sh" 2>/dev/null
if [ -f "$HOME/.claude/.current-session" ]; then
    pass "SessionStart creates .current-session marker"
else
    fail "SessionStart should create .current-session marker"
fi

SESSION_ID=$(grep "^SESSION_ID=" "$HOME/.claude/.current-session" 2>/dev/null | cut -d= -f2)
if [ -n "$SESSION_ID" ]; then
    pass "Session ID generated: ${SESSION_ID:0:8}..."
else
    fail "No session ID in .current-session"
fi

echo ""

# ── 3. Preflight Vector Storage ──────────────────────────────
echo "Phase 3: Preflight Vector Storage"

# Simulate what /epistemic-preflight does
jq --arg id "$SESSION_ID" --arg project "test-project" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '
   .sessions += [{
     id: $id, project: $project, timestamp: $ts,
     preflight: {
       engagement: 0.8, know: 0.5, do: 0.6, context: 0.7,
       clarity: 0.8, coherence: 0.7, signal: 0.6, density: 0.5,
       state: 0.6, change: 0.3, completion: 0.1, impact: 0.7,
       uncertainty: 0.4
     },
     postflight: null, deltas: null, task_summary: "", paired: false
   }] | .last_updated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
   ' "$HOME/.claude/epistemic.json" > "$HOME/.claude/epistemic.json.tmp" && \
   mv "$HOME/.claude/epistemic.json.tmp" "$HOME/.claude/epistemic.json"

PREFLIGHT_COUNT=$(jq --arg id "$SESSION_ID" \
    '[.sessions[] | select(.id == $id) | .preflight | keys[]] | length' \
    "$HOME/.claude/epistemic.json" 2>/dev/null)

if [ "$PREFLIGHT_COUNT" = "13" ]; then
    pass "Preflight stores all 13 vectors"
else
    fail "Expected 13 preflight vectors, got $PREFLIGHT_COUNT"
fi

echo ""

# ── 4. Postflight + Delta Computation ────────────────────────
echo "Phase 4: Postflight + Delta Computation"

jq --arg id "$SESSION_ID" \
   '
   (.sessions[] | select(.id == $id)) as $session |
   $session.preflight as $pre |
   {
     engagement: (0.85 - $pre.engagement),
     know: (0.7 - $pre.know),
     do: (0.8 - $pre.do),
     context: (0.75 - $pre.context),
     clarity: (0.85 - $pre.clarity),
     coherence: (0.75 - $pre.coherence),
     signal: (0.7 - $pre.signal),
     density: (0.65 - $pre.density),
     state: (0.75 - $pre.state),
     change: (0.6 - $pre.change),
     completion: (0.5 - $pre.completion),
     impact: (0.75 - $pre.impact),
     uncertainty: (0.2 - $pre.uncertainty)
   } as $deltas |

   .sessions = [.sessions[] |
     if .id == $id then
       .postflight = {
         engagement: 0.85, know: 0.7, do: 0.8, context: 0.75,
         clarity: 0.85, coherence: 0.75, signal: 0.7, density: 0.65,
         state: 0.75, change: 0.6, completion: 0.5, impact: 0.75,
         uncertainty: 0.2
       } |
       .deltas = $deltas |
       .paired = true |
       .task_summary = "Smoke test session"
     else . end
   ] |

   reduce ("engagement","know","do","context","clarity","coherence","signal","density","state","change","completion","impact","uncertainty") as $v (
     .;
     .calibration[$v].last_deltas = ((.calibration[$v].last_deltas + [$deltas[$v]]) | .[-50:]) |
     .calibration[$v].observation_count = ([.calibration[$v].last_deltas[] | select(. != null)] | length) |
     .calibration[$v].rolling_mean_delta = (
       [.calibration[$v].last_deltas[] | select(. != null) | tonumber] |
       if length == 0 then 0 else add / length end
     ) |
     .calibration[$v].correction = (
       .calibration[$v].rolling_mean_delta |
       if . > 0.25 then 0.25 elif . < -0.25 then -0.25 else . end
     )
   ) |
   .last_updated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
   ' "$HOME/.claude/epistemic.json" > "$HOME/.claude/epistemic.json.tmp" && \
   mv "$HOME/.claude/epistemic.json.tmp" "$HOME/.claude/epistemic.json"

IS_PAIRED=$(jq --arg id "$SESSION_ID" \
    '.sessions[] | select(.id == $id) | .paired' \
    "$HOME/.claude/epistemic.json" 2>/dev/null)

if [ "$IS_PAIRED" = "true" ]; then
    pass "Session paired after postflight"
else
    fail "Session should be paired, got paired=$IS_PAIRED"
fi

HAS_DELTAS=$(jq --arg id "$SESSION_ID" \
    '.sessions[] | select(.id == $id) | .deltas | length > 0' \
    "$HOME/.claude/epistemic.json" 2>/dev/null)

if [ "$HAS_DELTAS" = "true" ]; then
    pass "Deltas computed for all vectors"
else
    fail "Deltas should be present after pairing"
fi

# Verify know delta specifically (0.7 - 0.5 = 0.2)
KNOW_DELTA=$(jq --arg id "$SESSION_ID" \
    '.sessions[] | select(.id == $id) | .deltas.know' \
    "$HOME/.claude/epistemic.json" 2>/dev/null)

KNOW_CORRECT=$(echo "$KNOW_DELTA" | awk '{ print ($1 > 0.19 && $1 < 0.21) ? "true" : "false" }')
if [ "$KNOW_CORRECT" = "true" ]; then
    pass "know delta = $KNOW_DELTA (expected ~0.2)"
else
    fail "know delta = $KNOW_DELTA (expected ~0.2)"
fi

echo ""

# ── 5. Calibration State ────────────────────────────────────
echo "Phase 5: Calibration State"

OBS_COUNT=$(jq '.calibration.know.observation_count' "$HOME/.claude/epistemic.json" 2>/dev/null)
if [ "$OBS_COUNT" = "1" ]; then
    pass "Observation count incremented to 1"
else
    fail "Expected observation_count=1, got $OBS_COUNT"
fi

# Verify correction is within bounds
CORRECTION=$(jq '.calibration.know.correction' "$HOME/.claude/epistemic.json" 2>/dev/null)
IN_BOUNDS=$(echo "$CORRECTION" | awk '{ print ($1 >= -0.25 && $1 <= 0.25) ? "true" : "false" }')
if [ "$IN_BOUNDS" = "true" ]; then
    pass "Correction within ±0.25 bounds ($CORRECTION)"
else
    fail "Correction out of bounds: $CORRECTION"
fi

echo ""

# ── 6. Fail-Open Verification ───────────────────────────────
echo "Phase 6: Fail-Open Verification"

# Remove epistemic.json and verify hook still exits 0
rm -f "$HOME/.claude/epistemic.json"
bash "$REPO_ROOT/hooks/epistemic-preflight.sh" 2>/dev/null
if [ $? -eq 0 ]; then
    pass "SessionStart exits 0 with missing epistemic.json"
else
    fail "SessionStart should exit 0 even without epistemic.json"
fi

# Create 0-byte file
touch "$HOME/.claude/epistemic.json"
bash "$REPO_ROOT/hooks/epistemic-preflight.sh" 2>/dev/null
if [ $? -eq 0 ]; then
    pass "SessionStart exits 0 with 0-byte epistemic.json"
else
    fail "SessionStart should exit 0 with 0-byte file"
fi

echo ""

# ── 7. No Stale Temp Files ──────────────────────────────────
echo "Phase 7: Cleanup Verification"

if [ ! -f "$HOME/.claude/epistemic.json.tmp" ]; then
    pass "No stale .tmp files"
else
    fail "Found stale epistemic.json.tmp"
fi

echo ""

# ── Summary ──────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Smoke Test: $PASS passed, $FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
