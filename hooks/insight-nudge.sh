#!/usr/bin/env bash
# insight-nudge.sh — Throttled reminder to capture insights
#
# PostToolUse hook matched on Read|Edit|Write|Bash.
# Reminds Claude to call finding_log or /collect-insights when insights
# may have accumulated, but throttled to avoid noise.
#
# Throttle: emits reminder every N tool calls (default 8, configurable
# via INSIGHT_NUDGE_INTERVAL). Resets if finding_log was called recently
# (within 60 seconds, detected via timestamp file).
#
# Exit codes: Always 0 (advisory only — never block)

set +e

# Consume stdin (PostToolUse hook protocol)
cat > /dev/null

# Config
INTERVAL="${INSIGHT_NUDGE_INTERVAL:-8}"
UID_TAG=$(id -u)
COUNTER_FILE="/tmp/.insight-nudge-count-${UID_TAG}"
LAST_CAPTURE="/tmp/.insight-last-capture-${UID_TAG}"

# If a finding was captured recently (within 60s), reset counter and skip
if [ -f "$LAST_CAPTURE" ]; then
    last_ts=$(stat -c %Y "$LAST_CAPTURE" 2>/dev/null || stat -f %m "$LAST_CAPTURE" 2>/dev/null || echo 0)
    now_ts=$(date +%s)
    elapsed=$(( now_ts - last_ts ))
    if [ "$elapsed" -lt 60 ]; then
        echo 0 > "$COUNTER_FILE" 2>/dev/null
        exit 0
    fi
fi

# Read current count (default 0)
count=0
[ -f "$COUNTER_FILE" ] && count=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)

# Increment
count=$(( count + 1 ))

# Check if we've hit the interval
if [ "$count" -ge "$INTERVAL" ]; then
    # Emit advisory reminder to stderr
    echo "" >&2
    echo "💡 Insight check: If you generated ★ Insight blocks since the last capture, call /collect-insights or finding_log now." >&2
    echo "" >&2
    # Reset counter
    count=0
fi

# Write updated count
echo "$count" > "$COUNTER_FILE" 2>/dev/null

exit 0
