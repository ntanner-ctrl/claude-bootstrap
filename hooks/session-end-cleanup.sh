#!/usr/bin/env bash
# session-end-cleanup.sh — Removes signal files created during the session
#
# Cleans up: compaction guardian signals, failure counter, debug reset,
# guardian heartbeat, and checkpoint-done markers.
#
# To disable: remove the SessionEnd entry for session-end-cleanup.sh from ~/.claude/settings.json

set +e

# Determine session-scoped suffix (same logic as guardian/failure hooks)
if [ "$PPID" -eq 1 ]; then
    SIG_SUFFIX="$USER-$(pwd | md5sum | cut -c1-8)"
else
    SIG_SUFFIX="$PPID"
fi

rm -f "/tmp/.claude-ctx-warning-${SIG_SUFFIX}" \
      "/tmp/.claude-ctx-critical-${SIG_SUFFIX}" \
      "/tmp/.claude-checkpoint-done-${SIG_SUFFIX}" \
      "/tmp/.claude-fail-count-${SIG_SUFFIX}" \
      "/tmp/.claude-debug-reset-${SIG_SUFFIX}" \
      "/tmp/.claude-guardian-heartbeat-${SIG_SUFFIX}" \
      2>/dev/null

exit 0
