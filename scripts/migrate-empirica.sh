#!/usr/bin/env bash
# migrate-empirica.sh — One-time migration from Empirica to native epistemic tracking
#
# Migrates paired preflight/postflight sessions from Empirica's fragmented SQLite
# databases into ~/.claude/epistemic.json. Falls back to JSONL files if SQLite is
# unavailable or empty.
#
# DEV-ONLY: not part of the install path. Run from a cloned repo.
#
# Usage: bash scripts/migrate-empirica.sh
# Requires: jq, sqlite3 (for SQLite path; JSONL fallback if absent)
#
# Safe to run multiple times — skips sessions already migrated.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
EPISTEMIC_FILE="${HOME}/.claude/epistemic.json"

# ─── Colors ──────────────────────────────────────────────────────────

green() { printf "\033[0;32m%s\033[0m" "$1"; }
red()   { printf "\033[0;31m%s\033[0m" "$1"; }
yellow(){ printf "\033[1;33m%s\033[0m" "$1"; }
bold()  { printf "\033[1m%s\033[0m" "$1"; }

info()  { echo "  $(green "●") $1"; }
warn()  { echo "  $(yellow "⚠") $1"; }
err()   { echo "  $(red "✗") $1" >&2; }

# ─── Guards ──────────────────────────────────────────────────────────

command -v jq >/dev/null 2>&1 || {
    err "jq is required but not found. Install it first."
    exit 1
}

HAS_SQLITE=false
if command -v sqlite3 >/dev/null 2>&1; then
    HAS_SQLITE=true
fi

# ─── Initialize epistemic.json if needed ─────────────────────────────

if [ ! -s "$EPISTEMIC_FILE" ]; then
    echo "$(bold "Initializing epistemic.json...")"
    if [ -f "$SCRIPT_DIR/epistemic-init.sh" ]; then
        bash "$SCRIPT_DIR/epistemic-init.sh"
    else
        err "epistemic-init.sh not found at $SCRIPT_DIR/epistemic-init.sh"
        exit 1
    fi
fi

if [ ! -s "$EPISTEMIC_FILE" ]; then
    err "Failed to initialize $EPISTEMIC_FILE"
    exit 1
fi

# ─── Known Empirica database locations ───────────────────────────────

# Search home directory for .empirica/sessions/sessions.db files
SEARCH_DIRS=(
    "$HOME/.empirica"
    "$HOME/claude-sail/.empirica"
    "$HOME/project_scout/.empirica"
    "$HOME/s4-notion-portal/.empirica"
    "$HOME/s3-project/.empirica"
    "$HOME/s4-docs/.empirica"
)

# Also check current repo
if [ -d "$REPO_DIR/.empirica" ]; then
    # Avoid duplicates — only add if not already in list
    REPO_EMPIRICA="$REPO_DIR/.empirica"
    already_listed=false
    for d in "${SEARCH_DIRS[@]}"; do
        if [ "$(realpath "$d" 2>/dev/null)" = "$(realpath "$REPO_EMPIRICA" 2>/dev/null)" ]; then
            already_listed=true
            break
        fi
    done
    if [ "$already_listed" = false ]; then
        SEARCH_DIRS+=("$REPO_EMPIRICA")
    fi
fi

# ─── Collect paired sessions ─────────────────────────────────────────

echo ""
echo "$(bold "Empirica Migration")"
echo "$(bold "==================")"
echo ""

# Temp file for accumulating session JSON objects (one per line)
SESSIONS_TMP=$(mktemp)
EPISTEMIC_TMP=""
SQLITE_TMP=""
trap 'rm -f "$SESSIONS_TMP" "$EPISTEMIC_TMP" "$SQLITE_TMP"' EXIT

DATABASES_FOUND=0
TOTAL_PAIRED=0
ALREADY_MIGRATED=0

# Get list of already-migrated session IDs
EXISTING_IDS=$(jq -r '.sessions[]? | select(.migrated_from == "empirica") | .id' "$EPISTEMIC_FILE" 2>/dev/null || echo "")

derive_project_name() {
    local db_path="$1"
    local parent_dir
    # Path is like /home/user/project/.empirica/sessions/sessions.db
    # or /home/user/.empirica/sessions/sessions.db (global)
    parent_dir="$(dirname "$(dirname "$(dirname "$db_path")")")"
    local base
    base="$(basename "$parent_dir")"
    if [ "$base" = "$(basename "$HOME")" ] || [ "$parent_dir" = "$HOME" ]; then
        echo "global"
    else
        echo "$base"
    fi
}

derive_project_from_empirica_dir() {
    local empirica_dir="$1"
    local parent_dir
    parent_dir="$(dirname "$empirica_dir")"
    local base
    base="$(basename "$parent_dir")"
    if [ "$base" = "$(basename "$HOME")" ] || [ "$parent_dir" = "$HOME" ]; then
        echo "global"
    else
        echo "$base"
    fi
}

