# Spec: Anti-Pattern Catalog

> **Revision 4** (2026-04-30): Mechanism correctness (no architectural regression). AC14
> empirical pre-impl verification (see `ac14-verification.md`) confirmed DA-1: `exit 0 + stderr`
> from PreToolUse hooks does NOT propagate to Claude — only to the user terminal. Hook output
> mechanism in WU6 changes from "exit 0 + stderr `Catalog: <id>`" to "exit 0 + stdout JSON
> with `hookSpecificOutput.additionalContext`" per Claude Code's documented contract. WU6
> architecture (PreToolUse hook citing catalog IDs as first consumer) is unchanged; only the
> output channel shifts.
>
> **Revision 3** (2026-04-30): Post-review polish (no regression). Adds a Decisions section
> documenting why-regex/why-warn-only/why-heartbeat (PA-2, DA-1, S-1); adds optional
> `references` field to frontmatter (PA-3); adds event dedupe by (id, file, line) tuple to
> sweep algorithm (E20); moves vault export outside the 5s timeout (E23); adds vault-mirror
> contract header (DA-3); expands Known Limitations with E21, E22, E24; adds AC13 (dedupe)
> and AC14 (DA-1 hook visibility verification). See spec.diff.md for full rev2→rev3 delta.
>
> **Revision 2** (2026-04-30): Addresses adversarial findings F1 (hookify→shell hook pivot),
> F2 (sweep exclude paths), F3 (drop silent-error-suppression for v1, swap in regex-friendly
> third pattern), F4 (events log cap), F5 (safe-swap fallback), F7 (file-level copy-if-not-exists).
> See spec.diff.md for full revision delta.

## Architecture

A markdown-based catalog of language-specific anti-patterns, with derived counters refreshed by a session-end sweep. Project-local source of truth; vault export for cross-project aggregation.

```
PROJECT (source of truth)               VAULT (cross-project mirror)
──────────────────────────              ────────────────────────────
.claude/anti-patterns/         ──────►  Engineering/Anti-Patterns/
  ├── SCHEMA.md                         ├── [project]-bash-unsafe-atomic-write.md
  ├── bash-unsafe-atomic-write.md       ├── [project]-bash-silent-error-suppression.md
  ├── bash-silent-error-suppression.md  └── ...
  └── bash-missing-fail-fast.md
                                                    ▲
        ▲                                           │
        │                                           │
        │                                  vault export on each
        │                                  successful sweep (fail-open
        │                                  if vault unavailable)
        │
   sweep reads + writes
   (counter regeneration is
   idempotent — derived from
   detection events, not maintained)
```

Two sweep entry points:

- **Session sweep** — invoked by `/end`, scoped to `git diff --name-only` files for the session. Cheap, automatic, runs only if `.claude/anti-patterns/` exists.
- **Full sweep** — invoked manually as `bash scripts/anti-pattern-sweep.sh --full`. Scoped to `git ls-files` for the whole project. Used for initial catalog seeding and periodic reconciliation.

## Decisions

Documented design choices with the reasoning preserved for future-us. These resolve the
"why didn't you just use X?" questions that come up otherwise.

### Why regex over AST (PA-2)

The catalog uses POSIX ERE regex for `detection_regex`. AST-based tools (semgrep, ast-grep)
provide stronger detection: multi-line patterns, dataflow analysis, taint tracking. We don't
adopt them because **claude-sail's distribution constraint is bash + curl only** — semgrep
needs Python, ast-grep needs a Rust binary. Adopting either would change the toolkit's
distribution model.

Regex is therefore the strongest detection primitive available within the constraint, with
accepted coarseness on multi-line patterns (cf. F3 dropping `bash-silent-error-suppression`
from v1). A future `detection_kind: regex|semgrep|ast-grep` schema extension could route to
better engines on systems that have them installed, while preserving the bookkeeping layer
that's the actual product. Out of scope for v1; mentioned here so a future rev knows the
intended evolution path.

### Why warn-with-visibility via additionalContext (DA-1, rev4 verified)

The first consumer (`hooks/anti-pattern-write-check.sh`) is a PreToolUse hook that allows
the tool call to proceed but surfaces a `Catalog: <id>` warning to Claude in tool feedback.
The mechanism is **`exit 0` + stdout JSON** with `hookSpecificOutput.additionalContext`,
NOT stderr.

**Why not stderr:** AC14 empirical verification (see `ac14-verification.md`) confirmed that
`exit 0` PreToolUse hook stderr propagates to the user's terminal but NOT to Claude. A
warn-only-via-stderr consumer would be wired-but-silent — AC4 mechanically passes, but the
catalog produces no Claude-visible signal. This is exactly the failure mode DA-1 flagged
during /review.

