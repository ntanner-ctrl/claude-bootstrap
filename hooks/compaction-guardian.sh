#!/bin/bash
# compaction-guardian.sh — PreToolUse hook (matcher: *)
# Gates tool calls when context window approaches compaction threshold.
#
# To disable: remove the PreToolUse entry for compaction-guardian.sh from ~/.claude/settings.json
#
# Exit codes:
#   0 = allow (pass-through)
#   2 = block with feedback to Claude (stderr)
set +e

# --- Heartbeat (PM1 fix) — always write, before any logic ---
# Determines session-scoped suffix
if [ "$PPID" -eq 1 ]; then
    SIG_SUFFIX="$USER-$(pwd | md5sum | cut -c1-8)"
else
    SIG_SUFFIX="$PPID"
fi
echo "$(date +%s)" > "/tmp/.claude-guardian-heartbeat-${SIG_SUFFIX}"

# --- Parse tool call from stdin ---
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Fail-open: if parsing fails, allow
[ -z "$TOOL_NAME" ] && exit 0

# --- Exemption List (F2/M1 fix) ---
# These tools are part of the checkpoint escape path and must always pass
case "$TOOL_NAME" in
    Agent)
        exit 0
        ;;
    Skill)
        SKILL=$(echo "$INPUT" | jq -r '.skill // empty' 2>/dev/null)
        [ "$SKILL" = "checkpoint" ] && exit 0
        ;;
    Bash)
        COMMAND=$(echo "$INPUT" | jq -r '.command // empty' 2>/dev/null)
        case "$COMMAND" in
            */checkpoint*|*checkpoint.sh*) exit 0 ;;
        esac
        ;;
    Write)
        FILE_PATH=$(echo "$INPUT" | jq -r '.file_path // empty' 2>/dev/null)
        case "$FILE_PATH" in
            *.checkpoint*|*checkpoints/*) exit 0 ;;
        esac
        ;;
    Read)
        FILE_PATH=$(echo "$INPUT" | jq -r '.file_path // empty' 2>/dev/null)
        case "$FILE_PATH" in
            *state.json|*manifest.json|*state-index.json) exit 0 ;;
        esac
        ;;
esac

# --- Check critical signal file (75%+) ---
CRITICAL_FILE="/tmp/.claude-ctx-critical-${SIG_SUFFIX}"
if [ -f "$CRITICAL_FILE" ]; then
    # Check TTL (30 minutes)
    TIMESTAMP=$(sed -n '2p' "$CRITICAL_FILE" 2>/dev/null)
    NOW=$(date +%s)
    if [ -n "$TIMESTAMP" ] && [ $((NOW - TIMESTAMP)) -gt 1800 ]; then
        # Stale — remove and treat as no signal
        rm -f "$CRITICAL_FILE" 2>/dev/null
    else
        # Check for recent checkpoint-done signal (5-minute TTL)
        DONE_FILE="/tmp/.claude-checkpoint-done-${SIG_SUFFIX}"
        if [ -f "$DONE_FILE" ]; then
            DONE_TS=$(head -1 "$DONE_FILE" 2>/dev/null)
            if [ -n "$DONE_TS" ] && [ $((NOW - DONE_TS)) -lt 300 ]; then
                exit 0  # Recent checkpoint — allow
            else
                rm -f "$DONE_FILE" 2>/dev/null  # Expired
            fi
        fi

        # Block — context is critical, no recent checkpoint
        CTX_PCT=$(head -1 "$CRITICAL_FILE" 2>/dev/null)
        CTX_PCT=${CTX_PCT:-75}

        # Read session context for the message
        EMPIRICA_ID=""
        PLAN_NAME=""
        PLAN_DIR=""
        if [ -f ".claude/state-index.json" ]; then
            PLAN_NAME=$(jq -r '.active_plan // empty' .claude/state-index.json 2>/dev/null)
            [ -n "$PLAN_NAME" ] && PLAN_DIR=".claude/plans/${PLAN_NAME}"
        fi
        if [ -n "$PLAN_DIR" ] && [ -f "${PLAN_DIR}/state.json" ]; then
            EMPIRICA_ID=$(jq -r '.empirica_session_id // empty' "${PLAN_DIR}/state.json" 2>/dev/null)
        fi

        cat >&2 <<EOF
Context at ${CTX_PCT}%. Auto-compaction triggers at 85%.
DELEGATE checkpoint to a subagent to avoid consuming remaining context.

Subagent prompt should include:
  - Empirica session: ${EMPIRICA_ID:-not found}
  - Active plan: ${PLAN_NAME:-none}
  - Plan directory: ${PLAN_DIR:-none}
  - Signal path: /tmp/.claude-checkpoint-done-${SIG_SUFFIX}
    (literal path — subagent writes HERE, not its own \$PPID)

The subagent reads state files, writes checkpoint JSON, and optionally
calls Empirica. The parent receives only the compact result.

If subagent dispatch fails, fall back to inline /checkpoint.

NOTE: Agent, Bash(/checkpoint), Write(.checkpoint), Read(state/manifest),
and Skill:checkpoint calls are exempted from this gate.
EOF
        exit 2
    fi
fi

# --- Check warning signal file (65%+) ---
WARNING_FILE="/tmp/.claude-ctx-warning-${SIG_SUFFIX}"
if [ -f "$WARNING_FILE" ]; then
    # Check TTL (10 minutes)
    TIMESTAMP=$(sed -n '2p' "$WARNING_FILE" 2>/dev/null)
    NOW=$(date +%s)
    if [ -n "$TIMESTAMP" ] && [ $((NOW - TIMESTAMP)) -gt 600 ]; then
        rm -f "$WARNING_FILE" 2>/dev/null
    else
        CTX_PCT=$(head -1 "$WARNING_FILE" 2>/dev/null)
        echo "Context at ${CTX_PCT:-65}%. Consider /checkpoint soon." >&2
    fi
fi

exit 0