# ─── SQLite extraction ───────────────────────────────────────────────

extract_from_sqlite() {
    local db_path="$1"
    local project_name="$2"

    if [ ! -f "$db_path" ]; then
        return
    fi

    DATABASES_FOUND=$((DATABASES_FOUND + 1))
    info "Scanning: $db_path (project: $project_name)"

    # Check if reflexes table exists
    local has_reflexes
    has_reflexes=$(sqlite3 "$db_path" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='reflexes';" 2>/dev/null || echo "0")
    if [ "$has_reflexes" = "0" ]; then
        warn "  No reflexes table found, skipping"
        return
    fi

    # Extract paired sessions (both preflight and postflight exist)
    # Vectors are stored as individual columns, not a JSON blob
    SQLITE_TMP=$(mktemp)
    sqlite3 -json "$db_path" "
        SELECT r1.session_id,
               r1.engagement as pre_engagement, r1.know as pre_know, r1.do as pre_do,
               r1.context as pre_context, r1.clarity as pre_clarity, r1.coherence as pre_coherence,
               r1.signal as pre_signal, r1.density as pre_density, r1.state as pre_state,
               r1.change as pre_change, r1.completion as pre_completion, r1.impact as pre_impact,
               r1.uncertainty as pre_uncertainty,
               r2.engagement as post_engagement, r2.know as post_know, r2.do as post_do,
               r2.context as post_context, r2.clarity as post_clarity, r2.coherence as post_coherence,
               r2.signal as post_signal, r2.density as post_density, r2.state as post_state,
               r2.change as post_change, r2.completion as post_completion, r2.impact as post_impact,
               r2.uncertainty as post_uncertainty,
               r1.timestamp as timestamp
        FROM reflexes r1
        JOIN reflexes r2 ON r1.session_id = r2.session_id
        WHERE r1.phase = 'PREFLIGHT' AND r2.phase = 'POSTFLIGHT'
    " 2>/dev/null > "$SQLITE_TMP" || true

    # sqlite3 -json returns empty string or [] for no results
    local row_count
    row_count=$(jq 'length' "$SQLITE_TMP" 2>/dev/null || echo "0")

    if [ "$row_count" = "0" ] || [ -z "$row_count" ]; then
        info "  No paired sessions found"
        rm -f "$SQLITE_TMP"
        return
    fi

    info "  Found $row_count paired session(s)"

    # Process each paired session
    local i=0
    while [ "$i" -lt "$row_count" ]; do
        local session_id
        session_id=$(jq -r ".[$i].session_id" "$SQLITE_TMP")
        local timestamp
        timestamp=$(jq -r ".[$i].timestamp // empty" "$SQLITE_TMP")

        # Check if already migrated
        if echo "$EXISTING_IDS" | grep -qF "$session_id" 2>/dev/null; then
            ALREADY_MIGRATED=$((ALREADY_MIGRATED + 1))
            i=$((i + 1))
            continue
        fi

        # Build preflight/postflight objects from individual columns
        local preflight postflight deltas
        preflight=$(jq -r ".[$i] | {
            engagement: .pre_engagement, know: .pre_know, do: .pre_do,
            context: .pre_context, clarity: .pre_clarity, coherence: .pre_coherence,
            signal: .pre_signal, density: .pre_density, state: .pre_state,
            change: .pre_change, completion: .pre_completion, impact: .pre_impact,
            uncertainty: .pre_uncertainty
        }" "$SQLITE_TMP" 2>/dev/null || echo "{}")
        postflight=$(jq -r ".[$i] | {
            engagement: .post_engagement, know: .post_know, do: .post_do,
            context: .post_context, clarity: .post_clarity, coherence: .post_coherence,
            signal: .post_signal, density: .post_density, state: .post_state,
            change: .post_change, completion: .post_completion, impact: .post_impact,
            uncertainty: .post_uncertainty
        }" "$SQLITE_TMP" 2>/dev/null || echo "{}")

        # Compute deltas: postflight - preflight for each vector
        deltas=$(jq -n \
            --argjson pre "$preflight" \
            --argjson post "$postflight" \
            '[($pre | keys[]) as $k | {($k): (($post[$k] // 0) - ($pre[$k] // 0))}] | add // {}')

        # Use created_at or fallback to now
        if [ -z "$timestamp" ] || [ "$timestamp" = "null" ]; then
            timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        fi

        # Build session object
        jq -n \
            --arg id "$session_id" \
            --arg project "$project_name" \
            --arg ts "$timestamp" \
            --argjson pre "$preflight" \
            --argjson post "$postflight" \
            --argjson deltas "$deltas" \
            '{
                id: $id,
                project: $project,
                timestamp: $ts,
                preflight: $pre,
                postflight: $post,
                deltas: $deltas,
                task_summary: "",
                paired: true,
                migrated_from: "empirica"
            }' >> "$SESSIONS_TMP"

        TOTAL_PAIRED=$((TOTAL_PAIRED + 1))
        i=$((i + 1))
    done

    rm -f "$SQLITE_TMP"
}