**Why not exit 2:** `exit 2` does propagate stderr to Claude, but it also blocks the tool
call. That's the right primitive for hard violations (`protect-claude-md.sh` uses it) but
wrong for warn-only patterns where the user/Claude should see the citation and decide
whether to proceed.

**The right primitive — additionalContext:** Claude Code's documented PreToolUse hook output
schema includes:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "additionalContext": "anti-pattern detected\n  Catalog: bash-unsafe-atomic-write\n  ..."
  }
}
```

The hook outputs this JSON to stdout, exits 0. Claude Code:
1. Allows the tool call (`permissionDecision: "allow"`)
2. Adds `additionalContext` text to Claude's context alongside the tool result
3. The user sees the tool succeed; Claude sees the warning text; both are informed

**Multi-pattern citations:** if multiple patterns match (e.g., a Write contains both
`bash-unsafe-atomic-write` and `bash-rm-rf-with-variable`), the hook can emit multiple
`hookSpecificOutput` entries — Claude Code accumulates all `additionalContext` values per
the docs.

**Verification status:** in-session empirical test was inconclusive (settings.local.json
hooks are session-cached and don't reload mid-session — see `ac14-verification.md` Path C).
Fresh-session manual verification is the final gate before WU6 marks complete.

### Why heartbeat + nudge ceremony for v1 (S-1)

Stage 5 (Pre-Mortem) found that fail-open observability has a known decay pattern in
claude-sail's history — silent observability *is* broken observability. The heartbeat
(`.last-sweep.json`) + stale-sweep nudge in `/end` are not speculative ceremony; they
prevent the specific failure mode that's burned us before. The cost is real (extra spec
sections, GNU-vs-BSD `date -d` branching, two new ACs) but the prevention has empirical
basis.

If this turns out to be over-engineered after 60 days of operation: the heartbeat write
and `/end` nudge are both opt-out by file deletion (`rm .last-sweep.json` disables the
nudge silently — fail-open). Cheap to walk back; expensive to bolt on after a silent-decay
incident.

### Why ship `bash-rm-rf-with-variable` despite no current instances (S-3)

The pattern is included as a v1 entry that exercises the `recent_hits=0` path. This is a
deliberate test that the recency signal **honestly reports zero** rather than fabricating
hits. Alternative considered: cover that path via a synthetic `evals/evals.json` fixture
and ship only the 2 incident-derived patterns. Rejected because the eval fixture wouldn't
exercise the *full* sweep path on a real catalog entry — it would test the algorithm on
fake data. Including the pattern as a real catalog entry tests the algorithm on the same
codepath users will hit.

Trade-off: the catalog has one entry that's "documented best practice" rather than
"incident-derived." Documented as such; reviewers should know the difference.

## Catalog Entry Schema

Each pattern is a markdown file at `.claude/anti-patterns/<id>.md` with YAML frontmatter:

```yaml
---
id: bash-unsafe-atomic-write       # required, kebab-case, matches filename
language: bash                      # required: bash | python | js | ...
severity: high                      # required: critical | high | medium | low
status: active                      # required: active | retired
detection_regex: '> *"\$[A-Z_]+"? *&& *mv'  # required, ERE, anchored as needed
fixture_good: |                     # required, multi-line example that should NOT match
  jq '.' input > "$TMP"
  jq -e . "$TMP" >/dev/null && mv "$TMP" "$FILE"
fixture_bad: |                      # required, multi-line example that SHOULD match
  jq '.' input > "$TMP" && mv "$TMP" "$FILE"
first_seen: 2026-04-30              # required, ISO date — when the pattern was first cataloged
last_seen: 2026-04-30               # derived by sweep — most recent detection
total_hits: 0                       # derived by sweep — count of detection events ever
recent_hits: 0                      # derived by sweep — count within recent_window_days
recent_window_days: 60              # required, default 60 — definition of "recent"
locations_remedied: 0               # derived by sweep — diff of (prior detections - current detections)
related_hookify: []                 # optional, list of hookify rule names that cite this id
references: []                      # optional, links to incidents/PRs/CVEs/findings
                                    #   format: free-form strings or URLs
                                    #   intent: forward-compat with semgrep's metadata.references
                                    #   example: ["[[2026-04-30-jq-tmp-mv-pattern]]", "PR #42"]
---

# [Pattern human title]

