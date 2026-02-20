#!/usr/bin/env bash
# empirica-preflight-capture.sh — Capture preflight vectors to disk
#
# PostToolUse hook matched on mcp__empirica__submit_preflight_assessment.
# Persists the 13 epistemic vectors to .empirica/preflight.jsonl so /end
# can pair them with postflight for delta calculation and vault export.
#
# Consumers:
#   - /end command: pairs with postflight for epistemic delta vault note
#   - Human: readable via `cat .empirica/preflight.jsonl | jq`
#
# Exit codes: Always 0 (fail-open — never block Empirica calls)

set +e

# Read JSON input from stdin (PostToolUse hook protocol)
input=$(cat)

# Extract tool input from the hook payload
tool_input=$(echo "$input" | jq -r '.tool_input // empty' 2>/dev/null)

# Bail if we can't parse (fail-open)
[ -z "$tool_input" ] && exit 0

# Resolve data dir: EMPIRICA_DATA_DIR takes priority,
# then git root, then cwd fallback. Must match path_resolver.py priority.
if [ -n "$EMPIRICA_DATA_DIR" ]; then
    EMPIRICA_DIR="$EMPIRICA_DATA_DIR"
else
    GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    EMPIRICA_DIR="$GIT_ROOT/.empirica"
fi
mkdir -p "$EMPIRICA_DIR" 2>/dev/null

PREFLIGHT_FILE="$EMPIRICA_DIR/preflight.jsonl"

# Build JSONL entry: timestamp + type + full tool_input (preserves all fields)
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

entry=$(jq -n \
    --arg ts "$timestamp" \
    --argjson input "$tool_input" \
    '{timestamp: $ts, type: "preflight", input: $input}' 2>/dev/null)

# Append to JSONL (atomic-ish via single echo)
if [ -n "$entry" ]; then
    echo "$entry" >> "$PREFLIGHT_FILE" 2>/dev/null
fi

# Always exit 0 — never block Empirica operations
exit 0
