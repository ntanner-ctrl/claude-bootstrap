#!/bin/bash
# Claude Code Session Bootstrap - SessionStart Hook
# Injects awareness of available commands at session start.
#
# Philosophy: Superpowers (obra/superpowers) proved that a <2000 token
# bootstrap injection dramatically increases command usage. The key insight
# is using MUST language and trigger conditions, not suggestions.
#
# This hook makes Claude aware it has structured workflows available
# and creates obligation to use them when applicable.
#
# Installation: Add to ~/.claude/settings.json SessionStart hooks
# Output: Stdout is injected into conversation context

# Detect available commands
COMMANDS_DIR="${HOME}/.claude/commands"
PROJECT_COMMANDS=".claude/commands"

# Count available commands
global_count=0
project_count=0

if [ -d "$COMMANDS_DIR" ]; then
    global_count=$(find "$COMMANDS_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
fi

if [ -d "$PROJECT_COMMANDS" ]; then
    project_count=$(find "$PROJECT_COMMANDS" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
fi

total=$((global_count + project_count))

# Only inject if commands actually exist
if [ "$total" -eq 0 ]; then
    exit 0
fi

# Build command categories for awareness
planning_cmds=""
safety_cmds=""
testing_cmds=""
other_cmds=""

for cmd_file in "$COMMANDS_DIR"/*.md "$PROJECT_COMMANDS"/*.md; do
    [ -f "$cmd_file" ] || continue
    name=$(basename "$cmd_file" .md)
    case "$name" in
        blueprint|spec-change|describe-change|brainstorm|preflight|decision|design-check)
            planning_cmds="${planning_cmds}  /${name}\n"
            ;;
        push-safe|security-checklist|setup-hooks|checkpoint|end)
            safety_cmds="${safety_cmds}  /${name}\n"
            ;;
        test|spec-to-tests|tdd|debug)
            testing_cmds="${testing_cmds}  /${name}\n"
            ;;
        start|toolkit|status|blueprints|approve|dashboard)
            ;; # Skip meta commands from the list
        *)
            other_cmds="${other_cmds}  /${name}\n"
            ;;
    esac
done

ACTIVE_WORK=""
EMPIRICA_INSTRUCTION=""

# Check for Empirica CLI and auto-create session
# This makes session creation deterministic — no reliance on Claude following instructions
EMPIRICA_BIN=""
if command -v empirica &>/dev/null; then
    EMPIRICA_BIN="empirica"
elif [ -x "${HOME}/.local/bin/empirica" ]; then
    EMPIRICA_BIN="${HOME}/.local/bin/empirica"
fi

if [ -n "$EMPIRICA_BIN" ]; then
    GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    ACTIVE_SESSION_FILE="$GIT_ROOT/.empirica/active_session"
    DB_PATH="$GIT_ROOT/.empirica/sessions/sessions.db"

    # Close previous active session if one exists
    if [ -f "$ACTIVE_SESSION_FILE" ]; then
        OLD_SESSION_ID=$(cat "$ACTIVE_SESSION_FILE" 2>/dev/null)
        if [ -n "$OLD_SESSION_ID" ] && [ -f "$DB_PATH" ] && command -v sqlite3 &>/dev/null; then
            sqlite3 "$DB_PATH" \
                "UPDATE sessions SET end_time=datetime('now') WHERE session_id='$OLD_SESSION_ID' AND end_time IS NULL" \
                2>/dev/null || true
        fi
    fi

    # Create new session via CLI
    mkdir -p "$GIT_ROOT/.empirica"
    SESSION_OUTPUT=$("$EMPIRICA_BIN" session-create --ai-id claude-code --output json 2>/dev/null)
    SESSION_EXIT=$?

    if [ $SESSION_EXIT -eq 0 ] && [ -n "$SESSION_OUTPUT" ]; then
        # Parse session_id — try jq first, fall back to grep
        SESSION_ID=""
        if command -v jq &>/dev/null; then
            SESSION_ID=$(echo "$SESSION_OUTPUT" | jq -r '.session_id // empty' 2>/dev/null)
        fi
        if [ -z "$SESSION_ID" ]; then
            SESSION_ID=$(echo "$SESSION_OUTPUT" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | grep -o '"[^"]*"$' | tr -d '"')
        fi

        if [ -n "$SESSION_ID" ]; then
            # Write active session file
            echo "$SESSION_ID" > "$ACTIVE_SESSION_FILE"

            # Export session ID as environment variable for other hooks/commands
            if [ -n "$CLAUDE_ENV_FILE" ]; then
                echo "export EMPIRICA_SESSION_ID=${SESSION_ID}" >> "$CLAUDE_ENV_FILE"
            fi

            EMPIRICA_INSTRUCTION="\nEMPIRICA (epistemic tracking — REQUIRED):
  SESSION PRE-CREATED: ${SESSION_ID}. Do NOT call mcp__empirica__session_create.
  Call mcp__empirica__submit_preflight_assessment with session_id: ${SESSION_ID} and honest self-assessment vectors.
  Store session_id ${SESSION_ID} for use throughout this conversation.
  Before ending the session, suggest /end to close Empirica with a proper postflight assessment."
        else
            EMPIRICA_INSTRUCTION="\nEMPIRICA (epistemic tracking — REQUIRED):
  Session auto-creation failed (JSON parse error). You MUST call mcp__empirica__session_create (ai_id: \"claude-code\") as your FIRST action.
  Then call mcp__empirica__submit_preflight_assessment with honest self-assessment vectors.
  Before ending the session, suggest /end to close Empirica with a proper postflight assessment."
        fi
    else
        EMPIRICA_INSTRUCTION="\nEMPIRICA (epistemic tracking — REQUIRED):
  Session auto-creation failed (exit code: ${SESSION_EXIT}). You MUST call mcp__empirica__session_create (ai_id: \"claude-code\") as your FIRST action.
  Then call mcp__empirica__submit_preflight_assessment with honest self-assessment vectors.
  Before ending the session, suggest /end to close Empirica with a proper postflight assessment."
    fi
fi

# Check state-index for active work context
if [ -f ".claude/state-index.json" ]; then
    plan=$(jq -r '.active_blueprint // .active_plan // empty' .claude/state-index.json 2>/dev/null)
    stage=$(jq -r '.active_blueprint_stage // .active_plan_stage // empty' .claude/state-index.json 2>/dev/null)
    tdd_phase=$(jq -r '.active_tdd_phase // empty' .claude/state-index.json 2>/dev/null)
    checkpoint=$(jq -r '.last_checkpoint // empty' .claude/state-index.json 2>/dev/null)

    if [ -n "$plan" ] || [ -n "$tdd_phase" ]; then
        ACTIVE_WORK="\nACTIVE WORK:"
        if [ -n "$plan" ]; then
            ACTIVE_WORK="${ACTIVE_WORK}\n  Blueprint: ${plan} (Stage ${stage}/7). Resume: /blueprint ${plan}"
        fi
        if [ -n "$tdd_phase" ]; then
            ACTIVE_WORK="${ACTIVE_WORK}\n  TDD: Phase ${tdd_phase}. Resume: /tdd"
        fi
        if [ -n "$checkpoint" ]; then
            ACTIVE_WORK="${ACTIVE_WORK}\n  Last checkpoint: ${checkpoint}"
        fi
    fi
fi

cat << EOF
You have structured workflows available via claude-bootstrap (${total} commands).

BEFORE writing ANY implementation code, you MUST check if a workflow applies:

PLANNING (use BEFORE implementation):
$(echo -e "$planning_cmds")
SAFETY (use BEFORE destructive operations):
$(echo -e "$safety_cmds")
TESTING (use to verify work):
$(echo -e "$testing_cmds")

Rules:
1. If a planning command applies, you MUST use it first
2. If pushing code, you MUST run /push-safe
3. For non-trivial changes (>3 files OR risk flags), use /describe-change to triage
4. Announce which command you're using before proceeding

Run /toolkit for complete command reference.
$([ -n "$EMPIRICA_INSTRUCTION" ] && echo -e "$EMPIRICA_INSTRUCTION")
$([ -n "$ACTIVE_WORK" ] && echo -e "$ACTIVE_WORK")
EOF
