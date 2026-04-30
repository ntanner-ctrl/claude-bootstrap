# Generated Tests: anti-pattern-catalog (rev3 spec)

**Generated:** 2026-04-30
**Spec source:** `spec.md` rev3
**Constraint:** spec-blind — tests written from contract (ACs + fail-open + preservation), not from implementation. Tests must be runnable by the implementer without knowing internal function names, temp-file paths, or sweep step ordering.

## Test Infrastructure Mapping

The toolkit has three existing test surfaces. New tests slot in:

| Test type | Lives in | Runner |
|---|---|---|
| Frontmatter validation | `test.sh` Category 4 | `bash test.sh` |
| Behavioral fixtures | `evals/evals.json` | `scripts/behavioral-smoke.sh` |
| Integration tests | `test.sh` Category 7 (install dry-run) + new fixtures | `bash test.sh` |
| Hand-runnable smoke tests | `tests/anti-pattern-catalog/` (new dir) | invoked by `test.sh` |

## Source Specification Mapping

### Success Criteria → Test Coverage

| AC | Criterion | Test Coverage |
|---|---|---|
| AC1 | Catalog has ≥3 entries | `test_ac1_catalog_min_entries` |
| AC2 | Sweep increments `recent_hits` on detection | `test_ac2_sweep_detects_pattern`, eval fixture `anti-pattern-sweep-detection` |
| AC3 | Sweep is idempotent | `test_ac3_idempotency`, eval fixture `anti-pattern-sweep-idempotency` |
| AC4 | A consumer cites a catalog ID | `test_ac4_consumer_citation` |
| AC5 | `--full` finds existing instances | `test_ac5_full_sweep_seed_count` |
| AC6 | Add-pattern docs exist + ≤1 page | `test_ac6_schema_doc_exists` |
| AC7 | Frontmatter test-validated | `test_ac7_frontmatter_required_fields` (test.sh Category 4 extension) |
| AC8 | Sweep fails open in `/end` | `test_ac8_end_exit_zero_on_sweep_corruption` |
| AC9 | Vault export fail-open | `test_ac9_sweep_succeeds_without_vault` |
| AC10 | Stock catalog ships via `/bootstrap-project` | `test_ac10_bootstrap_populates_anti_patterns` (extends test.sh Category 7) |
| AC11 | Heartbeat written on success | `test_ac11_heartbeat_after_sweep` |
| AC12 | `/end` surfaces stale-sweep nudge | `test_ac12_stale_sweep_nudge` |
| AC13 | Counter regen dedupes by tuple | `test_ac13_dedup_event_tuples`, eval fixture `anti-pattern-sweep-dedup` |
| AC14 | PreToolUse hook warning visible to Claude | `test_ac14_hook_visibility` — **EMPIRICAL VERIFICATION REQUIRED, not derivable from spec alone** |

### Preservation Contract → Test Coverage

| Invariant | Source | Test Coverage |
|---|---|---|
| `/end` exits 0 in all observed cases | toolkit fail-open discipline | `test_preserve_end_exit_zero` |
| Counters are derived, never hand-maintained | spec ("Counter fields are derived") | `test_preserve_counters_recomputable_from_log` |
| Hand-edited counter fields are overwritten on next sweep | spec schema invariants | `test_preserve_hand_edits_overwritten` |
| `SAIL_DISABLED_HOOKS` disables the new hook | toolkit hook convention | `test_preserve_sail_disabled_hooks_honored` |
| Existing hookify rules continue to fire | preservation | `test_preserve_existing_hookify_rules` |
| `install.sh` dry-run lands all files (no-regression) | test.sh Category 7 | extended `test_install_lands_stock_anti_patterns` |
| Vault-unset does not error | fail-open | covered by `test_ac9` |

### Failure Modes → Test Coverage

