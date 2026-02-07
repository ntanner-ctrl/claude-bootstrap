#!/bin/bash
# Empirica Commit Reminder - PostToolUse Hook (Bash matcher)
# Reminds Claude to log findings via Empirica after a successful git commit.
#
# Fires on Bash tool use. Checks if the command was a git commit.
# Advisory only (exit 0) — outputs a reminder visible to the agent.
#
# Installation: PostToolUse hook with matcher "Bash" in settings.json

TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
TOOL_OUTPUT="${CLAUDE_TOOL_OUTPUT:-}"

# Extract the command from tool input
COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null)

[ -z "$COMMAND" ] && exit 0

# Only care about git commit commands (not git commit --amend, etc. checks)
case "$COMMAND" in
    git\ commit*) ;;
    *) exit 0 ;;
esac

# Check if the commit succeeded (look for typical success indicators)
case "$TOOL_OUTPUT" in
    *"create mode"*|*"file changed"*|*"files changed"*|*"insertion"*|*"deletion"*)
        # Commit succeeded — remind to log findings
        echo ""
        echo "Commit detected. If an Empirica session is active, call finding_log"
        echo "to record what was learned or accomplished in this commit."
        echo ""
        ;;
esac

exit 0
