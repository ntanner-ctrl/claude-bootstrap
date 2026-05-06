#!/bin/bash
#
# Claude Sail — Behavioral Smoke Tests
# Validates pre-captured output fixtures against structural assertions.
# DEV-ONLY: not part of the install path. Run from a cloned repo.
#
# Usage: bash scripts/behavioral-smoke.sh
# Requires: jq
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVALS_DIR="$SCRIPT_DIR/../evals"
EVALS_JSON="$EVALS_DIR/evals.json"

PASS=0
FAIL=0
WARN=0

green() { echo -e "\033[0;32m$1\033[0m"; }
red()   { echo -e "\033[0;31m$1\033[0m"; }
yellow(){ echo -e "\033[1;33m$1\033[0m"; }
bold()  { echo -e "\033[1m$1\033[0m"; }

pass() { PASS=$((PASS + 1)); echo "  $(green "✓") $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  $(red "✗") $1"; }
warn() { WARN=$((WARN + 1)); echo "  $(yellow "⚠") $1"; }

# ─── Guard: jq required ───────────────────────────────────────────

command -v jq >/dev/null 2>&1 || { echo "Error: jq required but not found"; exit 1; }

# ─── Guard: evals.json must exist ────────────────────────────────

if [ ! -f "$EVALS_JSON" ]; then
    echo "  $(red "✗") evals.json not found at $EVALS_JSON"
    exit 1
fi

if ! jq empty "$EVALS_JSON" 2>/dev/null; then
    echo "  $(red "✗") evals.json is invalid JSON"
    exit 1
fi

bold "Behavioral Smoke Tests (fixture-based, offline)"
echo ""

# ─── Main eval loop ───────────────────────────────────────────────

eval_count=0
jq_read_ok=0

eval_count=$(jq 'length' "$EVALS_JSON" 2>/dev/null)
if [ -z "$eval_count" ] || [ "$eval_count" -eq 0 ]; then
    warn "evals.json contains no entries — nothing to test"
    echo ""
    bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $(green "$PASS passed")  $(red "$FAIL failed")  $(yellow "$WARN warnings")"
    bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
fi