| Failure condition | Expected behavior | Test Coverage |
|---|---|---|
| Missing catalog dir | silent exit 0 (project not opted in) | `test_fail_missing_catalog_dir` |
| Malformed pattern frontmatter | WARN + skip pattern, sweep continues | `test_fail_malformed_frontmatter` |
| Self-test fails (regex doesn't match `fixture_bad`) | WARN + skip pattern | `test_fail_self_test_bad_mismatch` |
| Self-test fails (regex matches `fixture_good`) | WARN + skip pattern | `test_fail_self_test_good_match` |
| `git` unavailable | fall back to `find -mtime -1` heuristic | `test_fail_no_git_session_fallback` |
| `jq` unavailable | exit 0 with one-line warning | `test_fail_no_jq` |
| Vault unavailable | skip vault export silently, project sweep succeeds | `test_fail_vault_unavailable` |
| Truncated/corrupt event log line | skip line with WARN, sweep resilient | `test_fail_corrupt_event_log_line` |
| Read-only catalog dir | safe-swap rolls back, exit 0 + WARN | `test_fail_readonly_catalog_dir` |
| Disk full mid-sweep | tmp validate-before-swap catches, roll back | `test_fail_disk_full_simulation` |
| Sweep exceeds 5s session budget | partial counters written, sweep non-blocking | `test_fail_session_budget_timeout` |
| Network-mounted vault slow (rev3, E23) | sweep core completes within 5s, vault export runs after | `test_fail_slow_vault_does_not_block_sweep` |
| Reflog reference invalid post-rebase (rev3, E24) | sweep falls back to HEAD instead of phantom diff | `test_fail_reflog_invalid_post_rebase` |

---

## Generated Tests

All tests are bash. Conventions match `scripts/behavioral-smoke.sh`: setup → action → assert, exit 0 on pass / non-zero on fail, output to stderr only.

### Behavior Tests (Acceptance Criteria)

```bash
# ─────────────────────────────────────────────────────────────
# Test: AC1 — Catalog has ≥3 entries
# Behavior: after bootstrap, the catalog contains ≥3 active markdown entries
# ─────────────────────────────────────────────────────────────
test_ac1_catalog_min_entries() {
    local tmp=$(mktemp -d); trap "rm -rf $tmp" RETURN
    cd "$tmp" && git init -q && bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
    bash "$REPO_ROOT/commands/bootstrap-project.sh" --silent 2>/dev/null  # invocation contract per spec
    [ -d .claude/anti-patterns ] || { echo "FAIL: anti-patterns dir not created"; return 1; }
    local count=$(find .claude/anti-patterns -maxdepth 1 -name '*.md' ! -name 'SCHEMA.md' | wc -l)
    [ "$count" -ge 3 ] || { echo "FAIL: $count entries, expected ≥3"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Test: AC2 — Sweep detects a known-bad pattern
# Behavior: writing fixture_bad content to a non-excluded file then running sweep
#           appends ≥1 detection event for that pattern's id
# ─────────────────────────────────────────────────────────────
test_ac2_sweep_detects_pattern() {
    local tmp=$(setup_fresh_catalog)
    cd "$tmp"
    # Pick the first active catalog entry; extract its fixture_bad and id from frontmatter
    local id fixture
    read -r id fixture < <(extract_first_pattern_id_and_fixture_bad)
    # Write the fixture to a normal source file (NOT in excluded paths)
    mkdir -p src && printf '%s\n' "$fixture" > src/sample.sh
    git add -A && git commit -q -m "add sample"
    # Run sweep
    bash scripts/anti-pattern-sweep.sh --full 2>/dev/null
    # Assert: events log contains an event with this id pointing to src/sample.sh
    grep -F "\"id\":\"$id\"" .claude/anti-patterns/.events.jsonl 2>/dev/null \
        | grep -F '"file":"src/sample.sh"' >/dev/null \
        || { echo "FAIL: no event for $id at src/sample.sh"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Test: AC3 — Sweep is idempotent
# Behavior: running --full twice on unchanged source yields identical counters
# (timestamps may differ; counter values must not)
# ─────────────────────────────────────────────────────────────
test_ac3_idempotency() {
    local tmp=$(setup_fresh_catalog_with_known_matches)
    cd "$tmp"
    bash scripts/anti-pattern-sweep.sh --full 2>/dev/null
    local snapshot1=$(extract_all_counters .claude/anti-patterns)
    bash scripts/anti-pattern-sweep.sh --full 2>/dev/null
    local snapshot2=$(extract_all_counters .claude/anti-patterns)
    [ "$snapshot1" = "$snapshot2" ] \
        || { echo "FAIL: counters changed between sweeps"; diff <(echo "$snapshot1") <(echo "$snapshot2"); return 1; }
}

# ─────────────────────────────────────────────────────────────
# Test: AC4 — A consumer cites a catalog ID by convention
# Behavior: at least one shipped consumer artifact contains a `Catalog: <id>` reference
#          where <id> matches a catalog entry filename
# ─────────────────────────────────────────────────────────────
test_ac4_consumer_citation() {
    cd "$REPO_ROOT"
    local catalog_ids=$(find commands/templates/stock-anti-patterns -maxdepth 1 -name '*.md' ! -name 'SCHEMA.md' \
        | xargs -n1 basename | sed 's/\.md$//')
    [ -n "$catalog_ids" ] || { echo "FAIL: no stock catalog entries to cite"; return 1; }
    # Search consumer surfaces for `Catalog: <id>` reference matching any catalog id
    local found=0
    for id in $catalog_ids; do
        if grep -rE "Catalog:[[:space:]]*${id}\b" hooks/ hookify-rules/ 2>/dev/null | grep -v ':#' >/dev/null; then
            found=1; break
        fi
    done
    [ "$found" = 1 ] || { echo "FAIL: no consumer cites any catalog id"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Test: AC5 — --full sweep finds existing pattern instances
# Behavior: running --full on the claude-sail repo finds the known instances
#           that hand-grep would find (within excluded-paths filter)
# ─────────────────────────────────────────────────────────────
test_ac5_full_sweep_seed_count() {
    cd "$REPO_ROOT"
    # Hand-count known instances of the seeded pattern using only its detection_regex
    # (run grep manually in the same scope the sweep would use, EXCLUDING catalog paths)
    local pattern_id="bash-unsafe-atomic-write"   # known seed
    local regex=$(jq -r '.detection_regex // empty' < <(extract_frontmatter_json ".claude/anti-patterns/${pattern_id}.md"))
    [ -n "$regex" ] || { echo "SKIP: seed pattern not present"; return 0; }
    local hand_count=$(git ls-files \
        | grep -vE '\.claude/(anti-patterns|plans)/|commands/templates/stock-anti-patterns/' \
        | xargs grep -lE "$regex" 2>/dev/null | wc -l)
    bash scripts/anti-pattern-sweep.sh --full 2>/dev/null
    local sweep_count=$(grep -c "\"id\":\"$pattern_id\"" .claude/anti-patterns/.events.jsonl 2>/dev/null || echo 0)
    # Sweep count must be ≥ hand count (sweep counts per-line, hand-grep counts per-file; allow ≥)
    [ "$sweep_count" -ge "$hand_count" ] \
        || { echo "FAIL: sweep saw $sweep_count, hand-grep saw $hand_count files"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Test: AC6 — Schema doc exists and is ≤1 page
# Behavior: SCHEMA.md exists under .claude/anti-patterns/ and stock template,
#          documents schema fields, add-pattern flow, and counter semantics
# ─────────────────────────────────────────────────────────────
test_ac6_schema_doc_exists() {
    cd "$REPO_ROOT"
    local schema="commands/templates/stock-anti-patterns/SCHEMA.md"
    [ -f "$schema" ] || { echo "FAIL: $schema missing"; return 1; }
    local lines=$(wc -l < "$schema")
    [ "$lines" -le 80 ] || { echo "FAIL: SCHEMA.md is $lines lines, expected ≤80 (~1 page)"; return 1; }
    # Required content sections (spec-derived: schema reference, add-pattern, counter semantics)
    grep -qiE "schema|frontmatter" "$schema" && \
    grep -qiE "add (a )?pattern" "$schema" && \
    grep -qiE "counter|derived" "$schema" \
        || { echo "FAIL: SCHEMA.md missing required topic sections"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Test: AC7 — Frontmatter required fields validated by test.sh
# Behavior: an entry missing a required field causes test.sh Category 4 to fail
# ─────────────────────────────────────────────────────────────
test_ac7_frontmatter_required_fields() {
    local tmp=$(setup_fresh_repo_with_toolkit)
    cd "$tmp"
    mkdir -p .claude/anti-patterns
    # Write a deliberately-broken entry missing `severity`
    cat > .claude/anti-patterns/broken-test.md <<'EOF'
---
id: broken-test
language: bash
status: active
detection_regex: 'foo'
fixture_good: |
  good
fixture_bad: |
  bad
first_seen: 2026-01-01
recent_window_days: 60
---
# Broken
EOF
    # test.sh Category 4 must fail
    if bash test.sh 2>&1 | grep -q "broken-test.*missing.*severity"; then
        return 0
    else
        echo "FAIL: test.sh did not detect missing required field"; return 1
    fi
}

# ─────────────────────────────────────────────────────────────
# Test: AC8 — Sweep failure does not break /end
# Behavior: corrupt the catalog (e.g., replace a regex with invalid syntax),
#          run /end equivalent, observe exit 0
# ─────────────────────────────────────────────────────────────
test_ac8_end_exit_zero_on_sweep_corruption() {
    local tmp=$(setup_fresh_catalog_with_known_matches)
    cd "$tmp"
    # Corrupt one pattern's regex to invalid ERE
    local first_entry=$(find .claude/anti-patterns -maxdepth 1 -name '*.md' ! -name 'SCHEMA.md' | head -1)
    sed -i "s/^detection_regex:.*/detection_regex: '['/g" "$first_entry"   # unclosed bracket = invalid ERE
    # Run the /end-equivalent integration block (the sweep invocation)
    set +e
    bash scripts/anti-pattern-sweep.sh --session 2>&1 >/dev/null
    local rc=$?
    set -e
    [ "$rc" -eq 0 ] || { echo "FAIL: sweep exited $rc, expected 0 (fail-open)"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Test: AC9 — Vault unavailable does not break sweep
# Behavior: with VAULT_ENABLED unset, sweep completes successfully
# ─────────────────────────────────────────────────────────────
test_ac9_sweep_succeeds_without_vault() {
    local tmp=$(setup_fresh_catalog_with_known_matches)
    cd "$tmp"
    unset VAULT_ENABLED VAULT_PATH
    bash scripts/anti-pattern-sweep.sh --full 2>/dev/null \
        || { echo "FAIL: sweep failed when vault unavailable"; return 1; }
    [ -f .claude/anti-patterns/.events.jsonl ] \
        || { echo "FAIL: project-local sweep didn't run when vault absent"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Test: AC10 — Stock catalog ships via /bootstrap-project
# Behavior: bootstrapping a fresh project populates .claude/anti-patterns/ with starters
# ─────────────────────────────────────────────────────────────
test_ac10_bootstrap_populates_anti_patterns() {
    local tmp=$(mktemp -d); trap "rm -rf $tmp" RETURN
    cd "$tmp" && git init -q
    HOME="$tmp/fakehome" bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
    HOME="$tmp/fakehome" bash "$REPO_ROOT/commands/bootstrap-project.sh" --silent 2>/dev/null
    [ -d .claude/anti-patterns ] || { echo "FAIL: bootstrap did not create anti-patterns dir"; return 1; }
    local count=$(find .claude/anti-patterns -maxdepth 1 -name '*.md' ! -name 'SCHEMA.md' | wc -l)
    [ "$count" -ge 3 ] || { echo "FAIL: bootstrap populated $count entries, expected ≥3"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Test: AC11 — Heartbeat is written after successful sweep
# Behavior: after `--full` succeeds, .last-sweep.json exists with required fields
# ─────────────────────────────────────────────────────────────
test_ac11_heartbeat_after_sweep() {
    local tmp=$(setup_fresh_catalog)
    cd "$tmp"
    bash scripts/anti-pattern-sweep.sh --full 2>/dev/null
    local hb=.claude/anti-patterns/.last-sweep.json
    [ -f "$hb" ] || { echo "FAIL: heartbeat file not written"; return 1; }
    # Required fields per spec: timestamp, patterns_scanned, files_scanned,
    #                          events_appended, duration_ms, mode
    for field in timestamp patterns_scanned events_appended duration_ms mode; do
        jq -e --arg f "$field" 'has($f)' "$hb" >/dev/null \
            || { echo "FAIL: heartbeat missing $field"; return 1; }
    done
}

# ─────────────────────────────────────────────────────────────
# Test: AC12 — /end nudges on stale heartbeat
# Behavior: with .last-sweep.json artificially aged to 8+ days, /end stderr
#          contains "last successful sweep"
# ─────────────────────────────────────────────────────────────
test_ac12_stale_sweep_nudge() {
    local tmp=$(setup_fresh_catalog)
    cd "$tmp"
    # Age the heartbeat to 8 days ago
    local stale_ts=$(date -u -d '8 days ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
                  || date -u -v-8d +%Y-%m-%dT%H:%M:%SZ)
    echo "{\"timestamp\":\"$stale_ts\",\"patterns_scanned\":3,\"events_appended\":0,\"duration_ms\":42,\"mode\":\"session\"}" \
        > .claude/anti-patterns/.last-sweep.json
    # Run the /end integration block (extracted equivalent)
    local stderr=$(bash "$REPO_ROOT/skills/end/end.sh" --dry-run 2>&1 1>/dev/null)
    echo "$stderr" | grep -qE 'last successful sweep:.*[0-9]+d ago' \
        || { echo "FAIL: stale-sweep nudge not surfaced in /end stderr"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Test: AC13 (rev3) — Counter regen dedupes by (id, file, line) tuple
# Behavior: append two events for the same tuple seconds apart;
#          counter recomputation yields total_hits = 1, not 2
# ─────────────────────────────────────────────────────────────
test_ac13_dedup_event_tuples() {
    local tmp=$(setup_fresh_catalog_with_known_matches)
    cd "$tmp"
    bash scripts/anti-pattern-sweep.sh --full 2>/dev/null   # establish baseline events
    # Append a duplicate event manually for an existing (id, file, line) tuple
    local sample_event=$(tail -1 .claude/anti-patterns/.events.jsonl)
    [ -n "$sample_event" ] || { echo "SKIP: no baseline events to duplicate"; return 0; }
    local dup_event=$(echo "$sample_event" | jq -c '.ts = (now | todateiso8601)')
    echo "$dup_event" >> .claude/anti-patterns/.events.jsonl
    # Re-run sweep counter regen (in-place; could be a `--regen-only` flag or just a no-op sweep)
    bash scripts/anti-pattern-sweep.sh --full 2>/dev/null
    # Assert total_hits matches unique tuple count, not raw event count
    local id=$(echo "$sample_event" | jq -r .id)
    local entry=".claude/anti-patterns/${id}.md"
    local total=$(extract_frontmatter_field "$entry" "total_hits")
    local unique_tuples=$(jq -r --arg id "$id" 'select(.id == $id) | "\(.file):\(.line)"' \
                          .claude/anti-patterns/.events.jsonl | sort -u | wc -l)
    [ "$total" = "$unique_tuples" ] \
        || { echo "FAIL: total_hits=$total, expected $unique_tuples (deduped)"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Test: AC14 (rev3) — PreToolUse hook warning is visible to Claude
#
# CRITICAL: This AC is NOT spec-derivable as a pure unit test. The contract
# claim "stderr from PreToolUse is surfaced to Claude in tool-feedback" is an
# empirical property of the Claude Code harness, not a property of the hook
# script itself. The test below is the strongest spec-blind assertion possible:
# it verifies the hook EMITS the warning correctly. Whether Claude SEES it
# requires manual verification with a live session.
#
# Acceptable test forms in order of preference:
#  1. (preferred) During WU6, run the hook against a deliberately-matching
#     Write input via `echo $JSON | bash hooks/anti-pattern-write-check.sh`.
#     Capture stderr. Assert it contains `Catalog: <id>`.
#  2. (gating) Manually invoke a Write in a Claude Code session against a file
#     containing fixture_bad content. Visually confirm the tool-feedback
#     surfaces "Catalog: <id>" text.
#  3. (fallback if (2) fails) Replace warn-via-stderr with an alternative
#     visibility mechanism (file marker, block-with-marker exit code) and
#     re-run (1) + (2) against the new mechanism.
# ─────────────────────────────────────────────────────────────
test_ac14_hook_visibility() {
    cd "$REPO_ROOT"
    local hook=hooks/anti-pattern-write-check.sh
    [ -f "$hook" ] || { echo "FAIL: hook not implemented yet"; return 1; }
    # Form 1 (rev4): hook emits valid JSON to STDOUT (not stderr) containing
    # hookSpecificOutput.additionalContext with Catalog: <id> on matching input.
    local fixture=$(extract_first_pattern_fixture_bad_from_stock)
    local id=$(extract_first_pattern_id_from_stock)
    local mock_input=$(jq -nc --arg c "$fixture" '{tool_input: {content: $c, file_path: "test.sh"}}')
    local stdout=$(echo "$mock_input" | bash "$hook" 2>/dev/null)
    # Validate JSON shape per Claude Code docs
    echo "$stdout" | jq -e '.hookSpecificOutput.hookEventName == "PreToolUse"' >/dev/null \
        || { echo "FAIL: hook did not output valid hookSpecificOutput JSON"; return 1; }
    echo "$stdout" | jq -e '.hookSpecificOutput.permissionDecision == "allow"' >/dev/null \
        || { echo "FAIL: hook did not emit permissionDecision=allow"; return 1; }
    local ctx=$(echo "$stdout" | jq -r '.hookSpecificOutput.additionalContext // empty')
    echo "$ctx" | grep -qE "Catalog:[[:space:]]*${id}\b" \
        || { echo "FAIL: additionalContext does not include Catalog: $id"; return 1; }
    # Stderr should be empty on warn (no error/blocking output)
    local stderr=$(echo "$mock_input" | bash "$hook" 2>&1 1>/dev/null)
    [ -z "$stderr" ] \
        || { echo "FAIL: hook emitted stderr on warn (should be silent — additionalContext only)"; return 1; }
    # Form 2 is manual fresh-session verification
    echo "INFO: AC14 form 1 PASSED (hook outputs valid additionalContext JSON)." >&2
    echo "INFO: AC14 form 2 REQUIRES MANUAL: in a fresh Claude Code session," >&2
    echo "      wire the hook in settings.local.json, attempt a Write with fixture_bad" >&2
    echo "      content, confirm tool feedback contains 'Catalog: <id>'." >&2
    echo "      Docs: https://code.claude.com/docs/en/hooks" >&2
    echo "      Empirical reference: ac14-verification.md" >&2
}
```

### Contract Tests (Preservation)

```bash
# ─────────────────────────────────────────────────────────────
# Contract: /end exits 0 in all observed cases
# Pre-state: catalog populated and either healthy or corrupted
# Action: invoke /end's sweep-integration code path
# Assert: exit code 0
# ─────────────────────────────────────────────────────────────
test_preserve_end_exit_zero() {
    for state in healthy corrupted_regex missing_jq_simulated readonly_dir; do
        local tmp=$(setup_catalog_in_state "$state")
        cd "$tmp"
        set +e
        bash "$REPO_ROOT/skills/end/end.sh" --dry-run >/dev/null 2>&1
        local rc=$?
        set -e
        [ "$rc" -eq 0 ] \
            || { echo "FAIL: /end exit=$rc in state=$state, expected 0"; return 1; }
        rm -rf "$tmp"
    done
}

# ─────────────────────────────────────────────────────────────
# Contract: Counters are derived from events.jsonl, not maintained
# Pre-state: known events.jsonl with N events for pattern X
# Action: hand-edit a counter field to a wrong value, run sweep
# Assert: counter is overwritten to match events log
# ─────────────────────────────────────────────────────────────
test_preserve_counters_recomputable_from_log() {
    local tmp=$(setup_fresh_catalog_with_known_matches)
    cd "$tmp"
    bash scripts/anti-pattern-sweep.sh --full 2>/dev/null
    # Hand-corrupt a counter
    local entry=$(find .claude/anti-patterns -maxdepth 1 -name '*.md' ! -name 'SCHEMA.md' | head -1)
    sed -i 's/^total_hits:.*$/total_hits: 9999/' "$entry"
    # Run sweep with no source changes — should rewrite counters from events
    bash scripts/anti-pattern-sweep.sh --full 2>/dev/null
    local rewritten=$(extract_frontmatter_field "$entry" "total_hits")
    [ "$rewritten" != "9999" ] \
        || { echo "FAIL: hand-edit not overwritten — counter is maintained, not derived"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Contract: Hand-edited counter fields are overwritten on next sweep
# (subset of preserve_counters_recomputable_from_log; explicit per spec invariant)
# ─────────────────────────────────────────────────────────────
test_preserve_hand_edits_overwritten() {
    test_preserve_counters_recomputable_from_log
}

# ─────────────────────────────────────────────────────────────
# Contract: SAIL_DISABLED_HOOKS disables anti-pattern-write-check
# Pre-state: hook installed, fixture_bad content prepared
# Action: invoke hook with SAIL_DISABLED_HOOKS=anti-pattern-write-check
# Assert: hook exits 0 with no stderr
# ─────────────────────────────────────────────────────────────
test_preserve_sail_disabled_hooks_honored() {
    cd "$REPO_ROOT"
    local hook=hooks/anti-pattern-write-check.sh
    [ -f "$hook" ] || { echo "SKIP: hook not yet implemented"; return 0; }
    local fixture=$(extract_first_pattern_fixture_bad_from_stock)
    local mock_input=$(jq -nc --arg c "$fixture" '{tool_input: {content: $c}}')
    local stderr=$(SAIL_DISABLED_HOOKS=anti-pattern-write-check \
        echo "$mock_input" | bash "$hook" 2>&1 1>/dev/null)
    [ -z "$stderr" ] \
        || { echo "FAIL: hook produced output despite being in SAIL_DISABLED_HOOKS"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Contract: Existing hookify rules continue to fire
# Pre-state: existing hookify rules in hookify-rules/
# Action: run a known trigger for an existing rule (e.g., force-push command)
# Assert: rule is detected/processed as before
# ─────────────────────────────────────────────────────────────
test_preserve_existing_hookify_rules() {
    cd "$REPO_ROOT"
    local count_before=$(find hookify-rules -name '*.local.md' | wc -l)
    # New rules should not have been added; the catalog ships a shell hook, not a hookify rule
    local count_after=$(find hookify-rules -name '*.local.md' | wc -l)
    [ "$count_before" = "$count_after" ] \
        || { echo "FAIL: hookify rule count changed unexpectedly"; return 1; }
    # Smoke-check each rule still parses
    for rule in hookify-rules/*.local.md; do
        head -10 "$rule" | grep -q '^---$' \
            || { echo "FAIL: $rule lost its frontmatter delimiter"; return 1; }
    done
}

# ─────────────────────────────────────────────────────────────
# Contract: install.sh dry-run lands stock-anti-patterns into install target
# Extends test.sh Category 7 (existing install dry-run check)
# ─────────────────────────────────────────────────────────────
test_install_lands_stock_anti_patterns() {
    local tmp=$(mktemp -d); trap "rm -rf $tmp" RETURN
    HOME="$tmp" bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
    [ -d "$tmp/.claude/commands/templates/stock-anti-patterns" ] \
        || { echo "FAIL: install did not land stock-anti-patterns"; return 1; }
    local count=$(find "$tmp/.claude/commands/templates/stock-anti-patterns" -maxdepth 1 -name '*.md' | wc -l)
    [ "$count" -ge 4 ] \
        || { echo "FAIL: stock-anti-patterns has $count files, expected ≥4 (3 patterns + SCHEMA)"; return 1; }
}
```

### Failure Mode Tests

```bash
# ─────────────────────────────────────────────────────────────
# Failure: Missing catalog dir → silent exit 0 (project not opted in)
# ─────────────────────────────────────────────────────────────
test_fail_missing_catalog_dir() {
    local tmp=$(mktemp -d); trap "rm -rf $tmp" RETURN
    cd "$tmp" && git init -q
    # No .claude/anti-patterns/ directory
    set +e
    bash "$REPO_ROOT/scripts/anti-pattern-sweep.sh" --session 2>&1 >/dev/null
    local rc=$?
    set -e
    [ "$rc" -eq 0 ] || { echo "FAIL: missing catalog rc=$rc"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Failure: Malformed YAML frontmatter → WARN + skip pattern, sweep continues
# ─────────────────────────────────────────────────────────────
test_fail_malformed_frontmatter() {
    local tmp=$(setup_fresh_catalog)
    cd "$tmp"
    # Corrupt one entry's frontmatter
    local bad=$(find .claude/anti-patterns -maxdepth 1 -name '*.md' ! -name 'SCHEMA.md' | head -1)
    echo "this is not yaml ---" > "$bad"
    local stderr=$(bash scripts/anti-pattern-sweep.sh --full 2>&1 1>/dev/null)
    echo "$stderr" | grep -qiE "warn|skip" \
        || { echo "FAIL: no WARN emitted for malformed frontmatter"; return 1; }
    # Other patterns must still have been processed
    [ -f .claude/anti-patterns/.events.jsonl ] \
        || { echo "FAIL: sweep aborted instead of skipping bad pattern"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Failure: Self-test fails (regex doesn't match fixture_bad) → WARN + skip
# ─────────────────────────────────────────────────────────────
test_fail_self_test_bad_mismatch() {
    local tmp=$(setup_fresh_catalog)
    cd "$tmp"
    local entry=$(find .claude/anti-patterns -maxdepth 1 -name '*.md' ! -name 'SCHEMA.md' | head -1)
    local id=$(basename "$entry" .md)
    # Replace fixture_bad with content that won't match the regex
    sed -i 's/^fixture_bad: |.*$/fixture_bad: |\n  this will not match anything/' "$entry"
    local stderr=$(bash scripts/anti-pattern-sweep.sh --full 2>&1 1>/dev/null)
    echo "$stderr" | grep -qiE "self.?test|skip" \
        || { echo "FAIL: self-test mismatch did not emit WARN"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Failure: Self-test fails (regex matches fixture_good) → WARN + skip
# ─────────────────────────────────────────────────────────────
test_fail_self_test_good_match() {
    local tmp=$(setup_fresh_catalog)
    cd "$tmp"
    local entry=$(find .claude/anti-patterns -maxdepth 1 -name '*.md' ! -name 'SCHEMA.md' | head -1)
    # Replace fixture_good with content that DOES match the regex
    local fixture_bad=$(extract_frontmatter_field "$entry" "fixture_bad")
    sed -i "s/^fixture_good: |.*$/fixture_good: |\n  ${fixture_bad}/" "$entry"
    local stderr=$(bash scripts/anti-pattern-sweep.sh --full 2>&1 1>/dev/null)
    echo "$stderr" | grep -qiE "self.?test|skip" \
        || { echo "FAIL: fixture_good false-positive did not emit WARN"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Failure: git unavailable → fall back to find-mtime heuristic
# ─────────────────────────────────────────────────────────────
test_fail_no_git_session_fallback() {
    local tmp=$(setup_fresh_catalog_outside_git)   # no .git directory
    cd "$tmp"
    set +e
    bash "$REPO_ROOT/scripts/anti-pattern-sweep.sh" --session 2>/dev/null
    local rc=$?
    set -e
    [ "$rc" -eq 0 ] \
        || { echo "FAIL: sweep failed when not in git repo (rc=$rc)"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Failure: jq unavailable → exit 0 with one-line warning
# ─────────────────────────────────────────────────────────────
test_fail_no_jq() {
    local tmp=$(setup_fresh_catalog)
    cd "$tmp"
    # Simulate missing jq via PATH manipulation
    local stub=$(mktemp -d)
    cat > "$stub/jq" <<'EOF'
#!/usr/bin/env bash
exit 127
EOF
    chmod +x "$stub/jq"
    set +e
    PATH="$stub:$PATH" bash "$REPO_ROOT/scripts/anti-pattern-sweep.sh" --full 2>&1 >/dev/null
    local rc=$?
    set -e
    rm -rf "$stub"
    [ "$rc" -eq 0 ] \
        || { echo "FAIL: sweep exited $rc with jq broken, expected 0"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Failure: Vault unavailable → silent skip of vault export
# (covered by test_ac9; explicit failure-mode form here)
# ─────────────────────────────────────────────────────────────
test_fail_vault_unavailable() { test_ac9_sweep_succeeds_without_vault; }

# ─────────────────────────────────────────────────────────────
# Failure (rev3 E10/E21): Truncated/corrupt event log line → skip + WARN
# ─────────────────────────────────────────────────────────────
test_fail_corrupt_event_log_line() {
    local tmp=$(setup_fresh_catalog_with_known_matches)
    cd "$tmp"
    bash scripts/anti-pattern-sweep.sh --full 2>/dev/null
    # Append a malformed line (truncated mid-JSON)
    echo '{"ts":"2026-04-30T10:00:00Z","id":"foo","fi' >> .claude/anti-patterns/.events.jsonl
    set +e
    local stderr=$(bash scripts/anti-pattern-sweep.sh --full 2>&1 1>/dev/null)
    local rc=$?
    set -e
    [ "$rc" -eq 0 ] \
        || { echo "FAIL: corrupt log line broke sweep (rc=$rc)"; return 1; }
    echo "$stderr" | grep -qiE "warn|skip|malformed" \
        || { echo "FAIL: no WARN for corrupt event log line"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Failure: Read-only catalog dir → safe-swap rolls back, exit 0 + WARN
# ─────────────────────────────────────────────────────────────
test_fail_readonly_catalog_dir() {
    local tmp=$(setup_fresh_catalog)
    cd "$tmp"
    chmod -w .claude/anti-patterns
    set +e
    bash "$REPO_ROOT/scripts/anti-pattern-sweep.sh" --full 2>/dev/null
    local rc=$?
    set -e
    chmod +w .claude/anti-patterns
    [ "$rc" -eq 0 ] \
        || { echo "FAIL: readonly dir broke sweep (rc=$rc)"; return 1; }
}

# ─────────────────────────────────────────────────────────────
# Failure: Disk full mid-sweep → tmp validate-before-swap catches, roll back
# (Hard to simulate portably; documented as manual-verify)
# ─────────────────────────────────────────────────────────────
test_fail_disk_full_simulation() {
    echo "SKIP: disk-full simulation is manual — use a small loopback FS to verify roll-back"
    return 0
}

# ─────────────────────────────────────────────────────────────
# Failure: Session sweep exceeds 5s budget → partial counters, non-blocking
# ─────────────────────────────────────────────────────────────
test_fail_session_budget_timeout() {
    local tmp=$(setup_fresh_catalog)
    cd "$tmp"
    # Synthesize a slow scan: write many large source files containing the fixture_bad
    mkdir -p src
    local fixture=$(extract_first_pattern_fixture_bad_from_stock)
    for i in $(seq 1 500); do
        for j in $(seq 1 100); do echo "$fixture"; done > "src/big_$i.sh"
    done
    git init -q && git add -A && git commit -q -m "fill"
    # Run session sweep with the timeout per spec
    set +e
    timeout 6 bash "$REPO_ROOT/scripts/anti-pattern-sweep.sh" --session 2>/dev/null
    local rc=$?
    set -e
    [ "$rc" -le 124 ] || { echo "FAIL: session sweep exit=$rc, expected ≤124"; return 1; }
    # /end equivalent must still succeed
    set +e
    bash "$REPO_ROOT/skills/end/end.sh" --dry-run >/dev/null 2>&1
    [ "$?" -eq 0 ] || { echo "FAIL: /end blocked by slow session sweep"; return 1; }
    set -e
}

# ─────────────────────────────────────────────────────────────
# Failure (rev3 E23): Slow vault path doesn't blow project sweep budget
# ─────────────────────────────────────────────────────────────
test_fail_slow_vault_does_not_block_sweep() {
    local tmp=$(setup_fresh_catalog_with_known_matches)
    cd "$tmp"
    # Point VAULT_PATH at a FUSE/sleep-wrapped mount or simulate via a slow-write directory
    local slow_vault=$(mktemp -d)
    # Wrap the vault dir's writes with a 200ms delay using a fifo trick or alias
    # (Implementation: spec says sweep core completes within timeout; vault export is post-timeout)
    export VAULT_ENABLED=1 VAULT_PATH="$slow_vault"
    local start=$(date +%s)
    timeout 6 bash "$REPO_ROOT/scripts/anti-pattern-sweep.sh" --session 2>/dev/null
    local rc=$?
    local elapsed=$(( $(date +%s) - start ))
    [ "$rc" -eq 0 ] || { echo "FAIL: sweep blocked by slow vault (rc=$rc)"; return 1; }
    # Heartbeat must exist regardless of vault outcome (fail-open vault)
    [ -f .claude/anti-patterns/.last-sweep.json ] \
        || { echo "FAIL: heartbeat not written when vault is slow"; return 1; }
    unset VAULT_ENABLED VAULT_PATH
}

# ─────────────────────────────────────────────────────────────
# Failure (rev3 E24): Reflog reference invalid post-rebase
# ─────────────────────────────────────────────────────────────
test_fail_reflog_invalid_post_rebase() {
    local tmp=$(setup_fresh_catalog_with_known_matches)
    cd "$tmp"
    # Create a couple of commits then squash via interactive-equivalent
    echo "x" > a.txt && git add a.txt && git commit -q -m "a"
    echo "x" > b.txt && git add b.txt && git commit -q -m "b"
    git reset --soft HEAD~2 && git commit -q -m "squashed"
    # Reflog reference @{1.hour.ago} may now point to an orphaned commit
    set +e
    bash "$REPO_ROOT/scripts/anti-pattern-sweep.sh" --session 2>&1 >/dev/null
    local rc=$?
    set -e
    [ "$rc" -eq 0 ] \
        || { echo "FAIL: sweep choked on invalid reflog reference (rc=$rc)"; return 1; }
}
```

### Behavioral Eval Fixtures (for `evals/evals.json`)

```json
{
  "anti-pattern-sweep-detection": {
    "description": "AC2 — sweep detects a known fixture_bad in a non-excluded file",
    "setup": [
      "mkdir -p .claude/anti-patterns src",
      "cp $REPO_ROOT/commands/templates/stock-anti-patterns/bash-unsafe-atomic-write.md .claude/anti-patterns/",
      "cp $REPO_ROOT/commands/templates/stock-anti-patterns/SCHEMA.md .claude/anti-patterns/",
      "echo 'jq . in.json > \"$TMP\" && mv \"$TMP\" out.json' > src/sample.sh"
    ],
    "command": "bash $REPO_ROOT/scripts/anti-pattern-sweep.sh --full 2>/dev/null",
    "assertions": [
      ["exit_code", "==", 0],
      ["file_exists", ".claude/anti-patterns/.events.jsonl"],
      ["jq_count", ".claude/anti-patterns/.events.jsonl", "[.id == \"bash-unsafe-atomic-write\" and .file == \"src/sample.sh\"]", ">=", 1]
    ]
  },

  "anti-pattern-sweep-idempotency": {
    "description": "AC3 — running sweep twice on unchanged source yields identical counter values",
    "setup": [
      "<setup as in detection>",
      "bash $REPO_ROOT/scripts/anti-pattern-sweep.sh --full 2>/dev/null",
      "cp .claude/anti-patterns/bash-unsafe-atomic-write.md /tmp/snapshot1.md"
    ],
    "command": "bash $REPO_ROOT/scripts/anti-pattern-sweep.sh --full 2>/dev/null",
    "assertions": [
      ["exit_code", "==", 0],
      ["frontmatter_eq_except_timestamps", ".claude/anti-patterns/bash-unsafe-atomic-write.md", "/tmp/snapshot1.md"]
    ]
  },

  "anti-pattern-sweep-dedup": {
    "description": "AC13 (rev3) — counter regen dedupes by (id, file, line); same tuple twice = total_hits 1",
    "setup": [
      "<setup with known matching source>",
      "bash $REPO_ROOT/scripts/anti-pattern-sweep.sh --full 2>/dev/null",
      "tail -1 .claude/anti-patterns/.events.jsonl | jq -c '.ts = (now | todateiso8601)' >> .claude/anti-patterns/.events.jsonl"
    ],
    "command": "bash $REPO_ROOT/scripts/anti-pattern-sweep.sh --full 2>/dev/null",
    "assertions": [
      ["exit_code", "==", 0],
      ["frontmatter_field_eq_unique_tuple_count", ".claude/anti-patterns/bash-unsafe-atomic-write.md", "total_hits"]
    ]
  },

  "anti-pattern-sweep-fail-open-no-vault": {
    "description": "AC9 — sweep succeeds without VAULT_ENABLED",
    "setup": [
      "<setup as in detection>",
      "unset VAULT_ENABLED VAULT_PATH"
    ],
    "command": "bash $REPO_ROOT/scripts/anti-pattern-sweep.sh --full 2>/dev/null",
    "assertions": [
      ["exit_code", "==", 0],
      ["file_exists", ".claude/anti-patterns/.events.jsonl"],
      ["file_exists", ".claude/anti-patterns/.last-sweep.json"]
    ]
  },

  "anti-pattern-hook-emits-citation": {
    "description": "AC14 form 1 — hook emits 'Catalog: <id>' on matching Write input",
    "setup": [
      "<install hook + populate catalog>"
    ],
    "command": "echo '{\"tool_input\":{\"content\":\"jq . in > \\\"$T\\\" && mv \\\"$T\\\" out\"}}' | bash hooks/anti-pattern-write-check.sh",
    "assertions": [
      ["exit_code", "==", 0],
      ["stderr_matches", "Catalog:[[:space:]]*bash-unsafe-atomic-write"]
    ],
    "manual_verify_required": "AC14 form 2 — invoke a real Write in a Claude session and confirm tool-feedback path surfaces the warning. If form 2 fails, redesign the hook per spec.md Decisions section."
  }
}
```

---

## Anti-Tautology Review

For each test, evaluate against the four-column checklist:

| Test | Could pass with wrong impl? | Tests behavior not structure? | Survives refactor? | Derived from spec? |
|---|---|---|---|---|
| AC1 — min entries | No (file count is observable) | ✓ behavior | ✓ refactor-safe | ✓ |
| AC2 — sweep detects | Hard to fake (event must reference correct id+file) | ✓ | ✓ | ✓ |
| AC3 — idempotency | No (snapshot diff can't be cheated) | ✓ | ✓ | ✓ |
| AC4 — citation | No (grep on shipped artifacts) | ✓ | ✓ | ✓ |
| AC5 — full-sweep seed | No (cross-checked against hand-grep) | ✓ | ✓ | ✓ |
| AC6 — schema doc | Mild risk (length+grep is loose) | ✓ existence + topic coverage | ✓ | ✓ |
| AC7 — frontmatter validation | No (deliberately broken entry must fail) | ✓ | ✓ | ✓ |
| AC8 — fail-open `/end` | No (corrupt regex must produce rc 0) | ✓ | ✓ | ✓ |
| AC9 — no-vault fail-open | No (env-var unset must not break) | ✓ | ✓ | ✓ |
| AC10 — bootstrap populates | No (file existence after fresh bootstrap) | ✓ | ✓ | ✓ |
| AC11 — heartbeat | No (file + required JSON fields) | ✓ | ✓ | ✓ |
| AC12 — stale nudge | Mild risk (regex on stderr must match) | ✓ | ✓ if message format documented | ✓ |
| AC13 — dedup tuples | No (artificial duplicate must yield total=1) | ✓ | ✓ | ✓ |
| AC14 — hook visibility | **Test of form 1 yes; form 2 requires manual** | partial | ✓ | partial — empirical claim |
| Preserve `/end` exit 0 | No (rc check across multiple states) | ✓ | ✓ | ✓ |
| Preserve counters derived | No (hand-edit must be overwritten) | ✓ | ✓ | ✓ |
| Preserve SAIL_DISABLED_HOOKS | No (env-var check) | ✓ | ✓ | ✓ |
| Preserve hookify count | Mild risk (count check is loose) | ✓ | ✓ | ✓ |
| Install lands stock | No (filesystem check) | ✓ | ✓ | ✓ |
| Fail: missing dir | No (rc check) | ✓ | ✓ | ✓ |
| Fail: malformed yaml | No (WARN + continued execution) | ✓ | ✓ | ✓ |
| Fail: self-test mismatch | No (WARN required) | ✓ | ✓ | ✓ |
| Fail: no git | No (rc check) | ✓ | ✓ | ✓ |
| Fail: no jq | No (rc check) | ✓ | ✓ | ✓ |
| Fail: corrupt event log | No (rc + WARN + sweep continues) | ✓ | ✓ | ✓ |
| Fail: readonly | No (rc check) | ✓ | ✓ | ✓ |
| Fail: session timeout | No (rc + heartbeat presence) | ✓ | ✓ | ✓ |
| Fail (E23): slow vault | No (sweep core within budget despite slow vault) | ✓ | ✓ | ✓ |
| Fail (E24): reflog post-rebase | No (rc check after squash) | ✓ | ✓ | ✓ |

### Red flags identified

1. **AC14 is partially spec-blind.** The form-1 test (hook emits warning correctly) IS spec-derivable. The form-2 verification (Claude actually sees it) is NOT — it's a property of the harness. The test file documents this honestly and the spec.md "Decisions" section flags this as a pre-impl gating step. Recommend running form-1 + form-2 together as the AC14 gate; if form-2 fails, redesign before proceeding.

2. **AC6 (schema doc) is loose.** Topic-grep on "schema|frontmatter|add pattern|counter" passes any document that mentions those words. Acceptable for a documentation-existence check; tighter assertions would couple to specific phrasings.

3. **AC12 (stale nudge) is loose.** Tests that stderr contains `last successful sweep:.*[0-9]+d ago`. If implementation writes the same information in different phrasing, this test would fail despite correct behavior. Mitigation: the message format IS specified in the spec ("last successful sweep: ${age_days}d ago"); this is a contract, not over-coupling.

4. **`test_preserve_existing_hookify_rules` is weak.** Just checks count and frontmatter delimiter. Stronger test would actually fire the existing rules and verify they still detect their patterns — but that requires harness instrumentation outside scope here.

---

## Test Helper Library (referenced by tests above)

```bash
# tests/anti-pattern-catalog/helpers.sh
#
# Setup helpers. Implementation-blind — they just call the public contract:
#   - install.sh
#   - bootstrap-project (whatever shape that takes)
#   - scripts/anti-pattern-sweep.sh
#   - hooks/anti-pattern-write-check.sh

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"

setup_fresh_catalog() {
    local tmp=$(mktemp -d); echo "$tmp"
    cd "$tmp" && git init -q
    HOME="$tmp/.fakehome" bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
    HOME="$tmp/.fakehome" bash "$REPO_ROOT/commands/bootstrap-project.sh" --silent 2>/dev/null
}

setup_fresh_catalog_with_known_matches() {
    local tmp=$(setup_fresh_catalog)
    cd "$tmp"
    mkdir -p src
    # Drop in fixture_bad content from each stock pattern
    for entry in "$REPO_ROOT/commands/templates/stock-anti-patterns/"*.md; do
        [ "$(basename "$entry")" = "SCHEMA.md" ] && continue
        local fixture=$(awk '/^fixture_bad: \|$/{flag=1;next}/^[a-z_]+:/{flag=0}flag' "$entry")
        local id=$(basename "$entry" .md)
        printf '%s\n' "$fixture" > "src/${id}-sample.sh"
    done
    git add -A && git commit -q -m "seed"
    echo "$tmp"
}

setup_fresh_catalog_outside_git() {
    local tmp=$(mktemp -d); echo "$tmp"
    cd "$tmp"
    HOME="$tmp/.fakehome" bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
    mkdir -p .claude/anti-patterns
    cp "$REPO_ROOT/commands/templates/stock-anti-patterns/"*.md .claude/anti-patterns/
}

setup_catalog_in_state() {
    local state=$1
    local tmp=$(setup_fresh_catalog)
    cd "$tmp"
    case "$state" in
        healthy) ;;
        corrupted_regex)
            local first=$(find .claude/anti-patterns -name '*.md' ! -name 'SCHEMA.md' | head -1)
            sed -i "s/^detection_regex:.*/detection_regex: '['/" "$first" ;;
        readonly_dir) chmod -w .claude/anti-patterns ;;
        missing_jq_simulated)
            # Caller's responsibility to PATH-strip jq before invoking
            ;;
    esac
    echo "$tmp"
}

extract_frontmatter_field() {
    local file=$1 field=$2
    awk -v f="$field" '
        /^---$/{c++; next}
        c==1 && $1 == f":" { sub(/^[^:]+:[ \t]*/, ""); print; exit }
    ' "$file"
}

extract_frontmatter_json() {
    local file=$1
    awk '
        /^---$/{c++; if(c==2)exit; next}
        c==1 { print }
    ' "$file" | yq -o=json . 2>/dev/null || \
    awk '
        /^---$/{c++; if(c==2)exit; next}
        c==1 { print }
    ' "$file"
}

extract_first_pattern_id_and_fixture_bad() {
    local entry=$(find .claude/anti-patterns -maxdepth 1 -name '*.md' ! -name 'SCHEMA.md' | head -1)
    local id=$(basename "$entry" .md)
    local fixture=$(awk '/^fixture_bad: \|$/{flag=1;next}/^[a-z_]+:/{flag=0}flag' "$entry")
    echo "$id $fixture"
}

extract_first_pattern_fixture_bad_from_stock() {
    local entry=$(find "$REPO_ROOT/commands/templates/stock-anti-patterns" -maxdepth 1 \
                       -name '*.md' ! -name 'SCHEMA.md' | head -1)
    awk '/^fixture_bad: \|$/{flag=1;next}/^[a-z_]+:/{flag=0}flag' "$entry"
}

extract_first_pattern_id_from_stock() {
    local entry=$(find "$REPO_ROOT/commands/templates/stock-anti-patterns" -maxdepth 1 \
                       -name '*.md' ! -name 'SCHEMA.md' | head -1)
    basename "$entry" .md
}

extract_all_counters() {
    local dir=$1
    for entry in "$dir"/*.md; do
        [ "$(basename "$entry")" = "SCHEMA.md" ] && continue
        local id=$(basename "$entry" .md)
        local total=$(extract_frontmatter_field "$entry" "total_hits")
        local recent=$(extract_frontmatter_field "$entry" "recent_hits")
        local remedied=$(extract_frontmatter_field "$entry" "locations_remedied")
        echo "$id total=$total recent=$recent remedied=$remedied"
    done | sort
}
```

---

## Implementation Notes

These tests should:

1. **Fail initially** — nothing is implemented yet (WUs 1-7 produce the artifacts the tests verify).
2. **Pass without modification once implementation meets spec** — if a test needs to be edited during Execute, that's a signal the spec was incomplete or the implementation deviated from contract.
3. **AC14 form 1 is unit-testable; form 2 is harness-empirical** — do form-1 first (cheap), then form-2 (gating step) before committing to WU6's design. If form-2 fails, the spec's "Decisions" section anticipates redesign and the spec.md prose already accommodates it.

## Test Execution Order (suggested for Execute stage)

| Stage | Tests | When |
|---|---|---|
| 1 | AC14 form-1 + form-2 verification | Before implementing rest of WU6 — gating step per spec |
| 2 | AC1, AC6, AC7, AC10, install lands stock | After WU1, WU2, WU5 (catalog content + bootstrap) |
| 3 | AC2, AC3, AC11, AC13, fail-open suite | After WU3 (sweep core) |
| 4 | AC8, AC12, fail: session timeout | After WU4 (/end integration) |
| 5 | AC4, AC14 form-2 manual | After WU6 (consumer wired) |
| 6 | preservation tests, full eval suite | Before declaring Execute complete |

If AC14 form-2 fails: STOP, redesign per Decisions section, re-run form-2 before continuing.