[Body: full description. What it looks like, why it's dangerous, how to fix.
Stays free-form prose — Obsidian renders it, jq doesn't read it.]

## Examples

### Bad
```bash
# concrete unsafe instance — fill in with the real form
```

### Good
```bash
# concrete validated instance — fill in with the real form
```

## Source
- First seen: [link to incident or session]
- Related shell hook: [name, if any]
```

> **Note:** the bracketed/commented placeholders above are the *body template* —
> what an empty new entry looks like before being filled in. Real entries replace
> these with concrete code blocks (see WU2 starter entries).

**Schema invariants:**
- `id` field MUST equal the filename (without `.md` extension)
- Required fields are validated by `test.sh` Category 4 (frontmatter check) — entries missing required fields fail the test suite
- `detection_regex` is **POSIX ERE** (used by `grep -E`), so the same regex works on Linux, macOS, and BSD
- Counter fields (`total_hits`, `recent_hits`, `locations_remedied`, `last_seen`) are **derived** — written only by sweep, never by hand. Hand-edits to these fields are overwritten on the next sweep.

## Sweep Logic

`scripts/anti-pattern-sweep.sh` — single script, two modes via `--session` (default) or `--full` flag.

### Inputs

| Mode | File set | Source |
|------|----------|--------|
| session | files modified this session | `git diff --name-only HEAD` (uncommitted) + `git diff --name-only @{1.hour.ago}` (recent commits, scoped to session start) |
| full | all tracked files | `git ls-files` |

If not in a git repo: session mode falls back to "files modified in last 24h" via `find -mtime -1`; full mode falls back to glob over common source extensions.

### Detection event log

The catalog directory has an append-only log: `.claude/anti-patterns/.events.jsonl`. Each detection event:

```json
{"ts":"2026-04-30T20:15:00Z","id":"bash-unsafe-atomic-write","file":"hooks/epistemic-preflight.sh","line":148,"sweep":"session"}
```

This log is the **single source of truth** for counter derivation. Frontmatter counters are recomputed from it — the log is append-only and cannot drift.

### Sweep algorithm

```
1. Read all entries in .claude/anti-patterns/*.md
   For each entry: parse frontmatter, extract { id, detection_regex, fixture_good, fixture_bad }

2. Self-test each pattern (catches catalog bit-rot):
   For each entry:
     - grep -E "$detection_regex" against fixture_bad ⇒ MUST match (else WARN, skip pattern)
     - grep -E "$detection_regex" against fixture_good ⇒ MUST NOT match (else WARN, skip pattern)
   This is the catalog's own self-validation; broken regexes are skipped, not silently miscount.

3. Build the file set per mode (session vs full), then EXCLUDE catalog-internal paths.

   EXCLUDE_PATHS (apply via grep -v after file enumeration):
     .claude/anti-patterns/         (the catalog itself — fixtures would self-match)
     .claude/plans/                 (planning docs include patterns as examples)
     commands/templates/stock-anti-patterns/  (toolkit-shipped starter templates)

   Vault mirror exclusion: when scanning a project that has Engineering/Anti-Patterns/
   under VAULT_PATH, that directory is also excluded. (Vault is outside git tracking
   in most setups but check defensively.)

   Rationale: F2 from rev1 review — every catalog entry's fixture_bad code block matches
   its own detection_regex by design. Without exclusion, counters self-poison permanently.

4. For each (entry, file) pair:
   Run grep -nE "$detection_regex" against the file.
   For each match: append a detection event to .events.jsonl with the entry id, file, line, and sweep mode.

5. Recompute counters from .events.jsonl:
   For each entry id:

   5a. Dedupe events by (id, file, line) tuple — keep only the most recent timestamp per
       tuple (rev3 — addresses E20). Without dedup, a manual `--full` sweep followed by a
       `/end` session sweep within the same window double-attributes any unchanged match
       (same id, file, line gets two events seconds apart). Dedup is on read (counter
       regen) — the events log itself stays append-only for forensic continuity.

   5b. Compute counters from the deduped event set:
     - total_hits = count of unique (id, file, line) tuples with this id
     - recent_hits = count where ts >= now - recent_window_days
     - last_seen = max(ts) where id matches, or first_seen if no events
     - locations_remedied = (count of unique file:line tuples in events older than recent_window_days
                              that no longer match in the most recent sweep)

5a. Events log cap (added rev2, addresses F4):
    After counter regeneration, check the line count of .events.jsonl.
    If > 10000 lines:
      - Move the OLDEST 5000 lines to .events.archive.jsonl (append-only archive)
      - Truncate .events.jsonl to the most recent 5000 lines
      - Log: "Events log compacted: 5000 events archived"
    Counter recomputation reads .events.jsonl (active window) only.
    The archive exists for forensic queries, not routine reads.

6. Atomically rewrite each entry's frontmatter, with helper-or-fallback path
   (added rev2, addresses F5):

   if [ -f scripts/epistemic-safe-write.sh ] || [ -f ~/.claude/scripts/epistemic-safe-write.sh ]:
     source the helper, use epistemic_safe_swap
   else:
     # Inline fallback: validate non-empty + valid markdown frontmatter before swap.
     # If validation fails: keep original, remove tmp, log warning.

   Body content is preserved verbatim; only frontmatter counter fields are touched.

7. If vault available (vault-config.sh sourced, VAULT_ENABLED=1):
   Vault export runs **outside the timeout-wrapped sweep core** (rev3 — addresses E23).
   Network-mounted vault paths (corp Dropbox, iCloud, slow SMB) can take 100+ms per write,
   and per-pattern overhead inside a 5s session-mode budget can blow the timeout before
   the heartbeat is written — making vault latency look like sweep failure. The fix:
   the timeout wrapper covers steps 1-6 + 8-9 (the project-local critical path); step 7
   runs unwrapped after the heartbeat is committed.

   For each updated entry, write a mirror to:
     $VAULT_PATH/Engineering/Anti-Patterns/<project>-<id>.md
   Mirror has identical body + frontmatter PLUS:
     project: <basename of git toplevel>
     mirror_of: .claude/anti-patterns/<id>.md

   Mirror body is prefixed with a contract header (rev3 — addresses DA-3) so users
   editing in Obsidian see the contract before they lose work to the next sweep:

     <!-- AUTO-GENERATED MIRROR — edits here are overwritten by the next project sweep.
          Edit the project-local catalog at .claude/anti-patterns/<id>.md instead. -->

   Vault writes use validate-before-swap. If vault write fails: log warning, do not fail the sweep.

8. Print summary to stderr:
   "Anti-pattern sweep complete: scanned N files across M patterns.
    K new detections recorded. Recent: <id>: <recent_hits> ..."

9. Write heartbeat (rev2 — added per pre-mortem F-PM-1):
   .claude/anti-patterns/.last-sweep.json with:
   { "timestamp": "ISO-8601", "patterns_scanned": M, "files_scanned": N,
     "events_appended": K, "duration_ms": elapsed, "mode": "session|full" }
   Atomic write via the same safe-swap helper-or-fallback path. The heartbeat
   is the "is bookkeeping alive?" signal — without it, sweep failures are
   invisible (silent observability is broken observability).
```

### Performance budget

- Session sweep: 5 second hard cutoff (timeout wrapper)
- Full sweep: no cutoff (run-to-completion)
- If session sweep times out: log warning, partial counters written from completed work, sweep is non-blocking for `/end`

### Fail-open semantics

The sweep is **never** a blocker:
- Missing catalog directory → exit 0 silently (project hasn't opted in)
- Malformed pattern frontmatter → log WARN, skip that pattern, continue
- Self-test failure for a pattern → log WARN, skip that pattern, continue
- `git` unavailable → fall back to `find` heuristics
- `jq` unavailable → exit 0 with one-line warning (sweep needs jq)
- Vault unavailable → skip vault export silently

## /end Integration

`/end` skill gains a sweep invocation block AND a stale-sweep heartbeat nudge (the latter
added rev2 per pre-mortem F-PM-2):

```bash
# Anti-pattern sweep (opt-in by directory presence)
if [ -d .claude/anti-patterns ]; then
    HEARTBEAT=".claude/anti-patterns/.last-sweep.json"

    # Stale-sweep nudge: surface if heartbeat missing or > 7 days old
    if [ ! -f "$HEARTBEAT" ]; then
        echo "[anti-pattern catalog] no successful sweep recorded — first run pending." >&2
    else
        last_ts=$(jq -r '.timestamp' "$HEARTBEAT" 2>/dev/null)
        if [ -n "$last_ts" ]; then
            last_epoch=$(date -d "$last_ts" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_ts" +%s 2>/dev/null)
            now_epoch=$(date -u +%s)
            age_days=$(( (now_epoch - last_epoch) / 86400 ))
            if [ "$age_days" -gt 7 ]; then
                echo "[anti-pattern catalog] last successful sweep: ${age_days}d ago. Investigate sweep health." >&2
            fi
        fi
    fi

    # Run sweep
    SWEEP_SCRIPT="$(git rev-parse --show-toplevel 2>/dev/null)/scripts/anti-pattern-sweep.sh"
    [ -f "$SWEEP_SCRIPT" ] || SWEEP_SCRIPT="${HOME}/.claude/scripts/anti-pattern-sweep.sh"
    if [ -f "$SWEEP_SCRIPT" ]; then
        timeout 5 bash "$SWEEP_SCRIPT" --session 2>&1 | tail -10 || true
    fi
fi
```

Fail-open, opt-in by directory presence. Heartbeat check uses `jq` (already required for sweep);
falls through gracefully if jq unavailable. Date math uses GNU `date -d` with BSD fallback for
macOS — same defensive pattern used elsewhere in the toolkit.

## Stock Templates + Bootstrap

`commands/templates/stock-anti-patterns/` ships with toolkit:
- `SCHEMA.md` — copy of the schema doc above
- Three starter patterns (`bash-unsafe-atomic-write.md`, `bash-silent-error-suppression.md`, `bash-missing-fail-fast.md`)

`/bootstrap-project` gains a step: copy `stock-anti-patterns/` → `.claude/anti-patterns/` if the target directory doesn't exist (copy-if-not-exists, matching stock-pipelines semantics).

`install.sh` is updated to copy `commands/templates/stock-anti-patterns/` to `~/.claude/commands/templates/stock-anti-patterns/`.

## Shell Hook Integration (revised rev2)

> **Pivot from rev1:** The original spec proposed a hookify rule with `event: write`. Verified
> that all existing hookify rules in this toolkit use `event: bash` only — the rule would never
> fire. Pivoting to a real PreToolUse shell hook gives us deterministic enforcement on Write/Edit.

A new shell hook `hooks/anti-pattern-write-check.sh` runs as PreToolUse on `Write` and `Edit` tools.
It scans the proposed file content against catalog regexes and emits warnings (exit 0 with stderr)
when a pattern matches. Fail-open: missing catalog directory, jq, or grep means silent exit 0.

**Wiring in `settings-example.json`:**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/hooks/anti-pattern-write-check.sh"
          }
        ]
      }
    ]
  }
}
```

**Hook script contract (rev4 — additionalContext mechanism):**

```bash
#!/usr/bin/env bash
# anti-pattern-write-check.sh — PreToolUse on Write/Edit
#
# Reads the tool-call JSON from STDIN (matches the convention used by
# secret-scanner.sh, freeze-guard.sh, etc.). Extracts the candidate file
# content from .tool_input.content (Write) OR .tool_input.new_string (Edit),
# scans against each catalog pattern's detection_regex.
#
# On match: outputs JSON to STDOUT (NOT stderr) with permissionDecision allow
# + additionalContext "Catalog: <id>" so Claude sees the warning while the
# tool call still proceeds. Exit 0.
#
# Why this output mechanism (rev4): empirically verified that `exit 0 + stderr`
# does NOT propagate to Claude — only to the user terminal (see ac14-verification.md).
# The additionalContext field is the documented Claude Code primitive for
# warn-with-visibility on PreToolUse.

set +e

HOOK_NAME="anti-pattern-write-check"
[[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]] && exit 0

CATALOG_DIR="$(git rev-parse --show-toplevel 2>/dev/null)/.claude/anti-patterns"
[ -d "$CATALOG_DIR" ] || exit 0   # opt-in by directory presence

input=$(cat)
content=$(echo "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)
[ -z "$content" ] && exit 0   # nothing to scan

file_path=$(echo "$input" | jq -r '.tool_input.file_path // "<unknown>"' 2>/dev/null)

# Accumulate matches across all catalog entries. Multiple patterns can match
# the same content; we surface all of them.
matches=""
shopt -s nullglob
for entry in "$CATALOG_DIR"/*.md; do
    [ "$(basename "$entry")" = "SCHEMA.md" ] && continue
    id=$(basename "$entry" .md)
    regex=$(awk '/^---$/{c++; if(c>=2)exit; next} c==1 && /^detection_regex:/{
        sub(/^detection_regex:[[:space:]]*/, "")
        gsub(/^['\''"]|['\''"]$/, "")
        print; exit
    }' "$entry")
    [ -z "$regex" ] && continue
    if echo "$content" | grep -qE "$regex" 2>/dev/null; then
        matches="${matches}anti-pattern detected\n  Catalog: $id\n  File: $file_path\n\n"
    fi
