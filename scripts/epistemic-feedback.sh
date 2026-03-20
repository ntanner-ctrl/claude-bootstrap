#!/usr/bin/env bash
# epistemic-feedback.sh — Generate behavioral feedback from calibration data
#
# Pairs numeric corrections with natural-language instructions.
# The key insight: "you overestimate know by 0.12" is trivia.
# "Read at least 3 files in unfamiliar areas before rating know > 0.7" is actionable.
#
# Sourced by hooks (must be fail-open). Also callable standalone.
#
# Usage: source scripts/epistemic-feedback.sh
#        epistemic_generate_feedback          # updates epistemic.json with instructions
#        epistemic_format_calibration_block    # outputs calibration block for SessionStart
#
# Requires: jq, epistemic-compute.sh (for computation functions)

set +e

EPISTEMIC_FILE="${EPISTEMIC_FILE:-$HOME/.claude/epistemic.json}"
EPISTEMIC_TMP="${EPISTEMIC_FILE}.tmp"

# Source computation functions if not already loaded
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -z "$(type -t epistemic_clamp 2>/dev/null)" ]; then
    if [ -f "$SCRIPT_DIR/epistemic-compute.sh" ]; then
        source "$SCRIPT_DIR/epistemic-compute.sh"
    elif [ -f "${HOME}/.claude/scripts/epistemic-compute.sh" ]; then
        source "${HOME}/.claude/scripts/epistemic-compute.sh"
    fi
fi

# ── Priority Behavioral Templates ─────────────────────────────
# These 5 vectors get specific, evidence-based instructions.
# All others get the catch-all template.

_feedback_template() {
    local vector="$1"
    local direction="$2"  # overestimate | underestimate | well_calibrated
    local magnitude="$3"  # small | moderate | large
    local correction="$4"
    local count="$5"

    case "${vector}:${direction}" in
        know:overestimate)
            echo "You tend to overestimate understanding. In past sessions, this led to skipping exploration of unfamiliar code. Before rating \`know\` above 0.7, verify you've read at least 3 files in the target area."
            ;;
        know:underestimate)
            echo "You tend to underestimate understanding. Your actual comprehension is typically higher than you think. Trust your initial assessment more — don't over-research areas you already grasp."
            ;;
        do:overestimate)
            echo "You tend to overestimate your ability to execute. Implementation often takes longer or is more complex than initially assessed. Budget extra time for unexpected complexity."
            ;;
        do:underestimate)
            echo "You tend to underestimate execution ability. You accomplish more than you predict. Consider setting more ambitious implementation targets."
            ;;
        uncertainty:overestimate)
            echo "You tend to overestimate uncertainty. Your uncertainty predictions are usually higher than warranted — you know more than you think you do."
            ;;
        uncertainty:underestimate)
            echo "You tend to underestimate uncertainty. You are more uncertain than you initially think. Plan for more unknowns."
            ;;
        completion:overestimate)
            echo "You tend to overestimate completion progress. Sessions typically achieve less than you expected. Be more conservative with progress estimates."
            ;;
        completion:underestimate)
            echo "You tend to underestimate completion progress. Sessions typically achieve more than you expected. Your milestones may be more conservative than necessary."
            ;;
        engagement:overestimate)
            echo "You tend to overestimate initial engagement. You're often less aligned with the task than you think at the outset. Spend extra time understanding the task before diving in."
            ;;
        engagement:underestimate)
            echo "You tend to underestimate engagement. You become more invested in tasks than you initially predict. Trust your interest level."
            ;;
        *:well_calibrated)
            echo "Your \`${vector}\` assessment has been accurate across ${count} sessions (delta ±$(printf '%.2f' "$correction")). Note: this accuracy is based on familiar projects. New projects may differ."
            ;;
        *)
            # Catch-all for vectors without specific templates
            echo "Your \`${vector}\` self-assessment tends to be ${direction}d by ~$(printf '%.2f' "${correction#-}"). Consider adjusting your next \`${vector}\` rating accordingly."
            ;;
    esac
}

# ── Direction and Magnitude Classification ────────────────────

_classify_direction() {
    local correction="$1"
    # Negative correction = overestimate (preflight > postflight on average)
    # Positive correction = underestimate (preflight < postflight on average)
    local abs_correction
    abs_correction=$(echo "$correction" | awk '{ v = $1; if (v < 0) v = -v; print v }')

    if awk "BEGIN { exit !($abs_correction < 0.05) }" 2>/dev/null; then
        echo "well_calibrated"
    elif awk "BEGIN { exit !($correction < 0) }" 2>/dev/null; then
        echo "overestimate"
    else
        echo "underestimate"
    fi
}

_classify_magnitude() {
    local correction="$1"
    local abs_correction
    abs_correction=$(echo "$correction" | awk '{ v = $1; if (v < 0) v = -v; print v }')

    if awk "BEGIN { exit !($abs_correction < 0.08) }" 2>/dev/null; then
        echo "small"
    elif awk "BEGIN { exit !($abs_correction < 0.18) }" 2>/dev/null; then
        echo "moderate"
    else
        echo "large"
    fi
}

# ── Main Functions ────────────────────────────────────────────

