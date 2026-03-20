#!/usr/bin/env bash
# epistemic-init.sh — Initialize ~/.claude/epistemic.json with empty schema
#
# Creates the primary data store for native epistemic tracking.
# Safe to run multiple times — will NOT overwrite existing data.
#
# Usage: bash scripts/epistemic-init.sh
# DEV-ONLY: not part of the install path. Run from a cloned repo.

EPISTEMIC_FILE="${HOME}/.claude/epistemic.json"

# Guard: don't overwrite existing data
if [ -s "$EPISTEMIC_FILE" ]; then
    echo "epistemic.json already exists and is non-empty. Skipping init."
    echo "To reinitialize, delete $EPISTEMIC_FILE first."
    exit 0
fi

# Ensure directory exists
mkdir -p "${HOME}/.claude"

# All 13 vectors
VECTORS='["engagement","know","do","context","clarity","coherence","signal","density","state","change","completion","impact","uncertainty"]'

# Build calibration object with empty entries for each vector
if command -v jq &>/dev/null; then
    CALIBRATION=$(echo "$VECTORS" | jq '
        [.[] | {
            key: .,
            value: {
                rolling_mean_delta: 0,
                observation_count: 0,
                last_deltas: [],
                correction: 0,
                behavioral_instruction: "",
                last_updated: null
            }
        }] | from_entries
    ')

    jq -n \
        --argjson calibration "$CALIBRATION" \
        --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            schema_version: 1,
            last_updated: $now,
            calibration: $calibration,
            projects: {},
            sessions: [],
            bayesian: {
                enabled: false,
                beliefs: {}
            }
        }' > "$EPISTEMIC_FILE"
else
    # Fallback: write JSON without jq (literal string)
    cat > "$EPISTEMIC_FILE" << 'ENDJSON'
{
  "schema_version": 1,
  "last_updated": null,
  "calibration": {
    "engagement": { "rolling_mean_delta": 0, "observation_count": 0, "last_deltas": [], "correction": 0, "behavioral_instruction": "", "last_updated": null },
    "know": { "rolling_mean_delta": 0, "observation_count": 0, "last_deltas": [], "correction": 0, "behavioral_instruction": "", "last_updated": null },
    "do": { "rolling_mean_delta": 0, "observation_count": 0, "last_deltas": [], "correction": 0, "behavioral_instruction": "", "last_updated": null },
    "context": { "rolling_mean_delta": 0, "observation_count": 0, "last_deltas": [], "correction": 0, "behavioral_instruction": "", "last_updated": null },
    "clarity": { "rolling_mean_delta": 0, "observation_count": 0, "last_deltas": [], "correction": 0, "behavioral_instruction": "", "last_updated": null },
    "coherence": { "rolling_mean_delta": 0, "observation_count": 0, "last_deltas": [], "correction": 0, "behavioral_instruction": "", "last_updated": null },
    "signal": { "rolling_mean_delta": 0, "observation_count": 0, "last_deltas": [], "correction": 0, "behavioral_instruction": "", "last_updated": null },
    "density": { "rolling_mean_delta": 0, "observation_count": 0, "last_deltas": [], "correction": 0, "behavioral_instruction": "", "last_updated": null },
    "state": { "rolling_mean_delta": 0, "observation_count": 0, "last_deltas": [], "correction": 0, "behavioral_instruction": "", "last_updated": null },
    "change": { "rolling_mean_delta": 0, "observation_count": 0, "last_deltas": [], "correction": 0, "behavioral_instruction": "", "last_updated": null },
    "completion": { "rolling_mean_delta": 0, "observation_count": 0, "last_deltas": [], "correction": 0, "behavioral_instruction": "", "last_updated": null },
    "impact": { "rolling_mean_delta": 0, "observation_count": 0, "last_deltas": [], "correction": 0, "behavioral_instruction": "", "last_updated": null },
    "uncertainty": { "rolling_mean_delta": 0, "observation_count": 0, "last_deltas": [], "correction": 0, "behavioral_instruction": "", "last_updated": null }
  },
  "projects": {},
  "sessions": [],
  "bayesian": {
    "enabled": false,
    "beliefs": {}
  }
}
ENDJSON
fi

if [ -s "$EPISTEMIC_FILE" ]; then
    echo "Initialized $EPISTEMIC_FILE (schema_version: 1, 13 vectors)"
else
    echo "ERROR: Failed to create $EPISTEMIC_FILE" >&2
    exit 1
fi