done

# If any matches, emit a single JSON object with concatenated additionalContext.
# Multi-hook accumulation is also supported by Claude Code (per docs), but
# concatenating in one hook output is simpler and makes the citation block contiguous.
if [ -n "$matches" ]; then
    jq -nc --arg ctx "$matches" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "allow",
            additionalContext: $ctx
        }
    }'
fi

exit 0
```

The stdin/jq pattern matches existing hooks (`hooks/secret-scanner.sh:23`).
For Write tool the content field is `.tool_input.content`; for Edit it's
`.tool_input.new_string`. The `// empty` fallback chain handles both.

**Output channel (rev4):** stdout JSON, NOT stderr. The `hookSpecificOutput` schema is
canonical Claude Code; `permissionDecision: "allow"` lets the tool call proceed;
`additionalContext` is the field that surfaces text to Claude alongside the tool result.

**Catalog reference convention:** the additionalContext text MUST include the line
`Catalog: <id>` so Claude sees the entry name in its feedback. The convention is documented
in `.claude/anti-patterns/SCHEMA.md`. The sweep can optionally grep hook output / hookify rule
bodies for `Catalog:` references to derive bidirectional links — deferred to v2.

**Why this approach over alternatives:**
- Not stderr: rev3 spec assumed stderr propagates; AC14 empirical verification proved it doesn't.
- Not `exit 2`: that does propagate stderr to Claude but blocks the tool call — wrong primitive
  for warn-only patterns.
