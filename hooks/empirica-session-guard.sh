#!/usr/bin/env bash
# empirica-session-guard.sh — Block duplicate Empirica session creation
#
# PreToolUse hook matched on mcp__empirica__session_create.
# If a session was already pre-created by session-bootstrap.sh, this hook
# blocks the duplicate and redirects Claude to submit_preflight_assessment.
#
# If no active session exists, allows creation through (fallback for when
# the bootstrap hook couldn't create a session).
#
# Exit codes:
#   0 — Allow (no existing session, let creation proceed)
#   2 — Block with feedback (session exists, redirect to preflight)

set +e

# Consume stdin to prevent broken pipe
cat > /dev/null 2>&1

# Find project root
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

ACTIVE_SESSION_FILE="$GIT_ROOT/.empirica/active_session"

# No active session file? Allow creation through.
if [ ! -f "$ACTIVE_SESSION_FILE" ]; then
    exit 0
fi

SESSION_ID=$(cat "$ACTIVE_SESSION_FILE" 2>/dev/null)

# Empty or unreadable? Allow creation through.
if [ -z "$SESSION_ID" ]; then
    exit 0
fi

# Session exists — block duplicate creation and redirect to preflight
echo "SESSION ALREADY EXISTS: ${SESSION_ID}" >&2
echo "Do NOT call session_create. The session was pre-created by the SessionStart hook." >&2
echo "Call mcp__empirica__submit_preflight_assessment with session_id: ${SESSION_ID}" >&2
exit 2
