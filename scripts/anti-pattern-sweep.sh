#!/usr/bin/env bash
# anti-pattern-sweep.sh — scan files against the anti-pattern catalog.
#
# Two modes:
#   --session  (default) scope = files modified this session
#   --full              scope = all git ls-files
#
# Counters are derived from .events.jsonl (append-only) on every sweep.
# The events log is the single source of truth — frontmatter counter values
# are recomputed and overwritten each run. Hand-edits to counter fields will
# not stick.
#
# Fail-open: missing catalog dir, missing jq, malformed entry, vault
# unavailable, unreachable reflog → log a single-line WARN to stderr,
# proceed with what we have, exit 0.
#
# Usage:
#   bash scripts/anti-pattern-sweep.sh            # session mode
#   bash scripts/anti-pattern-sweep.sh --session
#   bash scripts/anti-pattern-sweep.sh --full

set +e

MODE="--session"
case "${1:-}" in
    --full)             MODE="--full" ;;
    --session|"")       MODE="--session" ;;
    -h|--help)
        sed -n '2,20p' "$0"; exit 0 ;;
    *)
        echo "anti-pattern-sweep: unknown mode '$1' (use --session or --full)" >&2
        exit 1 ;;
esac

START_S=$(date +%s)
START_NS=$(date +%N 2>/dev/null || echo 0)
[ -z "$START_NS" ] || [ "$START_NS" = "%N" ] && START_NS=0

# Locate catalog
GIT_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null)
ROOT="${GIT_TOPLEVEL:-$PWD}"
CATALOG_DIR="$ROOT/.claude/anti-patterns"
[ -d "$CATALOG_DIR" ] || exit 0   # opt-in by directory presence

# jq is required
if ! command -v jq >/dev/null 2>&1; then
    echo "anti-pattern-sweep: jq required but not found, skipping" >&2
    exit 0
fi

EVENT_LOG="$CATALOG_DIR/.events.jsonl"
EVENT_ARCHIVE="$CATALOG_DIR/.events.archive.jsonl"
HEARTBEAT="$CATALOG_DIR/.last-sweep.json"

# Inline safe-swap fallbacks (rev2 F5: helper-or-fallback path).
# The epistemic helper validates JSON; for markdown frontmatter we need a
# different validator. Both are inline here for portability.
md_safe_swap() {
    local file="$1" tmp="$2"
    [ -s "$tmp" ] || { rm -f "$tmp"; return 1; }
    head -1 "$tmp" | grep -qE '^---$' || { rm -f "$tmp"; return 1; }
    # Verify a closing --- exists
    awk 'BEGIN{c=0} /^---$/{c++; if(c==2){found=1;exit}} END{exit found?0:1}' "$tmp" \
        || { rm -f "$tmp"; return 1; }
    mv "$tmp" "$file"
}

json_safe_swap() {
    local file="$1" tmp="$2"
    [ -s "$tmp" ] || { rm -f "$tmp"; return 1; }
    jq -e . "$tmp" >/dev/null 2>&1 || { rm -f "$tmp"; return 1; }
    mv "$tmp" "$file"
}

# Read a frontmatter scalar field from a markdown entry
read_field() {
    local file="$1" field="$2"
    awk -v f="$field" '
        /^---$/{c++; if(c>=2)exit; next}
        c==1 && index($0, f":") == 1 {
            sub("^" f ":[[:space:]]*", "")
            gsub(/^['\''"]|['\''"]$/, "")
            print; exit
        }
    ' "$file"
}

# Read a multi-line block scalar (e.g. fixture_good: |) from frontmatter
read_block() {
    local file="$1" field="$2"
    awk -v f="$field" '
        /^---$/{c++; if(c>=2)exit; next}
        c==1 && $0 ~ "^"f":[[:space:]]*\\|" {flag=1; next}
        c==1 && flag && /^[a-z_][a-z0-9_]*:/ {flag=0}
        c==1 && flag {print}
    ' "$file"
}

# ── Phase 1: parse + self-test catalog ─────────────────────────────────
# Use parallel arrays (works in bash 3+ on macOS without associative arrays)
ENTRY_IDS=()
ENTRY_REGEX=()
ENTRY_PATH=()
ENTRY_WINDOW=()

