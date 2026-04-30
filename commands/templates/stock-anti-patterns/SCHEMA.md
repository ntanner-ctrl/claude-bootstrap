# Anti-Pattern Catalog Schema

Markdown catalog of language-specific anti-patterns. Counters are **derived** from a
session-end sweep — never hand-maintained. Project-local source of truth.

## Layout

```
.claude/anti-patterns/
├── SCHEMA.md                # this file
├── <pattern-id>.md          # one file per pattern, kebab-case id
├── .events.jsonl            # append-only detection event log
├── .events.archive.jsonl    # rolled-over events (oldest 5000 when log >10k)
└── .last-sweep.json         # heartbeat — last successful sweep stats
```

## Frontmatter Schema

```yaml
---
id: bash-unsafe-atomic-write              # required, kebab-case, MUST equal filename
language: bash                             # required: bash | python | js | ...
severity: high                             # required: critical | high | medium | low
status: active                             # required: active | retired
detection_regex: '> *"\$[A-Z_]+"? *&& *mv' # required, POSIX ERE (grep -E)
fixture_good: |                            # required, must NOT match the regex
  jq -e . "$TMP" >/dev/null && mv "$TMP" "$FILE"
fixture_bad: |                             # required, MUST match the regex
  jq '.' input > "$TMP" && mv "$TMP" "$FILE"
first_seen: 2026-04-30                     # required, ISO date
last_seen: 2026-04-30                      # derived — most recent detection
total_hits: 0                              # derived — unique (id,file,line) tuples
recent_hits: 0                             # derived — within recent_window_days
recent_window_days: 60                     # required, default 60
locations_remedied: 0                      # derived
related_hookify: []                        # optional
references: []                             # optional — links to incidents/PRs
---
# Pattern title
Free-form prose: what it looks like, why it's dangerous, how to fix.
```

## Required vs Derived Fields

**Required (hand-maintained):** `id`, `language`, `severity`, `status`,
`detection_regex`, `fixture_good`, `fixture_bad`, `first_seen`, `recent_window_days`.

**Derived (DO NOT hand-edit):** `last_seen`, `total_hits`, `recent_hits`,
`locations_remedied`. Hand-edits are overwritten on next sweep —
`.events.jsonl` is the single source of truth. `test.sh` validates required fields.

## Add a Pattern

1. Copy an existing entry. 2. Fill `id` (=filename), `detection_regex` (POSIX ERE),
both fixtures. 3. Run `bash scripts/anti-pattern-sweep.sh --full` to validate + seed
counters. Sweep self-tests on fixtures every run; broken regexes are skipped.

## Sweep Modes

`--session` (opt-in via `/end`, 5s cutoff, scope = files modified this session) or
`--full` (manual, runs to completion, scope = `git ls-files`). Both fail-open.

## Counter Semantics (derived from `.events.jsonl`)

- `total_hits` = unique `(id, file, line)` tuples for this id (deduped on read)
- `recent_hits` = subset within `recent_window_days`
- `last_seen` = max(ts) for id, else `first_seen`
- `locations_remedied` = `file:line` tuples that matched older sweeps but not the most recent

## Hook Integration

`hooks/anti-pattern-write-check.sh` (PreToolUse Write/Edit) cites matches via stdout
JSON `hookSpecificOutput.additionalContext` with `Catalog: <id>` — canonical Claude
Code warn-with-visibility primitive. Other consumers should cite the same form.

## Disabling

- `SAIL_DISABLED_HOOKS=anti-pattern-write-check` — disable hook for a session
- `rm .claude/anti-patterns/.last-sweep.json` — silence stale-sweep nudge
- `status: retired` in frontmatter — exclude from sweep matching
