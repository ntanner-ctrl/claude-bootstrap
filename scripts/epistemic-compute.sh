#!/usr/bin/env bash
# epistemic-compute.sh — Recompute rolling-average calibration for all 13 vectors
#
# Reads ~/.claude/epistemic.json, processes paired sessions' deltas and
# existing last_deltas arrays, then updates rolling_mean_delta, correction,
# and observation_count for each vector.
#
# Usage:
#   bash scripts/epistemic-compute.sh          # Standalone: recompute all vectors
#   source scripts/epistemic-compute.sh        # Source: import functions only
#
# Functions exported when sourced:
#   epistemic_compute_all           — recompute all vectors' calibration
#   epistemic_compute_vector NAME   — recompute a single vector
#   epistemic_rolling_mean NAME     — return the rolling mean for a vector (read-only)
#   epistemic_clamp VALUE           — clamp a value to ±0.25
#
# DEV-ONLY: not part of the install path. Run from a cloned repo.

set +e  # Fail-open — safe to source from hooks

# --- Configuration -----------------------------------------------------------

EPISTEMIC_FILE="${EPISTEMIC_FILE:-$HOME/.claude/epistemic.json}"
EPISTEMIC_TMP="${EPISTEMIC_FILE}.tmp"

# All 13 canonical vectors
EPISTEMIC_VECTORS=(
    engagement know do context clarity coherence signal
    density state change completion impact uncertainty
)

# --- Guards -------------------------------------------------------------------

_epistemic_check_deps() {
    if ! command -v jq &>/dev/null; then
        echo "WARNING: jq not found — epistemic-compute requires jq. Skipping." >&2
        return 1
    fi
    return 0
}

_epistemic_check_file() {
    if [ ! -f "$EPISTEMIC_FILE" ]; then
        echo "WARNING: $EPISTEMIC_FILE does not exist. Run epistemic-init.sh first." >&2
        return 1
    fi
    if [ ! -s "$EPISTEMIC_FILE" ]; then
        echo "WARNING: $EPISTEMIC_FILE is empty. Run epistemic-init.sh first." >&2
        return 1
    fi
    return 0
}

# --- Core Functions -----------------------------------------------------------

# Clamp a numeric value to [-0.25, 0.25]
# Usage: epistemic_clamp 0.5  =>  0.25
#         epistemic_clamp -0.3 => -0.25
epistemic_clamp() {
    local value="${1:-0}"
    jq -n --argjson v "$value" '
        if $v > 0.25 then 0.25
        elif $v < -0.25 then -0.25
        else $v
        end
    '
}

# Return the null-safe rolling mean for a single vector (read-only)
# Usage: epistemic_rolling_mean know  =>  -0.12
epistemic_rolling_mean() {
    local vector="$1"
    if [ -z "$vector" ]; then
        echo "Usage: epistemic_rolling_mean VECTOR_NAME" >&2
        return 1
    fi
    _epistemic_check_deps || return 1
    _epistemic_check_file || return 1

    jq -r --arg v "$vector" '
        .calibration[$v].last_deltas // [] |
        [.[] | select(. != null) | tonumber] |
        if length == 0 then 0 else add / length end
    ' "$EPISTEMIC_FILE"
}

# Recompute calibration for a single vector
# Updates: rolling_mean_delta, correction, observation_count, last_updated
# Usage: epistemic_compute_vector know
epistemic_compute_vector() {
    local vector="$1"
    if [ -z "$vector" ]; then
        echo "Usage: epistemic_compute_vector VECTOR_NAME" >&2
        return 1
    fi
    _epistemic_check_deps || return 1
    _epistemic_check_file || return 1

    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # Single jq pass: collect new deltas from paired sessions, merge with
    # existing last_deltas (capped at 50), compute rolling mean and correction
    jq --arg v "$vector" --arg now "$now" '
        # Gather new deltas from paired sessions for this vector
        [.sessions[]? | select(.paired == true) | .deltas[$v]? // empty] as $new_deltas |

        # Existing last_deltas array (may contain nulls)
        (.calibration[$v].last_deltas // []) as $existing |

        # Merge: append new deltas to existing, keep last 50
        (($existing + $new_deltas) | .[-50:]) as $merged |

        # Null-safe: filter nulls, compute mean
        [$merged[] | select(. != null) | tonumber] as $clean |
        ($clean | if length == 0 then 0 else add / length end) as $mean |

        # Clamp correction to ±0.25
        (if $mean > 0.25 then 0.25
         elif $mean < -0.25 then -0.25
         else $mean end) as $correction |

        # Update calibration for this vector
        .calibration[$v] = (.calibration[$v] // {}) + {
            rolling_mean_delta: $mean,
            correction: $correction,
            observation_count: ($clean | length),
            last_deltas: $merged,
            last_updated: $now
        } |

        # Update top-level timestamp
        .last_updated = $now
    ' "$EPISTEMIC_FILE" > "$EPISTEMIC_TMP" && mv "$EPISTEMIC_TMP" "$EPISTEMIC_FILE"

    local rc=$?
    if [ $rc -ne 0 ]; then
        echo "ERROR: Failed to update vector '$vector' in $EPISTEMIC_FILE" >&2
        rm -f "$EPISTEMIC_TMP"
        return 1
    fi
    return 0
}

# Recompute calibration for ALL 13 vectors in a single pass
# Usage: epistemic_compute_all
epistemic_compute_all() {
    _epistemic_check_deps || return 1
    _epistemic_check_file || return 1

    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # Build the vector list as a JSON array for jq
    local vectors_json
    vectors_json=$(printf '%s\n' "${EPISTEMIC_VECTORS[@]}" | jq -R . | jq -s .)

    # Single atomic jq pass over all vectors
    jq --argjson vectors "$vectors_json" --arg now "$now" '
        . as $root |

        # For each vector, recompute calibration
        reduce $vectors[] as $v ($root;
            # New deltas from paired sessions
            [.sessions[]? | select(.paired == true) | .deltas[$v]? // empty] as $new_deltas |

            # Existing last_deltas
            (.calibration[$v].last_deltas // []) as $existing |

            # Merge and cap at 50
            (($existing + $new_deltas) | .[-50:]) as $merged |

            # Null-safe mean
            [$merged[] | select(. != null) | tonumber] as $clean |
            ($clean | if length == 0 then 0 else add / length end) as $mean |

            # Clamp
            (if $mean > 0.25 then 0.25
             elif $mean < -0.25 then -0.25
             else $mean end) as $correction |

            # Write back
            .calibration[$v] = (.calibration[$v] // {}) + {
                rolling_mean_delta: $mean,
                correction: $correction,
                observation_count: ($clean | length),
                last_deltas: $merged,
                last_updated: $now
            }
        ) |

        .last_updated = $now
    ' "$EPISTEMIC_FILE" > "$EPISTEMIC_TMP" && mv "$EPISTEMIC_TMP" "$EPISTEMIC_FILE"

    local rc=$?
    if [ $rc -ne 0 ]; then
        echo "ERROR: Failed to recompute calibration in $EPISTEMIC_FILE" >&2
        rm -f "$EPISTEMIC_TMP"
        return 1
    fi

    echo "Recomputed calibration for ${#EPISTEMIC_VECTORS[@]} vectors in $EPISTEMIC_FILE"
    return 0
}

# --- Main (only runs when executed, not when sourced) -------------------------

# Detect if sourced vs executed
# When sourced, BASH_SOURCE[0] != $0
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    _epistemic_check_deps || exit 0
    _epistemic_check_file || exit 0
    epistemic_compute_all
fi
