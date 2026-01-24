#!/bin/bash
# State Index Updater - PostToolUse Hook (Edit|Write matcher)
# Maintains .claude/state-index.json as a lightweight "what's active?" index.
#
# Only acts when state files change (plan state.json, TDD active.json).
# Low-frequency: most edits don't trigger any work.
#
# Installation: PostToolUse hook with matcher "Edit|Write"

# Get the file that was just edited/written
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null)

[ -z "$FILE_PATH" ] && exit 0

# Only care about state files
case "$FILE_PATH" in
    */.claude/plans/*/state.json) ;;
    */.claude/tdd-sessions/active.json) ;;
    *) exit 0 ;;
esac

STATE_INDEX=".claude/state-index.json"
mkdir -p .claude

# Initialize index if missing
if [ ! -f "$STATE_INDEX" ]; then
    echo '{}' > "$STATE_INDEX"
fi

# Read current plan state
active_plan=""
active_plan_stage=""
for state_file in .claude/plans/*/state.json; do
    [ -f "$state_file" ] || continue
    stage=$(jq -r '.current_stage // empty' "$state_file" 2>/dev/null)
    status=$(jq -r '.stages.execute.status // empty' "$state_file" 2>/dev/null)
    if [ -n "$stage" ] && [ "$status" != "complete" ]; then
        active_plan=$(jq -r '.name // empty' "$state_file" 2>/dev/null)
        active_plan_stage="$stage"
        break
    fi
done

# Read TDD state
active_tdd=""
active_tdd_phase=""
if [ -f ".claude/tdd-sessions/active.json" ]; then
    active_tdd=$(jq -r '.id // empty' .claude/tdd-sessions/active.json 2>/dev/null)
    active_tdd_phase=$(jq -r '.phase // empty' .claude/tdd-sessions/active.json 2>/dev/null)
fi

# Write index
jq -n \
    --arg plan "$active_plan" \
    --arg stage "$active_plan_stage" \
    --arg tdd "$active_tdd" \
    --arg tdd_phase "$active_tdd_phase" \
    --arg checkpoint "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
        active_plan: (if $plan == "" then null else $plan end),
        active_plan_stage: (if $stage == "" then null else ($stage | tonumber) end),
        active_tdd: (if $tdd == "" then null else $tdd end),
        active_tdd_phase: (if $tdd_phase == "" then null else $tdd_phase end),
        last_checkpoint: $checkpoint,
        delegate_running: false
    }' > "$STATE_INDEX"

exit 0
