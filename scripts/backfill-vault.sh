#!/usr/bin/env bash
# backfill-vault.sh — One-time migration of existing blueprints and Empirica findings to Obsidian vault.
# LOCAL script, not distributed via install.sh.
#
# Usage: bash scripts/backfill-vault.sh
#   or:  bash scripts/backfill-vault.sh --dry-run

set +e  # Fail-open on individual items

# --- Configuration ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source vault config for VAULT_PATH and helpers
VAULT_CONFIG="$HOME/.claude/hooks/vault-config.sh"
if [ ! -f "$VAULT_CONFIG" ]; then
    echo "ERROR: Vault config not found at $VAULT_CONFIG" >&2
    echo "Run install.sh first, then configure vault-config.sh" >&2
    exit 1
fi
# shellcheck source=/dev/null
source "$VAULT_CONFIG"

# Dry run mode
DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=1
    echo "[DRY RUN] No files will be written."
fi

# --- Dependency check ---

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required but not installed." >&2
    echo "Install with: sudo apt install jq" >&2
    exit 1
fi

# --- Vault availability check ---

if ! vault_is_available; then
    echo "ERROR: Vault is not available." >&2
    echo "  VAULT_ENABLED=$VAULT_ENABLED" >&2
    echo "  VAULT_PATH=$VAULT_PATH" >&2
    echo "Check that the path exists and is writable." >&2
    exit 1
fi

echo "Vault: $VAULT_PATH"
echo "---"

# --- Ensure target directories ---

BLUEPRINT_DIR="$VAULT_PATH/Engineering/Blueprints"
FINDING_DIR="$VAULT_PATH/Engineering/Findings"

if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$BLUEPRINT_DIR"
    mkdir -p "$FINDING_DIR"
fi

# --- Counters ---

BLUEPRINTS_WRITTEN=0
FINDINGS_WRITTEN=0
SKIPPED=0

# --- Stage name mapping ---
# Works for both numeric and string current_stage values

stage_name() {
    local stage="$1"
    case "$stage" in
        1|describe)      echo "Describe" ;;
        2|specify)       echo "Specify" ;;
        3|challenge)     echo "Challenge" ;;
        4|edge_cases)    echo "Edge Cases" ;;
        5|premortem|review) echo "Review" ;;
        6|test)          echo "Test" ;;
        7|execute)       echo "Execute" ;;
        ""|null)          echo "Unknown" ;;
        *)               echo "$stage" ;;
    esac
}

stage_number() {
    local stage="$1"
    case "$stage" in
        1|describe)      echo "1" ;;
        2|specify)       echo "2" ;;
        3|challenge)     echo "3" ;;
        4|edge_cases)    echo "4" ;;
        5|premortem|review) echo "5" ;;
        6|test)          echo "6" ;;
        7|execute)       echo "7" ;;
        ""|null)         echo "?" ;;
        *)               echo "?" ;;
    esac
}

# --- Helper: determine project name from a plan directory ---

get_project_name() {
    local plan_dir="$1"
    # Walk up to find .git
    local dir="$plan_dir"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.git" ]; then
            basename "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    # Fallback: if under ~/.claude/plans, use "global"
    if echo "$plan_dir" | grep -q "$HOME/.claude/plans"; then
        echo "global"
    else
        echo "unknown"
    fi
    return 0
}

# --- Helper: generate slug ---

make_slug() {
    echo "$1" | tr -cd '[:alnum:] ._-' | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/^-*//;s/-*$//' | head -c 80
}

# --- Helper: extract date from ISO timestamp ---

iso_to_date() {
    # Extracts YYYY-MM-DD from ISO-8601 string
    echo "$1" | grep -oP '^\d{4}-\d{2}-\d{2}' || echo ""
}

# --- Helper: file mtime as YYYY-MM-DD ---

file_date() {
    local f="$1"
    if [ -f "$f" ]; then
        stat -c '%Y' "$f" 2>/dev/null | xargs -I{} date -d @{} '+%Y-%m-%d' 2>/dev/null || date '+%Y-%m-%d'
    else
        date '+%Y-%m-%d'
    fi
}

# ============================================================
# PART 1: Blueprint Backfill
# ============================================================

echo "=== Blueprint Backfill ==="

PLAN_DIRS=(
    "$REPO_ROOT/.claude/plans"
    "$HOME/project_scout/.claude/plans"
    "$HOME/.claude/plans"
)

