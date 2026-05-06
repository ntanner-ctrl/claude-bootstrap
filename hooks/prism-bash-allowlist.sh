#!/bin/bash
# Claude Sail — Prism Bash Allowlist (Scope Guardrail)
# PreToolUse hook for the test-debt-classifier subagent dispatched by /prism Stage 5.5.
#
# THREAT MODEL: scope guardrail, NOT security boundary.
# This hook catches agent confusion (the test-debt-classifier reaching outside its
# declared scope: pytest / bash test.sh / git log). It surfaces a visible error so the
# user knows the agent went off-script. It does NOT defend against:
#   - hostile test code (use SAIL_PRISM_RUN_TESTS=0 for unaudited repos)
#   - shell metacharacter bypass within otherwise-allowed commands (not modeled)
#   - child processes spawned by allowed commands (PreToolUse fires on Bash tool
#     calls, not on child processes spawned by allowed commands — by design)
#
# UNIVERSAL DESTRUCTIVE-PATTERN BLOCKING continues to be enforced by
# dangerous-commands.sh for ALL Bash calls. This hook is additive.
#
# Exit codes:
#   0 = Allow operation (proceed silently)
#   1 = User-facing error (hook malfunction)
#   2 = Block with feedback TO CLAUDE (Claude sees stderr)

# Fail-open: hook bugs must NOT halt work
set +e

# Hook runtime toggle — skip if disabled via env var
HOOK_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi

# Audit logging — no-op fallback if utility not installed
audit_block() { :; }
source ~/.claude/hooks/_audit-log.sh 2>/dev/null || true

# Read JSON input from stdin
input=$(cat)

# Extract agent_type — `// empty` ensures missing field returns "" not "null"
agent_type=$(echo "$input" | jq -r '.agent_type // empty' 2>/dev/null)

# Main session (no agent_type) → no-op
if [[ -z "$agent_type" ]]; then
    exit 0
fi

# Dispatch by agent_type. Only test-debt-classifier is constrained today.
# Other agents pass through unaffected (defense-in-depth, smaller blast radius).
case "$agent_type" in
    test-debt-classifier)
        # Continue to allowlist enforcement below
        ;;
    *)
        # Different agent — not our concern
        exit 0
        ;;
esac

# Extract the command (fail-open if malformed)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
if [[ -z "$cmd" ]]; then
    exit 0  # No command, nothing to enforce
fi

# Allowlist: substring-prefix match. The command must START WITH one of these
# prefixes (after any leading whitespace). No metacharacter parsing — this is
# a scope guardrail, not airtight matching (per threat model).
#
# To extend: add a prefix line below.
allowed=0
for prefix in "pytest " "pytest$" "bash test.sh" "git log "; do
    # Trim leading whitespace from cmd for comparison
    trimmed="${cmd#"${cmd%%[![:space:]]*}"}"
    case "$prefix" in
        *'$')
            # Anchored exact match (no trailing args) — pytest with no args
            base="${prefix%$}"
            if [[ "$trimmed" == "$base" ]]; then
                allowed=1
                break
            fi
            ;;
        *)
            if [[ "$trimmed" == "$prefix"* ]]; then
                allowed=1
                break
            fi
            ;;
    esac
done

if [[ "$allowed" -eq 1 ]]; then
    exit 0
fi

# Outside declared scope — block with feedback to Claude
echo "BLOCKED [SCOPE_GUARDRAIL]: Command outside declared scope for test-debt-classifier" >&2
echo "" >&2
echo "  Command: ${cmd:0:120}" >&2
echo "  Allowed prefixes: 'pytest ', 'bash test.sh', 'git log '" >&2
echo "" >&2
echo "Suggestion: This agent classifies pre-existing test failures. Stay within the test runner + git log for symbol history. If you genuinely need a different command, the agent prompt is the wrong scope — surface the gap rather than improvising." >&2

audit_block "$HOOK_NAME" "SCOPE_GUARDRAIL" "non-allowlisted command for test-debt-classifier" "Bash" "${cmd:0:100}"
exit 2
