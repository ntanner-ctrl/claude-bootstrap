#!/usr/bin/env bash
# anti-pattern-write-check.sh — PreToolUse on Write/Edit
#
# Scans Write/Edit content against catalog regexes in .claude/anti-patterns/.
# On match: emits stdout JSON with hookSpecificOutput.additionalContext citing
# the matched catalog id(s). Tool call still proceeds (permissionDecision: allow).
#
# Why additionalContext (rev4): empirical AC14 verification confirmed that
# `exit 0 + stderr` from a PreToolUse hook does NOT propagate to Claude — it
# only reaches the user's terminal. The additionalContext field is the
# documented Claude Code primitive for warn-with-visibility on PreToolUse.
# See .claude/plans/anti-pattern-catalog/ac14-verification.md.
#
# Wiring: settings.json PreToolUse matcher "Write|Edit".
# Disable per session: SAIL_DISABLED_HOOKS=anti-pattern-write-check claude

set +e

HOOK_NAME="anti-pattern-write-check"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi

# Audit logging — no-op fallback if utility not installed
audit_block() { :; }
source ~/.claude/hooks/_audit-log.sh 2>/dev/null || true

# Locate catalog (opt-in by directory presence)
GIT_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null)
CATALOG_DIR="${GIT_TOPLEVEL:-.}/.claude/anti-patterns"
[ -d "$CATALOG_DIR" ] || exit 0

# Read tool-call JSON from stdin (matches secret-scanner.sh convention)
input=$(cat)

# Extract candidate content. Write uses tool_input.content; Edit uses
# tool_input.new_string. The // empty fallback handles both, plus any
# tool that doesn't carry either field.
content=$(echo "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)
[ -z "$content" ] && exit 0

file_path=$(echo "$input" | jq -r '.tool_input.file_path // "<unknown>"' 2>/dev/null)

# Skip writes targeting the catalog itself or planning docs — fixtures
# would self-match. Mirrors EXCLUDE_PATHS in scripts/anti-pattern-sweep.sh.
case "$file_path" in
    *.claude/anti-patterns/*) exit 0 ;;
    *.claude/plans/*)         exit 0 ;;
    *commands/templates/stock-anti-patterns/*) exit 0 ;;
esac

# Accumulate citations across all catalog entries. Multiple patterns may match;
# we surface them all in one additionalContext block (Claude Code accumulates
# additionalContext across hooks too, per docs — but concatenating in-hook keeps
# the citation block contiguous in feedback).
matches=""
shopt -s nullglob
for entry in "$CATALOG_DIR"/*.md; do
    [ "$(basename "$entry")" = "SCHEMA.md" ] && continue
    id=$(basename "$entry" .md)

    # Skip retired patterns
    status=$(awk '/^---$/{c++; if(c>=2)exit; next} c==1 && /^status:/{
        sub(/^status:[[:space:]]*/, ""); print; exit
    }' "$entry")
    [ "$status" = "retired" ] && continue

    # Extract detection_regex, stripping surrounding quotes if present
    regex=$(awk '/^---$/{c++; if(c>=2)exit; next} c==1 && /^detection_regex:/{
        sub(/^detection_regex:[[:space:]]*/, "")
        gsub(/^['\''"]|['\''"]$/, "")
        print; exit
    }' "$entry")
    [ -z "$regex" ] && continue

    if echo "$content" | grep -qE "$regex" 2>/dev/null; then
        matches+="anti-pattern detected
  Catalog: $id
  File: $file_path

"
    fi
done
shopt -u nullglob

# If any matches, emit one JSON object with concatenated additionalContext.
if [ -n "$matches" ]; then
    if command -v jq >/dev/null 2>&1; then
        jq -nc --arg ctx "$matches" '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "allow",
                additionalContext: $ctx
            }
        }'
    fi
fi

exit 0
