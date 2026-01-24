#!/bin/bash
# Claude Code Status Line - Toolkit-Aware
# Receives JSON on stdin with: model, cost, context_window, workspace
# Reads .claude/state-index.json for active plan/TDD state
# Outputs single line with ANSI colors
#
# Optimized for 300ms update frequency: minimal forks, single jq calls

# Parse all input fields in one jq call (tab-separated)
IFS=$'\t' read -r MODEL COST CTX_PCT < <(jq -r '[
  (.model.display_name // "Unknown"),
  (.cost.total_cost_usd // 0 | tostring),
  (.context_window.used_percentage // 0 | tostring)
] | join("\t")' 2>/dev/null)

# Shorten model name (pure bash, no sed fork)
MODEL_SHORT="${MODEL#Claude }"
MODEL_SHORT="${MODEL_SHORT/Sonnet/Son}"
MODEL_SHORT="${MODEL_SHORT/Haiku/Hai}"

# Format cost (awk is lighter than bc)
if awk "BEGIN{exit(!($COST < 0.01))}" 2>/dev/null; then
    COST_FMT="<\$0.01"
else
    COST_FMT="\$$(printf '%.2f' "$COST")"
fi

# Context bar (10 chars wide, pure bash)
CTX_INT=${CTX_PCT%.*}
CTX_INT=${CTX_INT:-0}
FILLED=$((CTX_INT / 10))
EMPTY=$((10 - FILLED))
BAR=""
for ((i=0; i<FILLED; i++)); do BAR+="█"; done
for ((i=0; i<EMPTY; i++)); do BAR+="░"; done

# Color context based on usage
if [ "$CTX_INT" -ge 80 ]; then
    CTX_COLOR="\033[31m"  # Red — getting close to limit
elif [ "$CTX_INT" -ge 60 ]; then
    CTX_COLOR="\033[33m"  # Yellow — past halfway
else
    CTX_COLOR="\033[32m"  # Green — plenty of room
fi
RESET="\033[0m"
DIM="\033[2m"
BOLD="\033[1m"
CYAN="\033[36m"

# Build base status
STATUS="${BOLD}${MODEL_SHORT}${RESET} ${DIM}│${RESET} ${COST_FMT} ${DIM}│${RESET} ${CTX_COLOR}${BAR} ${CTX_INT}%${RESET}"

# Read toolkit state if available (single jq call for all fields)
STATE_FILE=".claude/state-index.json"
if [ -f "$STATE_FILE" ]; then
    IFS=$'\t' read -r PLAN STAGE TDD_PHASE < <(jq -r '[
      (.active_plan // ""),
      (.active_plan_stage // "" | tostring),
      (.active_tdd_phase // "")
    ] | join("\t")' "$STATE_FILE" 2>/dev/null)

    TOOLKIT=""
    if [ -n "$PLAN" ]; then
        TOOLKIT="${CYAN}Plan: ${PLAN}"
        [ -n "$STAGE" ] && TOOLKIT+=" [${STAGE}]"
        TOOLKIT+="${RESET}"
    fi
    if [ -n "$TDD_PHASE" ]; then
        [ -n "$TOOLKIT" ] && TOOLKIT+=" "
        case "$TDD_PHASE" in
            RED)   TDD_CLR="\033[31m" ;;
            GREEN) TDD_CLR="\033[32m" ;;
            *)     TDD_CLR="\033[33m" ;;
        esac
        TOOLKIT+="${TDD_CLR}TDD: ${TDD_PHASE}${RESET}"
    fi

    [ -n "$TOOLKIT" ] && STATUS+=" ${DIM}│${RESET} ${TOOLKIT}"
fi

echo -e "$STATUS"
