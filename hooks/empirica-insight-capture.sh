#!/usr/bin/env bash
# empirica-insight-capture.sh — Write-through cache for Empirica findings
#
# PostToolUse hook matched on mcp__empirica__finding_log, mistake_log, deadend_log.
# Mirrors every Empirica epistemic capture to a local JSONL file that survives
# context compaction, crashes, and sessions closed without /end.
#
# This is the "Option 2" safety net. Option 1 (CLAUDE.md instruction) tells Claude
# to call finding_log at each insight. This hook persists those calls to disk
# immediately so they're never lost.
#
# Consumers of the JSONL file:
#   - /end command: reconciles with Empirica on graceful shutdown
#   - /start command: picks up orphaned insights from prior sessions
#   - Human: readable session log via `cat .empirica/insights.jsonl | jq`
#
# Exit codes: Always 0 (fail-open — never block Empirica calls)

set +e

# Read JSON input from stdin (PostToolUse hook protocol)
input=$(cat)

# Extract tool name and input from the hook payload
tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
tool_input=$(echo "$input" | jq -r '.tool_input // empty' 2>/dev/null)

# Bail if we can't parse (fail-open)
[ -z "$tool_input" ] && exit 0

# Resolve data dir: EMPIRICA_DATA_DIR takes priority (global DB mode),
# then git root, then cwd fallback. Must match path_resolver.py priority.
if [ -n "$EMPIRICA_DATA_DIR" ]; then
    EMPIRICA_DIR="$EMPIRICA_DATA_DIR"
else
    GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    EMPIRICA_DIR="$GIT_ROOT/.empirica"
fi
mkdir -p "$EMPIRICA_DIR" 2>/dev/null

INSIGHTS_FILE="$EMPIRICA_DIR/insights.jsonl"

# Determine the log type from the tool name
case "$tool_name" in
    *finding_log*)  log_type="finding" ;;
    *mistake_log*)  log_type="mistake" ;;
    *deadend_log*)  log_type="deadend" ;;
    *)              log_type="unknown" ;;
esac

# Build JSONL entry: timestamp + type + full tool_input (preserves all fields)
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

entry=$(jq -n \
    --arg ts "$timestamp" \
    --arg type "$log_type" \
    --argjson input "$tool_input" \
    '{timestamp: $ts, type: $type, input: $input}' 2>/dev/null)

# Append to JSONL (atomic-ish via single echo)
if [ -n "$entry" ]; then
    echo "$entry" >> "$INSIGHTS_FILE" 2>/dev/null
fi

# Signal to insight-nudge.sh that a capture just happened
touch "/tmp/.insight-last-capture-$(id -u)" 2>/dev/null

# Always exit 0 — never block Empirica operations
exit 0