# Generate and store behavioral instructions for all vectors
epistemic_generate_feedback() {
    if ! command -v jq &>/dev/null; then
        echo "WARNING: jq not available — skipping feedback generation" >&2
        return 0
    fi

    if [ ! -s "$EPISTEMIC_FILE" ]; then
        echo "WARNING: epistemic.json missing or empty — skipping feedback generation" >&2
        return 0
    fi

    local vectors="engagement know do context clarity coherence signal density state change completion impact uncertainty"
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    for vector in $vectors; do
        local correction count direction magnitude instruction

        correction=$(jq -r ".calibration.${vector}.correction // 0" "$EPISTEMIC_FILE" 2>/dev/null)
        count=$(jq -r ".calibration.${vector}.observation_count // 0" "$EPISTEMIC_FILE" 2>/dev/null)

        # Skip vectors with insufficient data
        if [ "$count" -lt 5 ] 2>/dev/null; then
            instruction="Insufficient data (${count}/5 paired sessions). Calibration will activate after 5 paired sessions."
            jq --arg v "$vector" --arg inst "$instruction" --arg now "$now" \
                '.calibration[$v].behavioral_instruction = $inst | .calibration[$v].last_updated = $now' \
                "$EPISTEMIC_FILE" > "$EPISTEMIC_TMP" && mv "$EPISTEMIC_TMP" "$EPISTEMIC_FILE"
            continue
        fi

        direction=$(_classify_direction "$correction")
        magnitude=$(_classify_magnitude "$correction")
        instruction=$(_feedback_template "$vector" "$direction" "$magnitude" "$correction" "$count")

        # Store instruction in epistemic.json (atomic write)
        jq --arg v "$vector" --arg inst "$instruction" --arg now "$now" \
            '.calibration[$v].behavioral_instruction = $inst | .calibration[$v].last_updated = $now' \
            "$EPISTEMIC_FILE" > "$EPISTEMIC_TMP" && mv "$EPISTEMIC_TMP" "$EPISTEMIC_FILE"
    done
}

# Format the calibration block for SessionStart hook injection
# Outputs to stdout — caller redirects to stderr for Claude context injection
epistemic_format_calibration_block() {
    if ! command -v jq &>/dev/null; then
        echo "[Epistemic Tracking] Calibration unavailable (jq not installed)."
        return 0
    fi

    if [ ! -s "$EPISTEMIC_FILE" ]; then
        echo "[Epistemic Tracking] No calibration data yet."
        return 0
    fi

    local session_id="$1"
    local project_name="$2"
    local familiarity="$3"

    # Count total paired observations (use max across vectors)
    local total_obs
    total_obs=$(jq '[.calibration[].observation_count] | max // 0' "$EPISTEMIC_FILE" 2>/dev/null)

    echo "[Epistemic Tracking]"
    echo "Session: ${session_id}"
    echo "Project: ${project_name} (familiarity: ${familiarity})"
    echo ""

    if [ "$total_obs" -lt 5 ] 2>/dev/null; then
        echo "Calibration: Collecting data (${total_obs}/5 paired sessions needed)"
        echo ""
    else
        echo "Calibration (${total_obs} paired sessions):"

        # Show vectors with |correction| > 0.05 (non-trivially miscalibrated)
        local vectors="engagement know do context clarity coherence signal density state change completion impact uncertainty"
        local shown=0

        for vector in $vectors; do
            local correction direction instruction
            correction=$(jq -r ".calibration.${vector}.correction // 0" "$EPISTEMIC_FILE" 2>/dev/null)
            local abs_correction
            abs_correction=$(echo "$correction" | awk '{ v = $1; if (v < 0) v = -v; print v }')

            if awk "BEGIN { exit !($abs_correction > 0.05) }" 2>/dev/null; then
                direction=$(_classify_direction "$correction")
                instruction=$(jq -r ".calibration.${vector}.behavioral_instruction // \"\"" "$EPISTEMIC_FILE" 2>/dev/null)

                printf "  %s: correction %+.2f (%s)\n" "$vector" "$correction" "$direction"
                if [ -n "$instruction" ] && [ "$instruction" != "null" ]; then
                    echo "    → $instruction"
                fi
                shown=$((shown + 1))
            fi
        done

        if [ "$shown" -eq 0 ]; then
            echo "  All vectors well-calibrated (corrections within ±0.05)"
        fi
        echo ""
    fi

    # Context-sensitive warning for unfamiliar projects
    if [ "$familiarity" = "low" ] && [ "$total_obs" -ge 5 ] 2>/dev/null; then
        echo "  Context warning: ${project_name} is new to you."
        echo "  Calibration based on familiar projects — may not transfer."
        echo ""
    fi

    # Pairing rate health check
    local session_count paired_count
    session_count=$(jq '.sessions | length' "$EPISTEMIC_FILE" 2>/dev/null)
    paired_count=$(jq '[.sessions[] | select(.paired == true)] | length' "$EPISTEMIC_FILE" 2>/dev/null)

    if [ "$session_count" -ge 10 ] 2>/dev/null && [ "$paired_count" -eq 0 ] 2>/dev/null; then
        echo "WARNING: 0 of ${session_count} sessions have paired."
        echo "Check that /end is working correctly."
        echo ""
    fi

    echo "Submit preflight vectors using /epistemic-preflight with 13 scores (0.0-1.0):"
    echo "  engagement, know, do, context, clarity, coherence, signal,"
    echo "  density, state, change, completion, impact, uncertainty"
}

# When run directly (not sourced), generate feedback
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    epistemic_generate_feedback
    echo "Feedback generation complete."
fi
