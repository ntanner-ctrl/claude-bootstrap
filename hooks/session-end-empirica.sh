#!/usr/bin/env bash
# session-end-empirica.sh — Safety net: closes Empirica session on exit
#
# Fires on SessionEnd event. If /end wasn't used to do a proper postflight,
# this hook at least closes the session record in the DB so it doesn't stay
# orphaned with a null end_time forever.
#
# This is bookkeeping only — no epistemic assessment happens here (Claude is
# already gone). For proper postflight with learning deltas, use /end.
#
# Exit codes: Always 0 (fail-open, can't block session end anyway)

set +e

# Find project root (git root preferred, fall back to cwd)
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

ACTIVE_SESSION_FILE="$GIT_ROOT/.empirica/active_session"
DB_PATH="$GIT_ROOT/.empirica/sessions/sessions.db"

# No active session file? Nothing to do.
[ -f "$ACTIVE_SESSION_FILE" ] || exit 0

SESSION_ID=$(cat "$ACTIVE_SESSION_FILE" 2>/dev/null)
[ -z "$SESSION_ID" ] && exit 0

# No database? Nothing we can update.
[ -f "$DB_PATH" ] || exit 0

# Need sqlite3 for direct DB update
if ! command -v sqlite3 &>/dev/null; then
    exit 0
fi

# Check if session already has end_time (properly closed by /end or session_create)
END_TIME=$(sqlite3 "$DB_PATH" \
    "SELECT end_time FROM sessions WHERE session_id='$SESSION_ID'" 2>/dev/null)

if [ -n "$END_TIME" ]; then
    # Already closed — /end was used or next session_create closed it
    exit 0
fi

# Close the session with current timestamp
sqlite3 "$DB_PATH" \
    "UPDATE sessions SET end_time=datetime('now') WHERE session_id='$SESSION_ID' AND end_time IS NULL" \
    2>/dev/null

exit 0