- Not a marker file + separate surfacing mechanism: loose timing, no guarantee Claude reads it.

**Why a shell hook, not hookify:** F1 (rev2) — hookify rules in this toolkit fire on
`event: bash` only. Write/Edit content interception requires PreToolUse hooks. Shell hooks
are deterministic, already follow toolkit fail-open discipline, and now have a documented
warn-with-visibility primitive (additionalContext) that makes them strictly better than the
hookify rule would have been.

## Documentation

`.claude/anti-patterns/SCHEMA.md` (one-page):
- Frontmatter schema reference
- How to add a new pattern (3-step: copy template, fill fields, run sweep to validate)
- Counter semantics (derived, not maintained — DO NOT hand-edit counter fields)
- Sweep modes and when each runs
- Hookify integration convention

Add a `## Anti-Pattern Catalog` section to project root `README.md` in claude-sail with a link to the schema doc.

## Three Starter Entries (rev2: F3 swap)

> **Rev2 change:** `bash-silent-error-suppression` is dropped from v1. Its detection requires
> multi-line context-aware analysis (set +e followed by unchecked exit codes within N lines),
> which `grep -E` doesn't support. Schema extension `detection_kind: regex|awk|external-script`
> is deferred to v2. Replaced with `bash-rm-rf-with-variable` — single-line regex, distinct
> shape, genuinely dangerous, exercises the recent_hits=0 path on this codebase.