shopt -s nullglob
for entry in "$CATALOG_DIR"/*.md; do
    base="$(basename "$entry")"
    [ "$base" = "SCHEMA.md" ] && continue
    id="${base%.md}"

    # Skip retired
    status=$(read_field "$entry" "status")
    [ "$status" = "retired" ] && continue

    # Validate required fields
    missing=""
    for f in id language severity status detection_regex first_seen recent_window_days; do
        v=$(read_field "$entry" "$f")
        [ -z "$v" ] && missing="$missing $f"
    done
    if [ -n "$missing" ]; then
        echo "WARN: $id missing required field(s):$missing — skipping" >&2
        continue
    fi

    regex=$(read_field "$entry" "detection_regex")
    [ -z "$regex" ] && continue

    # Self-test (bit-rot guard)
    fb=$(read_block "$entry" "fixture_bad")
    fg=$(read_block "$entry" "fixture_good")
    if ! printf '%s' "$fb" | grep -qE "$regex" 2>/dev/null; then
        echo "WARN: $id self-test failed (regex doesn't match fixture_bad) — skipping" >&2
        continue
    fi
    if [ -n "$fg" ] && printf '%s' "$fg" | grep -qE "$regex" 2>/dev/null; then
        echo "WARN: $id self-test failed (regex matches fixture_good) — skipping" >&2
        continue
    fi

    rwd=$(read_field "$entry" "recent_window_days")
    [ -z "$rwd" ] && rwd=60

    ENTRY_IDS+=("$id")
    ENTRY_REGEX+=("$regex")
    ENTRY_PATH+=("$entry")
    ENTRY_WINDOW+=("$rwd")
done
shopt -u nullglob

PATTERNS_SCANNED=${#ENTRY_IDS[@]}

# ── Phase 2: build file list ──────────────────────────────────────────
EXCLUDE_RE='\.claude/(anti-patterns|plans)/|commands/templates/stock-anti-patterns/'
if [ -n "$VAULT_PATH" ]; then
    # Defensive: vault may live inside the project on some setups
    vault_re=$(printf '%s' "$VAULT_PATH/Engineering/Anti-Patterns/" | sed 's/[][\\^$.*+?()|{}/]/\\&/g')
    EXCLUDE_RE="$EXCLUDE_RE|$vault_re"
fi

FILE_LIST_TMP=$(mktemp)
trap 'rm -f "$FILE_LIST_TMP"' EXIT

if [ "$MODE" = "--full" ]; then
    if [ -n "$GIT_TOPLEVEL" ]; then
        ( cd "$GIT_TOPLEVEL" && git ls-files ) 2>/dev/null \
            | grep -vE "$EXCLUDE_RE" > "$FILE_LIST_TMP"
    else
        find . -type f \
            \( -name '*.sh' -o -name '*.py' -o -name '*.js' -o -name '*.ts' \
               -o -name '*.md' -o -name '*.yaml' -o -name '*.yml' \) \
            -not -path '*/.git/*' 2>/dev/null \
            | sed 's|^\./||' \
            | grep -vE "$EXCLUDE_RE" > "$FILE_LIST_TMP"
    fi
else
    # session mode
    if [ -n "$GIT_TOPLEVEL" ]; then
        cd "$GIT_TOPLEVEL"
        # Uncommitted changes
        git diff --name-only HEAD 2>/dev/null > "$FILE_LIST_TMP"
        # Untracked files (often where new anti-patterns get introduced)
        git ls-files --others --exclude-standard 2>/dev/null >> "$FILE_LIST_TMP"
        # Recent commits — guard the @{1.hour.ago} reflog reference (rev3 E24)
        recent_ref=$(git rev-parse '@{1.hour.ago}' 2>/dev/null)
        if [ -n "$recent_ref" ]; then
            git diff --name-only "$recent_ref"...HEAD 2>/dev/null >> "$FILE_LIST_TMP"
        fi
        # Dedupe + exclude catalog paths
        sort -u "$FILE_LIST_TMP" | grep -v '^$' | grep -vE "$EXCLUDE_RE" > "$FILE_LIST_TMP.f" \
            && mv "$FILE_LIST_TMP.f" "$FILE_LIST_TMP"
    else
        # Not in git repo: files modified in last 24h
        find . -type f -mtime -1 \
            \( -name '*.sh' -o -name '*.py' -o -name '*.js' -o -name '*.ts' \
               -o -name '*.md' -o -name '*.yaml' -o -name '*.yml' \) 2>/dev/null \
            | sed 's|^\./||' \
            | grep -vE "$EXCLUDE_RE" > "$FILE_LIST_TMP"
    fi
fi

FILES_SCANNED=$(grep -c . "$FILE_LIST_TMP" 2>/dev/null || echo 0)

# ── Phase 3: detection — append events for each (id, file, line) match ─
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EVENTS_APPENDED=0

# Track the set of (id, file, line) tuples seen in THIS sweep — used
# downstream for locations_remedied computation.
CURRENT_TUPLES_TMP=$(mktemp)
trap 'rm -f "$FILE_LIST_TMP" "$CURRENT_TUPLES_TMP"' EXIT

i=0
while [ "$i" -lt "${#ENTRY_IDS[@]}" ]; do
    id="${ENTRY_IDS[$i]}"
    regex="${ENTRY_REGEX[$i]}"

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        [ ! -f "$file" ] && continue
        # grep -nE prints "line:content" — extract just the line number
        while IFS= read -r match; do
            lineno="${match%%:*}"
            # Sanity: lineno must be a positive integer
            case "$lineno" in
                ''|*[!0-9]*) continue ;;
            esac
            event=$(jq -nc \
                --arg ts "$NOW" \
                --arg id "$id" \
                --arg file "$file" \
                --argjson line "$lineno" \
                --arg sweep "${MODE#--}" \
                '{ts: $ts, id: $id, file: $file, line: $line, sweep: $sweep}')
            echo "$event" >> "$EVENT_LOG"
            echo "$id|$file|$lineno" >> "$CURRENT_TUPLES_TMP"
            EVENTS_APPENDED=$((EVENTS_APPENDED + 1))
        done < <(grep -nE "$regex" "$file" 2>/dev/null)
    done < "$FILE_LIST_TMP"
    i=$((i + 1))
done

# ── Phase 4: events log cap (rev2 F4) ──────────────────────────────────
if [ -f "$EVENT_LOG" ]; then
    line_count=$(wc -l < "$EVENT_LOG")
    if [ "$line_count" -gt 10000 ]; then
        head -n 5000 "$EVENT_LOG" >> "$EVENT_ARCHIVE"
        tail -n +5001 "$EVENT_LOG" > "$EVENT_LOG.tmp" \
            && mv "$EVENT_LOG.tmp" "$EVENT_LOG"
        echo "Events log compacted: 5000 events archived" >&2
    fi
fi

# ── Phase 5: counter regen (deduped read of events log) ───────────────
i=0
while [ "$i" -lt "${#ENTRY_IDS[@]}" ]; do
    id="${ENTRY_IDS[$i]}"
    entry="${ENTRY_PATH[$i]}"
    rwd="${ENTRY_WINDOW[$i]}"

    # Compute cutoff timestamp (recent_window_days ago)
    cutoff_epoch=$(( $(date -u +%s) - rwd * 86400 ))
    cutoff_ts=$(date -u -d "@$cutoff_epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
        || date -u -r "$cutoff_epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
        || echo "1970-01-01T00:00:00Z")

    if [ -f "$EVENT_LOG" ]; then
        # Dedupe by (file, line) tuple, keep latest ts per tuple
        deduped=$(jq -c --arg id "$id" '
            select(.id == $id) | {file, line, ts}
        ' "$EVENT_LOG" 2>/dev/null \
            | jq -s '
                group_by(.file + ":" + (.line|tostring)) |
                map(max_by(.ts))
            ' 2>/dev/null)

        if [ -z "$deduped" ] || [ "$deduped" = "null" ]; then
            deduped='[]'
        fi

        total_hits=$(echo "$deduped" | jq 'length' 2>/dev/null)
        recent_hits=$(echo "$deduped" \
            | jq --arg c "$cutoff_ts" '[.[] | select(.ts >= $c)] | length' 2>/dev/null)
        last_seen=$(echo "$deduped" \
            | jq -r 'if length>0 then (max_by(.ts) | .ts) else "" end' 2>/dev/null)

        # locations_remedied: tuples present in old events (older than cutoff)
        # but absent from THIS sweep's matches.
        old_tuples=$(echo "$deduped" \
            | jq -r --arg c "$cutoff_ts" '.[] | select(.ts < $c) | "\(.file)|\(.line)"' 2>/dev/null \
            | sort -u)
        if [ -n "$old_tuples" ] && [ -f "$CURRENT_TUPLES_TMP" ]; then
            current_for_id=$(grep "^$id|" "$CURRENT_TUPLES_TMP" 2>/dev/null \
                | sed "s/^$id|//" | sort -u)
            locations_remedied=$(comm -23 \
                <(echo "$old_tuples") <(echo "$current_for_id") | grep -c . || echo 0)
        else
            locations_remedied=0
        fi
    else
        total_hits=0
        recent_hits=0
        last_seen=""
        locations_remedied=0
    fi

    # Default last_seen to first_seen if no events
    [ -z "$last_seen" ] && last_seen=$(read_field "$entry" "first_seen")

    # Defensive defaults
    : "${total_hits:=0}"
    : "${recent_hits:=0}"
    : "${locations_remedied:=0}"

    # Atomically rewrite frontmatter — touch only the four derived fields
    tmp="${entry}.tmp.$$"
    awk -v ls="$last_seen" -v th="$total_hits" -v rh="$recent_hits" \
        -v lr="$locations_remedied" '
        /^---$/ {
            c++; print
            if (c >= 2) flag = 0
            else flag = 1
            next
        }
        flag == 1 && /^last_seen:/         { print "last_seen: " ls; next }
        flag == 1 && /^total_hits:/        { print "total_hits: " th; next }
        flag == 1 && /^recent_hits:/       { print "recent_hits: " rh; next }
        flag == 1 && /^locations_remedied:/{ print "locations_remedied: " lr; next }
        { print }
    ' "$entry" > "$tmp"

    if ! md_safe_swap "$entry" "$tmp"; then
        echo "WARN: $id frontmatter swap failed (validation rejected new content)" >&2
    fi

    i=$((i + 1))
done

# ── Phase 6: heartbeat write (rev2 F-PM-1) ─────────────────────────────
END_S=$(date +%s)
DURATION_MS=$(( (END_S - START_S) * 1000 ))

HB_TMP="$HEARTBEAT.tmp.$$"
jq -nc \
    --arg ts "$NOW" \
    --argjson ps "$PATTERNS_SCANNED" \
    --argjson fs "$FILES_SCANNED" \
    --argjson ea "$EVENTS_APPENDED" \
    --argjson dms "$DURATION_MS" \
    --arg mode "${MODE#--}" \
    '{timestamp: $ts, patterns_scanned: $ps, files_scanned: $fs,
      events_appended: $ea, duration_ms: $dms, mode: $mode}' \
    > "$HB_TMP" 2>/dev/null

if ! json_safe_swap "$HEARTBEAT" "$HB_TMP"; then
    echo "WARN: heartbeat write failed" >&2
fi

# ── Phase 7: vault export (post-heartbeat per rev3 E23) ────────────────
# Outside the timeout-wrapped critical path. If vault is slow or unreachable,
# the project-local sweep has already completed and the heartbeat is committed.
if [ "${VAULT_ENABLED:-0}" = "1" ] && [ -n "${VAULT_PATH:-}" ] && [ -d "$VAULT_PATH" ]; then
    PROJECT=$(basename "$ROOT")
    VAULT_DIR="$VAULT_PATH/Engineering/Anti-Patterns"
    mkdir -p "$VAULT_DIR" 2>/dev/null

    if [ -d "$VAULT_DIR" ] && [ -w "$VAULT_DIR" ]; then
        i=0
        while [ "$i" -lt "${#ENTRY_IDS[@]}" ]; do
            id="${ENTRY_IDS[$i]}"
            entry="${ENTRY_PATH[$i]}"
            mirror="$VAULT_DIR/${PROJECT}-${id}.md"
            mirror_tmp="$mirror.tmp.$$"

            {
                echo "<!-- AUTO-GENERATED MIRROR — edits here are overwritten by the next project sweep."
                echo "     Edit the project-local catalog at .claude/anti-patterns/${id}.md instead. -->"
                echo ""
                # Inject project + mirror_of into frontmatter
                awk -v project="$PROJECT" -v src=".claude/anti-patterns/${id}.md" '
                    /^---$/ {
                        c++; print
                        if (c == 1) {
                            print "project: " project
                            print "mirror_of: " src
                        }
                        next
                    }
                    { print }
                ' "$entry"
            } > "$mirror_tmp"

            md_safe_swap "$mirror" "$mirror_tmp" \
                || { rm -f "$mirror_tmp"; echo "WARN: vault mirror failed for $id" >&2; }

            i=$((i + 1))
        done
    else
        echo "WARN: vault dir not writable, skipping mirror" >&2
    fi
fi

# Summary
echo "Anti-pattern sweep ($MODE): scanned $FILES_SCANNED files across $PATTERNS_SCANNED patterns. $EVENTS_APPENDED events recorded." >&2

exit 0