# ─── JSONL extraction (fallback) ─────────────────────────────────────

extract_from_jsonl() {
    local empirica_dir="$1"
    local project_name="$2"

    local preflight_file="$empirica_dir/preflight.jsonl"
    local postflight_file="$empirica_dir/postflight.jsonl"

    if [ ! -f "$preflight_file" ] || [ ! -f "$postflight_file" ]; then
        return
    fi

    info "Scanning JSONL fallback: $empirica_dir (project: $project_name)"

    # Build lookup of preflight entries by session_id
    # JSONL format: {"timestamp": "...", "type": "preflight", "input": {"session_id": "...", "vectors": {...}}}
    local pre_tmp post_tmp
    pre_tmp=$(mktemp)
    post_tmp=$(mktemp)

    # Extract session_id -> vectors from preflight
    while IFS= read -r line; do
        local sid vectors
        sid=$(echo "$line" | jq -r '.input.session_id // empty' 2>/dev/null)
        vectors=$(echo "$line" | jq '.input.vectors // empty' 2>/dev/null)
        if [ -n "$sid" ] && [ "$vectors" != "null" ] && [ -n "$vectors" ]; then
            local ts
            ts=$(echo "$line" | jq -r '.timestamp // empty' 2>/dev/null)
            jq -n --arg sid "$sid" --argjson v "$vectors" --arg ts "$ts" \
                '{sid: $sid, vectors: $v, timestamp: $ts}' >> "$pre_tmp"
        fi
    done < "$preflight_file"

    # Extract session_id -> vectors from postflight
    while IFS= read -r line; do
        local sid vectors
        sid=$(echo "$line" | jq -r '.input.session_id // empty' 2>/dev/null)
        vectors=$(echo "$line" | jq '.input.vectors // empty' 2>/dev/null)
        if [ -n "$sid" ] && [ "$vectors" != "null" ] && [ -n "$vectors" ]; then
            jq -n --arg sid "$sid" --argjson v "$vectors" \
                '{sid: $sid, vectors: $v}' >> "$post_tmp"
        fi
    done < "$postflight_file"

    # Match by session_id
    local paired_count=0
    while IFS= read -r pre_line; do
        local sid
        sid=$(echo "$pre_line" | jq -r '.sid')
        local post_match
        # slurp JSONL into array, find first match, compact to single line
        post_match=$(jq -sc --arg sid "$sid" '[.[] | select(.sid == $sid)] | first // empty' "$post_tmp" 2>/dev/null || true)

        if [ -n "$post_match" ]; then
            # Check if already migrated
            if echo "$EXISTING_IDS" | grep -qF "$sid" 2>/dev/null; then
                ALREADY_MIGRATED=$((ALREADY_MIGRATED + 1))
                continue
            fi

            local preflight postflight deltas timestamp
            preflight=$(echo "$pre_line" | jq '.vectors')
            postflight=$(echo "$post_match" | jq '.vectors')
            timestamp=$(echo "$pre_line" | jq -r '.timestamp // empty')

            if [ -z "$timestamp" ] || [ "$timestamp" = "null" ]; then
                timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            fi

            deltas=$(jq -n \
                --argjson pre "$preflight" \
                --argjson post "$postflight" \
                '[($pre | keys[]) as $k | {($k): (($post[$k] // 0) - ($pre[$k] // 0))}] | add // {}')

            jq -n \
                --arg id "$sid" \
                --arg project "$project_name" \
                --arg ts "$timestamp" \
                --argjson pre "$preflight" \
                --argjson post "$postflight" \
                --argjson deltas "$deltas" \
                '{
                    id: $id,
                    project: $project,
                    timestamp: $ts,
                    preflight: $pre,
                    postflight: $post,
                    deltas: $deltas,
                    task_summary: "",
                    paired: true,
                    migrated_from: "empirica"
                }' >> "$SESSIONS_TMP"

            TOTAL_PAIRED=$((TOTAL_PAIRED + 1))
            paired_count=$((paired_count + 1))
        fi
    done < "$pre_tmp"

    if [ "$paired_count" -gt 0 ]; then
        info "  Found $paired_count paired session(s) from JSONL"
    else
        info "  No paired sessions found in JSONL"
    fi

    rm -f "$pre_tmp" "$post_tmp"
}

# ─── Scan all known locations ─────────────────────────────────────────