### 1. `bash-unsafe-atomic-write`

Pattern: `> *"?\$[A-Z_]+"? *&& *mv` (rough — final regex tuned during WU2)

Source: 2026-04-30 incident — `/epistemic-postflight` wiped a 91KB epistemic.json this way.

Initial counters: `total_hits: 4`, `recent_hits: 4` (the four sister-site occurrences caught and fixed this session). After remediation: `locations_remedied: 4`.

### 2. `bash-missing-fail-fast`

Pattern: detect a function or top-level script that uses a critical variable (e.g., `SESSION_ID`, `PROJECT`, `EPISTEMIC_FILE`) without a preceding `[ -z "$X" ] && exit` or equivalent guard.

This one is harder to regex tightly — accept a coarser signal: "function/script body references variable that is `grep`'d out of a file but no fail-fast immediately follows." Accept some false-positive rate; document it explicitly.

Source: 2026-04-30 — postflight proceeded with empty `SESSION_ID` and that compounded with the unsafe write.

Initial counters: `total_hits: 1`, `recent_hits: 1` (the postflight site, now remediated). After remediation: `locations_remedied: 1`.

### 3. `bash-rm-rf-with-variable` (rev2 replacement)

Pattern: `\brm +-r[fr]?[fr]? +"?\$\{?[A-Z_a-z]+` — matches `rm -rf $VAR`, `rm -rf "$VAR"`, `rm -rf ${VAR}/`, etc.

Why dangerous: if the variable is unset or empty, `rm -rf $UNSET/` becomes `rm -rf /`. Even when "obviously" set, dynamic edge cases (whitespace, glob expansion, partial substitution) bite. The accepted-safe form requires explicit guards: `[ -n "$VAR" ] && [ "$VAR" != "/" ] && rm -rf -- "$VAR"`.