i=0
while [ "$i" -lt "$eval_count" ]; do

    # Per-entry jq: if any field read fails, record as FAIL and continue
    entry_name=$(jq -r ".[$i].name // empty" "$EVALS_JSON" 2>/dev/null)
    entry_command=$(jq -r ".[$i].command // empty" "$EVALS_JSON" 2>/dev/null)
    entry_fixture_rel=$(jq -r ".[$i].fixture // empty" "$EVALS_JSON" 2>/dev/null)
    assertion_count=$(jq ".[$i].assertions | length" "$EVALS_JSON" 2>/dev/null)

    # If jq failed to parse entry fields
    if [ -z "$entry_name" ]; then
        fail "entry[$i] — could not parse name from evals.json"
        i=$((i + 1))
        continue
    fi

    # ─── Hook execution mode ────────────────────────────────────────
    # Entries with a `hook` field run the hook with provided stdin and assert
    # against expected_exit + (optional) expected_stderr_contains. Distinct
    # from the fixture-based text-assertion mode below — used for behavioral
    # tests of PreToolUse hooks (where the hook code IS the fixture).

    entry_hook=$(jq -r ".[$i].hook // empty" "$EVALS_JSON" 2>/dev/null)

    if [ -n "$entry_hook" ]; then
        hook_path="$SCRIPT_DIR/../hooks/$entry_hook"

        if [ ! -f "$hook_path" ]; then
            warn "$entry_name: SKIP — hook file not found: $entry_hook"
            i=$((i + 1))
            continue
        fi

        # Build stdin JSON (compact form)
        entry_stdin=$(jq -c ".[$i].stdin // empty" "$EVALS_JSON" 2>/dev/null)
        if [ -z "$entry_stdin" ] || [ "$entry_stdin" = "null" ]; then
            fail "$entry_name — INVALID (hook entry missing stdin field)"
            i=$((i + 1))
            continue
        fi

        expected_exit=$(jq -r ".[$i].expected_exit // empty" "$EVALS_JSON" 2>/dev/null)
        expected_stderr=$(jq -r ".[$i].expected_stderr_contains // empty" "$EVALS_JSON" 2>/dev/null)

        if [ -z "$expected_exit" ]; then
            fail "$entry_name — INVALID (hook entry missing expected_exit)"
            i=$((i + 1))
            continue
        fi

        # Run the hook. Note: command_env field allows test-specific env vars
        # (e.g., SAIL_DISABLED_HOOKS) without bleeding into other tests.
        entry_env=$(jq -r ".[$i].command_env // empty" "$EVALS_JSON" 2>/dev/null)
        actual_stderr_file=$(mktemp)
        actual_exit=0
        if [ -n "$entry_env" ]; then
            env $entry_env bash "$hook_path" >/dev/null 2>"$actual_stderr_file" <<<"$entry_stdin" || actual_exit=$?
        else
            bash "$hook_path" >/dev/null 2>"$actual_stderr_file" <<<"$entry_stdin" || actual_exit=$?
        fi
        actual_stderr=$(cat "$actual_stderr_file")
        rm -f "$actual_stderr_file"

        entry_pass=0
        entry_fail=0
        entry_fail_desc=""

        # Assertion 1: exit code
        if [ "$actual_exit" = "$expected_exit" ]; then
            entry_pass=$((entry_pass + 1))
        else
            entry_fail=$((entry_fail + 1))
            entry_fail_desc="exit code mismatch (expected $expected_exit, got $actual_exit)"
        fi

        # Assertion 2: stderr substring (optional)
        if [ -n "$expected_stderr" ]; then
            if grep -qF -- "$expected_stderr" <<<"$actual_stderr"; then
                entry_pass=$((entry_pass + 1))
            else
                entry_fail=$((entry_fail + 1))
                if [ -z "$entry_fail_desc" ]; then
                    entry_fail_desc="stderr does not contain '$expected_stderr' (got: ${actual_stderr:0:120})"
                fi
            fi
        fi

        total_assertions=$((entry_pass + entry_fail))
        if [ "$entry_fail" -eq 0 ]; then
            pass "$entry_name: $entry_pass/$total_assertions assertions passed (hook-exec)"
        else
            fail "$entry_name: FAIL — $entry_fail_desc"
        fi

        i=$((i + 1))
        continue
    fi

    # ─── Fixture-based text assertion mode (existing) ──────────────

    # Vacuous pass guard: assertions must be non-null and have >= 1 entry
    if [ -z "$assertion_count" ] || [ "$assertion_count" -lt 1 ]; then
        fail "$entry_name — INVALID (assertions array is null, empty, or missing)"
        i=$((i + 1))
        continue
    fi

    # Resolve fixture path relative to evals dir
    fixture_file="$EVALS_DIR/$entry_fixture_rel"

    # Missing or empty fixture → SKIP
    if [ -z "$entry_fixture_rel" ] || [ ! -f "$fixture_file" ]; then
        warn "$entry_name: SKIP — fixture not found: $entry_fixture_rel"
        i=$((i + 1))
        continue
    fi

    if [ ! -s "$fixture_file" ]; then
        warn "$entry_name: SKIP — fixture is empty: $entry_fixture_rel"
        i=$((i + 1))
        continue
    fi

    # Run assertions
    entry_pass=0
    entry_fail=0
    entry_fail_desc=""

    j=0
    while [ "$j" -lt "$assertion_count" ]; do

        atype=$(jq -r ".[$i].assertions[$j].type // empty" "$EVALS_JSON" 2>/dev/null)
        adesc=$(jq -r ".[$i].assertions[$j].description // empty" "$EVALS_JSON" 2>/dev/null)

        if [ -z "$atype" ]; then
            entry_fail=$((entry_fail + 1))
            entry_fail_desc="assertion[$j] has no type"
            j=$((j + 1))
            continue
        fi

        assertion_ok=0

        case "$atype" in
            contains)
                avalue=$(jq -r ".[$i].assertions[$j].value // empty" "$EVALS_JSON" 2>/dev/null)
                if grep -qi -e "$avalue" "$fixture_file" 2>/dev/null; then
                    assertion_ok=1
                fi
                ;;

            contains-any)
                val_count=$(jq ".[$i].assertions[$j].values | length" "$EVALS_JSON" 2>/dev/null)
                k=0
                while [ "$k" -lt "$val_count" ]; do
                    v=$(jq -r ".[$i].assertions[$j].values[$k]" "$EVALS_JSON" 2>/dev/null)
                    if grep -qi -e "$v" "$fixture_file" 2>/dev/null; then
                        assertion_ok=1
                        break
                    fi
                    k=$((k + 1))
                done
                ;;

            not-contains)
                avalue=$(jq -r ".[$i].assertions[$j].value // empty" "$EVALS_JSON" 2>/dev/null)
                if ! grep -qi -e "$avalue" "$fixture_file" 2>/dev/null; then
                    assertion_ok=1
                fi
                ;;

            min-headers)
                avalue=$(jq -r ".[$i].assertions[$j].value // 0" "$EVALS_JSON" 2>/dev/null)
                hcount=$(grep -c "^## " "$fixture_file" 2>/dev/null || echo 0)
                if [ "$hcount" -ge "$avalue" ] 2>/dev/null; then
                    assertion_ok=1
                fi
                ;;

            min-length)
                avalue=$(jq -r ".[$i].assertions[$j].value // 0" "$EVALS_JSON" 2>/dev/null)
                chars=$(wc -c < "$fixture_file" 2>/dev/null || echo 0)
                if [ "$chars" -ge "$avalue" ] 2>/dev/null; then
                    assertion_ok=1
                fi
                ;;

            regex)
                avalue=$(jq -r ".[$i].assertions[$j].value // empty" "$EVALS_JSON" 2>/dev/null)
                if grep -Eqi -e "$avalue" "$fixture_file" 2>/dev/null; then
                    assertion_ok=1
                fi
                ;;

            *)
                entry_fail=$((entry_fail + 1))
                entry_fail_desc="unknown assertion type: $atype"
                j=$((j + 1))
                continue
                ;;
        esac

        if [ "$assertion_ok" -eq 1 ]; then
            entry_pass=$((entry_pass + 1))
        else
            entry_fail=$((entry_fail + 1))
            if [ -z "$entry_fail_desc" ]; then
                entry_fail_desc="\"$adesc\" ($atype)"
            fi
        fi

        j=$((j + 1))
    done

    # Report entry result
    total_assertions=$((entry_pass + entry_fail))
    if [ "$entry_fail" -eq 0 ]; then
        pass "$entry_name: $entry_pass/$total_assertions assertions passed"
    else
        fail "$entry_name: FAIL — assertion $entry_fail_desc"
    fi

    i=$((i + 1))
done

echo ""

# ─── Summary ──────────────────────────────────────────────────────

bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  $(green "$PASS passed")  $(red "$FAIL failed")  $(yellow "$WARN warnings")"
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    red "  Some behavioral checks failed."
    exit 1
fi

if [ "$WARN" -gt 0 ]; then
    echo ""
    yellow "  Passed with warnings."
    exit 0
fi

echo ""
green "  All behavioral checks passed."
exit 0