for empirica_dir in "${SEARCH_DIRS[@]}"; do
    if [ ! -d "$empirica_dir" ]; then
        continue
    fi

    project_name=$(derive_project_from_empirica_dir "$empirica_dir")
    db_path="$empirica_dir/sessions/sessions.db"

    # Try SQLite first, fall back to JSONL
    if [ "$HAS_SQLITE" = true ] && [ -f "$db_path" ]; then
        extract_from_sqlite "$db_path" "$project_name"
    else
        extract_from_jsonl "$empirica_dir" "$project_name"
    fi
done

# ─── Report findings ─────────────────────────────────────────────────

echo ""
echo "$(bold "Discovery Summary")"
echo "  Databases scanned:     $DATABASES_FOUND"
echo "  Paired sessions found: $TOTAL_PAIRED"
echo "  Already migrated:      $ALREADY_MIGRATED"
echo ""

if [ "$TOTAL_PAIRED" -eq 0 ]; then
    if [ "$ALREADY_MIGRATED" -gt 0 ]; then
        info "All paired sessions already migrated. Nothing to do."
        exit 0
    else
        warn "Zero paired sessions found."
        warn "If you expected data, inspect the reflexes table manually:"
        warn "  sqlite3 ~/.empirica/sessions/sessions.db \"SELECT phase, count(*) FROM reflexes GROUP BY phase;\""
        exit 0
    fi
fi

# ─── Merge into epistemic.json ────────────────────────────────────────

echo "$(bold "Merging $TOTAL_PAIRED paired sessions into epistemic.json...")"

# Read all collected sessions into a JSON array
SESSIONS_ARRAY=$(jq -s '.' "$SESSIONS_TMP")

# Merge sessions and update calibration + projects
EPISTEMIC_TMP=$(mktemp)

jq --argjson new_sessions "$SESSIONS_ARRAY" \
   --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '

    # Add new sessions
    .sessions += $new_sessions |
    .last_updated = $now |

    # Update project familiarity counts
    (reduce $new_sessions[] as $s (
        .projects;
        .[$s.project] = ((.[$s.project] // {session_count: 0, last_session: null}) |
            .session_count += 1 |
            .last_session = $s.timestamp
        )
    )) as $updated_projects |
    .projects = $updated_projects |

    # Update calibration last_deltas arrays (keep last 10 per vector)
    (reduce $new_sessions[] as $s (
        .calibration;
        reduce ($s.deltas | to_entries[]) as $entry (
            .;
            if .[$entry.key] then
                .[$entry.key].last_deltas = ((.[$entry.key].last_deltas + [$entry.value]) | .[-10:]) |
                .[$entry.key].observation_count += 1 |
                .[$entry.key].last_updated = $now
            else . end
        )
    )) as $updated_calibration |
    .calibration = $updated_calibration |

    # Recompute rolling_mean_delta for each vector that has observations
    .calibration = (.calibration | to_entries | map(
        if (.value.last_deltas | length) > 0 then
            .value.rolling_mean_delta = ((.value.last_deltas | add) / (.value.last_deltas | length))
        else . end |
        {key: .key, value: .value}
    ) | from_entries)

' "$EPISTEMIC_FILE" > "$EPISTEMIC_TMP"

# Validate output before writing
if ! jq empty "$EPISTEMIC_TMP" 2>/dev/null; then
    err "Generated invalid JSON. Migration aborted — no changes made."
    exit 1
fi

# Atomic write
mv "$EPISTEMIC_TMP" "$EPISTEMIC_FILE"

# ─── Try to run epistemic-compute if available ────────────────────────

COMPUTE_SCRIPT="$SCRIPT_DIR/epistemic-compute.sh"
if [ -f "$COMPUTE_SCRIPT" ]; then
    info "Running epistemic-compute.sh to recompute calibration..."
    # Source it to get epistemic_compute_all function
    if bash "$COMPUTE_SCRIPT" 2>/dev/null; then
        info "Calibration recomputed."
    else
        warn "epistemic-compute.sh failed — calibration values computed inline instead."
    fi
else
    info "epistemic-compute.sh not found — calibration computed inline."
fi

# ─── Final summary ───────────────────────────────────────────────────

echo ""
echo "$(bold "Migration Complete")"
echo "  Migrated:  $TOTAL_PAIRED paired sessions"
echo "  Skipped:   $ALREADY_MIGRATED already-migrated sessions"

# Show per-project breakdown
echo ""
echo "  $(bold "Per-project breakdown:")"
jq -r '.sessions | map(select(.migrated_from == "empirica")) | group_by(.project) | .[] | "    \(.[0].project): \(length) session(s)"' "$EPISTEMIC_FILE"

echo ""
info "Data written to $EPISTEMIC_FILE"