Source: well-documented anti-pattern across many incidents in the wild. Not specific to this codebase — included as a v1 entry that exercises the **recent_hits=0** path (good test of the recency signal: a pattern can exist in the catalog without recent activity, and the system should report this honestly rather than fabricate hits).

Initial counters: `total_hits: 0`, `recent_hits: 0` (sweep will populate from `git ls-files` on first full run; expected to find zero or near-zero in claude-sail).

## Work Units

| WU | Description | Complexity | TDD | Depends on |
|----|-------------|------------|-----|------------|
| WU1 | Schema doc (`SCHEMA.md`) — frontmatter spec, add-pattern flow, counter semantics. | Low | No | — |
| WU2 | Three starter entries (`bash-unsafe-atomic-write`, `bash-missing-fail-fast`, `bash-rm-rf-with-variable`) with tuned `detection_regex` + `fixture_good` + `fixture_bad`. Manual hand-grep verifies regex on this repo. | Medium | Yes (fixture-based) | WU1 |
| WU3 | `scripts/anti-pattern-sweep.sh` — both modes, self-test loop, **EXCLUDE_PATHS filter (rev2)**, event log with **10000-line cap rev2**, counter regeneration, **safe-swap helper-or-fallback (rev2)**, vault export, fail-open semantics. Estimate revised to 150 min (rev2, F6). | **High** | Yes | WU1, WU2 |
| WU4 | `/end` integration — opt-in invocation block. | Low | No (manual smoke test) | WU3 |
| WU5 | `commands/templates/stock-anti-patterns/` + `/bootstrap-project` **file-level copy-if-not-exists (rev2, F7)** + `install.sh` template copy. | Medium | No (covered by install dry-run) | WU2 |
| WU6 | **`hooks/anti-pattern-write-check.sh`** — PreToolUse shell hook on Write/Edit, scans content against catalog regexes, emits `Catalog: <id>` citations to Claude via stdout JSON `additionalContext` (rev4 — AC14 verified). Updates `settings-example.json` to wire the hook. **Final manual gate before WU6 marks complete:** verify in a fresh Claude session that the citation surfaces in tool feedback (Form 2 of AC14). | Medium | Yes | WU2 |
| WU7 | Test suite additions: `test.sh` Category 4 frontmatter validation for catalog entries; behavioral fixture for sweep idempotency; **fixture for hook firing on Write content match (rev2)**; install dry-run check for stock-anti-patterns. README updates. | Medium | Yes | WU3, WU5, WU6 |

7 WUs, 1 high-complexity (WU3). Auto-tier: **Full**. User can override with `--tier=standard` if the design feels well-converged enough to skip Refine.

## Acceptance Criteria

Per success criterion in `describe.md`:

| ID | Criterion | Verification |
|----|-----------|-------------|
| AC1 | Catalog exists with ≥3 entries | `ls .claude/anti-patterns/*.md \| wc -l` ≥ 3 |
| AC2 | Sweep increments `recent_hits` on detection | Fixture: write a known-bad file, run sweep, observe counter delta |
| AC3 | Sweep is idempotent | Run sweep twice with no source changes; counters identical |
| AC4 | One hookify rule cites a catalog ID | `grep -l '\*\*Catalog:\*\*' hookify-rules/` returns ≥1 |
| AC5 | Full sweep finds existing instances | Run `--full` against claude-sail, hand-verify count of `> "$TMP" && mv` matches |
| AC6 | Add-pattern docs exist | `.claude/anti-patterns/SCHEMA.md` exists, ≤1 page, covers schema + flow + counter semantics |
| AC7 | Catalog frontmatter is test-validated | `bash test.sh` validates required fields per entry; missing fields fail the suite |
| AC8 | Sweep fails open in `/end` | Force a sweep failure (corrupt a regex); `/end` still exits 0 |
| AC9 | Vault export is fail-open | With vault unavailable: sweep completes, no errors raised, project-local catalog updated |
| AC10 | Stock catalog ships via `/bootstrap-project` | Bootstrap a fresh dir, observe `.claude/anti-patterns/` populated with 3 starters |
| AC11 | Sweep writes heartbeat on success (rev2, F-PM-1) | After successful sweep, `.claude/anti-patterns/.last-sweep.json` exists with timestamp + duration_ms + events_appended |
| AC12 | `/end` surfaces stale-sweep nudge (rev2, F-PM-2) | With heartbeat artificially aged to >7 days, running `/end` prints `last successful sweep: Nd ago` to stderr |
| AC13 | Counter regen dedupes by (id, file, line) tuple (rev3, E20) | Append two events for the same tuple seconds apart; sweep reports `total_hits: 1`, not 2. Verifiable in evals/evals.json fixture. |
| AC14 | PreToolUse hook warning is visible to Claude via additionalContext (rev4) | Form 1 (unit): hook emits valid JSON to stdout containing `hookSpecificOutput.additionalContext` with `Catalog: <id>` text on a deliberately matching input. Form 2 (manual, fresh session): a real Write in a Claude Code session produces tool feedback containing the citation. Empirically confirmed during AC14 pre-impl verification — see ac14-verification.md. |

