# Spec: Anti-Pattern Catalog

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
     - total_hits = count of all events with this id
     - recent_hits = count of events with this id where ts >= now - recent_window_days
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
   For each updated entry, write a mirror to:
     $VAULT_PATH/Engineering/Anti-Patterns/<project>-<id>.md
   Mirror has identical body + frontmatter PLUS:
     project: <basename of git toplevel>
     mirror_of: .claude/anti-patterns/<id>.md
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

**Hook script contract:**

```bash
#!/usr/bin/env bash
# anti-pattern-write-check.sh — PreToolUse on Write/Edit
#
# Reads the tool-call JSON from STDIN (matches the convention used by
# secret-scanner.sh, freeze-guard.sh, etc.). Extracts the candidate file
# content from .tool_input.content (Write) OR .tool_input.new_string (Edit),
# scans against each catalog pattern's detection_regex.
# Warns on match (action: warn, exit 0). Cites Catalog: <id> in the warning.

set +e

# Hook runtime toggle (matches existing convention)
HOOK_NAME="anti-pattern-write-check"
[[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]] && exit 0

CATALOG_DIR="$(git rev-parse --show-toplevel 2>/dev/null)/.claude/anti-patterns"
[ -d "$CATALOG_DIR" ] || exit 0   # opt-in by directory presence

input=$(cat)
content=$(echo "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)
[ -z "$content" ] && exit 0   # nothing to scan (could be a non-content tool call)

# For each catalog entry: parse frontmatter for detection_regex, scan content,
# emit warnings to stderr. (Implementation detail in WU6.)
```

The stdin/jq pattern matches existing hooks (`hooks/secret-scanner.sh:23` uses
`input=$(cat); cmd=$(echo "$input" | jq -r '.tool_input.command // empty')`).
For Write tool the content field is `.tool_input.content`; for Edit it's
`.tool_input.new_string`. The fallback chain `// empty` handles both.

**Action: `warn`**, not `block` — matches existing toolkit posture for non-fatal patterns.
User can tighten to block per-pattern by editing the hook (or by adding a hookify-style
`action: block` entry to the pattern's frontmatter, which a future hook iteration can read).

**Catalog reference convention:** the warning emitted by the hook MUST include the line
`Catalog: <id>` so the user sees the entry name in their feedback. The convention is documented
in `.claude/anti-patterns/SCHEMA.md`. The sweep can optionally grep hook output / hookify rule
bodies for `Catalog:` references to derive bidirectional links — deferred to v2.

**Why a shell hook, not hookify:** F1 — hookify rules in this toolkit fire on `event: bash`
only. Write/Edit content interception requires PreToolUse hooks. Shell hooks are deterministic,
already follow toolkit fail-open discipline, and don't depend on plugin capabilities we
haven't verified. Trade-off: the catalog's first consumer is now a shell hook, not a hookify
rule. The describe.md framing "at least one hookify rule cites a catalog ID" is updated to
"at least one consumer cites a catalog ID by convention."

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
| WU6 | **`hooks/anti-pattern-write-check.sh` (rev2 — was hookify rule)** — PreToolUse shell hook on Write/Edit, scans content against catalog regexes, emits `Catalog: <id>` warnings. Updates `settings-example.json` to wire the hook. | Medium (rev2, was Low) | Yes | WU2 |
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
| Vault and project frontmatter drift | Vault is mirror, not source; on conflict, project wins (sweep overwrites vault entry). Documented behavior. |
| Shell hook warn-action might be too noisy | Hook uses `action: warn` (exit 0 with stderr) not block; user can tighten by editing the hook. |

## Open Questions for Stage 3 (Challenge)

1. Should `bash-missing-fail-fast` be in v1, or is its detection too imprecise? Could substitute a tighter pattern.
2. Should the event log be `.events.jsonl` or scoped per-pattern (`.events/<id>.jsonl`)? Per-pattern scales better at 100+ patterns; single file is simpler at <100.
3. Should `--full` sweep auto-prune `.events.jsonl` events whose source files no longer exist? (Currently: no, deferred.)
