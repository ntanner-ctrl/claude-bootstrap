#!/bin/bash
# Claude Code CLAUDE.md Protection - PreToolUse Hook
# Prevents accidental modification of CLAUDE.md files that contain
# critical project instructions.
#
# Inspired by ZacheryGlass/.claude protect_claude_md.py
#
# Exit Codes:
#   0 = Allow operation (not a CLAUDE.md file)
#   2 = Block with feedback TO CLAUDE (requires user confirmation)
#
# Installation: Add to ~/.claude/settings.json PreToolUse hooks
#   matcher: "Edit|Write"

# Fail-open: Don't let hook bugs block work
set +e

# Read JSON input from stdin
input=$(cat)

# Extract file path from tool input
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$file_path" ]]; then
    exit 0  # No file path, allow
fi

# Get just the filename
filename=$(basename "$file_path")

# Check if it's a CLAUDE.md file (case-insensitive)
if [[ "${filename,,}" == "claude.md" ]]; then
    # Determine context
    if [[ "$file_path" == *"/.claude/"* ]]; then
        location="project-level (.claude/)"
    elif [[ "$file_path" == *"$HOME/.claude/"* ]] || [[ "$file_path" == *"$HOME/"* && "$file_path" == *"CLAUDE.md" ]]; then
        location="user-level (~/.claude/)"
    else
        location="$(dirname "$file_path")"
    fi

    echo "PROTECTED FILE: CLAUDE.md modification detected" >&2
    echo "" >&2
    echo "Target: $file_path" >&2
    echo "Location: $location" >&2
    echo "" >&2
    echo "CLAUDE.md files contain critical project instructions that guide" >&2
    echo "Claude's behavior. Accidental modifications can break workflows." >&2
    echo "" >&2
    echo "This edit requires explicit user approval." >&2
    echo "If this is part of /bootstrap-project or /refresh-claude-md," >&2
    echo "the user should have already approved the operation." >&2
    exit 2
fi

exit 0