for plans_root in "${PLAN_DIRS[@]}"; do
    [ -d "$plans_root" ] || continue

    for plan_dir in "$plans_root"/*/; do
        [ -d "$plan_dir" ] || continue

        MANIFEST="$plan_dir/manifest.json"
        STATE="$plan_dir/state.json"
        ADVERSARIAL="$plan_dir/adversarial.md"

        # Must have at least one metadata file
        if [ ! -f "$MANIFEST" ] && [ ! -f "$STATE" ]; then
            continue
        fi

        # --- Extract fields: manifest.json primary, state.json fallback ---

        if [ -f "$MANIFEST" ]; then
            NAME=$(jq -r '.blueprint // .name // empty' "$MANIFEST" 2>/dev/null)
            SUMMARY=$(jq -r '.summary // empty' "$MANIFEST" 2>/dev/null)
            CURRENT_STAGE=$(jq -r '.current_stage // empty' "$MANIFEST" 2>/dev/null)
            PATH_TYPE=$(jq -r '.path // .scope.path // empty' "$MANIFEST" 2>/dev/null)
            CHALLENGE_MODE=$(jq -r '.challenge_mode // .scope.challenge_mode // empty' "$MANIFEST" 2>/dev/null)
            WORK_UNITS=$(jq -r '.spec_digest.work_units // (.work_units | length) // 0' "$MANIFEST" 2>/dev/null)
            # Extract decisions
            DECISIONS=$(jq -r '
                if .decisions then
                    [.decisions[] | "- **\(.topic)**: \(.chosen)"] | join("\n")
                else
                    ""
                end
            ' "$MANIFEST" 2>/dev/null)
        else
            NAME=""
            SUMMARY=""
            CURRENT_STAGE=""
            PATH_TYPE=""
            CHALLENGE_MODE=""
            WORK_UNITS="0"
            DECISIONS=""
        fi

        # Fallback to state.json for missing fields
        if [ -f "$STATE" ]; then
            [ -z "$NAME" ] && NAME=$(jq -r '.name // empty' "$STATE" 2>/dev/null)
            [ -z "$CURRENT_STAGE" ] && CURRENT_STAGE=$(jq -r '.current_stage // empty' "$STATE" 2>/dev/null)
            [ -z "$PATH_TYPE" ] && PATH_TYPE=$(jq -r '.path // .chosen_path // .recommended_path // empty' "$STATE" 2>/dev/null)
            [ -z "$CHALLENGE_MODE" ] && CHALLENGE_MODE=$(jq -r '.challenge_mode // empty' "$STATE" 2>/dev/null)
        fi

        # Final fallback for name: directory basename
        [ -z "$NAME" ] && NAME=$(basename "$plan_dir")

        # --- Date ---

        DATE=""
        if [ -f "$STATE" ]; then
            CREATED=$(jq -r '.created // empty' "$STATE" 2>/dev/null)
            if [ -n "$CREATED" ]; then
                DATE=$(iso_to_date "$CREATED")
            fi
        fi
        if [ -z "$DATE" ]; then
            # Fallback to manifest artifact timestamps or file mtime
            if [ -f "$MANIFEST" ]; then
                DATE=$(file_date "$MANIFEST")
            elif [ -f "$STATE" ]; then
                DATE=$(file_date "$STATE")
            else
                DATE=$(date '+%Y-%m-%d')
            fi
        fi

        # --- Project name ---

        PROJECT=$(get_project_name "$plan_dir")

        # --- Slug and dedup ---

        SLUG=$(make_slug "$NAME")
        FILENAME="${DATE}-${PROJECT}-${SLUG}.md"

        # Dedup check: any file matching *-PROJECT-SLUG.md
        if ls "$BLUEPRINT_DIR"/*-"${PROJECT}-${SLUG}.md" >/dev/null 2>&1; then
            echo "  SKIP (exists): $FILENAME"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi

        # --- Stage info ---

        STAGE_NAME=$(stage_name "$CURRENT_STAGE")
        STAGE_NUM=$(stage_number "$CURRENT_STAGE")

        # --- Adversarial findings ---

        FINDINGS_TEXT=""
        if [ -f "$ADVERSARIAL" ]; then
            # Extract first 5 lines that start with ** or - and contain [
            FINDINGS_TEXT=$(grep -E '^\*\*|^- .*\[|^### F|^### M' "$ADVERSARIAL" 2>/dev/null \
                | head -5 \
                | sed 's/^/- /')
        fi

        # --- Decisions fallback ---

        if [ -z "$DECISIONS" ]; then
            DECISIONS="No decisions recorded"
        fi
        if [ -z "$FINDINGS_TEXT" ]; then
            FINDINGS_TEXT="No adversarial findings recorded"
        fi
        if [ -z "$SUMMARY" ]; then
            SUMMARY="(No summary available)"
        fi

        # Default values
        [ -z "$PATH_TYPE" ] && PATH_TYPE="unknown"
        [ -z "$CHALLENGE_MODE" ] && CHALLENGE_MODE="unknown"

        # --- Write vault note ---

        TARGET="$BLUEPRINT_DIR/$FILENAME"

        NOTE="---
type: blueprint
schema_version: 1
date: ${DATE}
project: ${PROJECT}
blueprint: ${NAME}
stage: ${STAGE_NAME}
path: ${PATH_TYPE}
tags: [blueprint]
---

# Blueprint: ${NAME}

## Summary
${SUMMARY}

## Current Status
Stage ${STAGE_NUM}/7 — ${STAGE_NAME}
Path: ${PATH_TYPE} | Mode: ${CHALLENGE_MODE}

## Key Decisions
${DECISIONS}

## Adversarial Findings
${FINDINGS_TEXT}

<!-- user-content -->"

        if [ "$DRY_RUN" -eq 1 ]; then
            echo "  WOULD WRITE: $FILENAME (project=$PROJECT, stage=$STAGE_NAME)"
        else
            printf '%s\n' "$NOTE" > "$TARGET"
            echo "  WROTE: $FILENAME (project=$PROJECT, stage=$STAGE_NAME)"
        fi
        BLUEPRINTS_WRITTEN=$((BLUEPRINTS_WRITTEN + 1))
    done
done

# ============================================================
# PART 2: Findings Backfill
# ============================================================

echo ""
echo "=== Findings Backfill ==="

INSIGHT_FILES=(
    "$HOME/.empirica/insights.jsonl"
    "$REPO_ROOT/.empirica/insights.jsonl"
    "$HOME/project_scout/.empirica/insights.jsonl"
)

for insight_file in "${INSIGHT_FILES[@]}"; do
    [ -f "$insight_file" ] || continue

    echo "  Scanning: $insight_file"

    # Determine project from path
    INSIGHT_DIR=$(dirname "$insight_file")
    INSIGHT_PROJECT_DIR=$(dirname "$INSIGHT_DIR")
    if [ "$INSIGHT_PROJECT_DIR" = "$HOME" ]; then
        INSIGHT_PROJECT="global"
    else
        INSIGHT_PROJECT=$(get_project_name "$INSIGHT_PROJECT_DIR")
    fi

    # Process line by line
    while IFS= read -r line; do
        [ -z "$line" ] && continue

        # Parse type — skip non-finding entries
        ENTRY_TYPE=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)
        if [ "$ENTRY_TYPE" != "finding" ]; then
            continue
        fi

        # Extract fields
        TIMESTAMP=$(echo "$line" | jq -r '.timestamp // empty' 2>/dev/null)
        FINDING_TEXT=$(echo "$line" | jq -r '.input.finding // empty' 2>/dev/null)
        IMPACT=$(echo "$line" | jq -r '.input.impact // empty' 2>/dev/null)
        SESSION_ID=$(echo "$line" | jq -r '.input.session_id // empty' 2>/dev/null)
        CATEGORY=$(echo "$line" | jq -r '.input.category // "insight"' 2>/dev/null)

        [ -z "$FINDING_TEXT" ] && continue

        # Date from timestamp
        if [ -n "$TIMESTAMP" ]; then
            FDATE=$(iso_to_date "$TIMESTAMP")
        fi
        [ -z "$FDATE" ] && FDATE=$(date '+%Y-%m-%d')

        # Title: first ~60 chars, break at word boundary
        TITLE=$(echo "$FINDING_TEXT" | head -c 65 | sed 's/\(.\{55,\}\) .*/\1/' | sed 's/[[:space:]]*$//')
        [ ${#TITLE} -lt ${#FINDING_TEXT} ] && TITLE="${TITLE}..."

        # Slug
        FSLUG=$(make_slug "$TITLE")
        FFILENAME="${FDATE}-${INSIGHT_PROJECT}-${FSLUG}.md"

        # Dedup
        if ls "$FINDING_DIR"/*-"${INSIGHT_PROJECT}-${FSLUG}.md" >/dev/null 2>&1; then
            echo "    SKIP (exists): $FFILENAME"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi

        # Confidence: must be numeric, default 0.5
        CONFIDENCE="0.5"
        if [ -n "$IMPACT" ]; then
            # Check if numeric (integer or float)
            if echo "$IMPACT" | grep -qP '^\d+\.?\d*$'; then
                CONFIDENCE="$IMPACT"
            fi
        fi

        # Write vault note
        FTARGET="$FINDING_DIR/$FFILENAME"

        FNOTE="---
type: finding
schema_version: 1
date: ${FDATE}
project: ${INSIGHT_PROJECT}
category: ${CATEGORY}
severity: info
tags: [finding]
empirica_confidence: ${CONFIDENCE}
empirica_session: ${SESSION_ID}
empirica_status: active
---

# ${TITLE}

${FINDING_TEXT}

## Source
- Imported from pre-vault Empirica disk cache

## Implications
Review and assess — this finding was captured before vault integration.

<!-- user-content -->"

        if [ "$DRY_RUN" -eq 1 ]; then
            echo "    WOULD WRITE: $FFILENAME"
        else
            printf '%s\n' "$FNOTE" > "$FTARGET"
            echo "    WROTE: $FFILENAME"
        fi
        FINDINGS_WRITTEN=$((FINDINGS_WRITTEN + 1))

    done < "$insight_file"
done

# ============================================================
# Summary
# ============================================================

echo ""
echo "---"
echo "Backfill complete: $BLUEPRINTS_WRITTEN blueprints, $FINDINGS_WRITTEN findings ($SKIPPED skipped as duplicates)"