## Test Strategy

- **Fixture-based detection tests** (WU2, WU3): each pattern has paired fixture files. The sweep self-tests on these on every run; a CI check also verifies them.
- **Idempotency test** (WU3, WU7): run sweep twice, diff outputs, must be identical except for `last_seen` timestamps.
- **Fail-open tests** (WU3, WU4): inject failures (corrupt regex, missing jq, vault unavailable) and verify graceful degradation.
- **Install dry-run** (WU5, WU7): existing `test.sh` Category 7 verifies stock-anti-patterns lands in the install target.
- **Behavioral eval fixture** (WU7): add `anti-pattern-sweep` fixture to `evals/evals.json` with expected sweep output for a known input.

## Risks / Open Questions

| Risk | Mitigation |
|------|-----------|
| Detection regex over-matches in real code (false positives inflate counters) | Self-test against `fixture_good` on every sweep; document expected false-positive rate per pattern. |
| Detection regex under-matches (missed real instances) | Each pattern's body lists known-bad shapes; full-sweep results are hand-verified during WU2 against this repo. |
| Sweep slow on large projects | 5s hard cutoff for session mode; full mode is opt-in/manual. |
| Catalog bit-rot — entries become outdated | `status: active|retired`; sweep flags entries with `recent_hits == 0` for >90 days as advisory "consider retiring". |
| `.events.jsonl` grows unbounded | Rev2: 10000-line cap with archive of oldest 5000 to `.events.archive.jsonl`. Counter regen reads active log only. |
| Truncated/corrupt event log line (rev2, E10) | Skip malformed line with WARN; sweep is resilient to partial corruption. |
| Clock skew impact on recent_hits (rev2, E15) | Counter accuracy depends on monotonic-ish system clock. Major backward skew can temporarily inflate `recent_hits`. Documented limitation, not a v1 fix. |
| Symlinked catalog entries (rev2, E19) | Catalog entries should be regular files. Symlinks to vault may cause writes to land outside the project, breaking project-local source-of-truth. Document; do not auto-detect. |
| File rename mid-sweep (rev2, E7) | Phantom `locations_remedied` may appear. Self-corrects on next sweep. Documented limitation. |
| Vault and project frontmatter drift | Vault is mirror, not source; on conflict, project wins (sweep overwrites vault entry). Mirror prefixed with auto-generated header (rev3, DA-3) so contract is visible to vault editors. |
| Shell hook warn-action might be too noisy | Hook uses `action: warn` (exit 0 with stderr) not block; user can tighten by editing the hook. |
| Detection regex mutated between sweeps (rev3, E21) | Old events in `.events.jsonl` remain tagged with the entry's id but were matched by a prior regex. `recent_hits` becomes a mix of old-regex and new-regex matches. Acceptable for v1; users who substantially change a regex should optionally archive old events for that id. |
| Orphaned events for deleted patterns (rev3, E22) | If a pattern entry is deleted, events tagged with its id remain in `.events.jsonl` and are not garbage-collected. Counter regen runs on existing entries only, so orphans don't appear in counters but do contribute to log size. v2: optional `--full --prune` flag. |
| `git diff --name-only @{1.hour.ago}` after rebase (rev3, E24) | Reflog reference may point to commits no longer reachable, producing phantom events from orphaned commits. Mitigation: wrap in `git rev-parse ... 2>/dev/null \|\| echo HEAD` fallback chain in the sweep script; preferable to silent miscount. |

## Open Questions for Stage 3 (Challenge)

1. Should `bash-missing-fail-fast` be in v1, or is its detection too imprecise? Could substitute a tighter pattern.
2. Should the event log be `.events.jsonl` or scoped per-pattern (`.events/<id>.jsonl`)? Per-pattern scales better at 100+ patterns; single file is simpler at <100.
3. Should `--full` sweep auto-prune `.events.jsonl` events whose source files no longer exist? (Currently: no, deferred.)
