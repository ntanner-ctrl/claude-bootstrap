# Specification: Native Epistemic Tracking for claude-sail

> **Revision 3** (2026-03-19) — Addresses 20 adversarial findings across design
> challenge (F1-F8), edge cases (F9-F15), and pre-mortem (F16-F20).
> See `spec.diff.md` for change history.

## 1. Overview

Replace the Empirica MCP server with a native epistemic tracking system built into
claude-sail's existing hook infrastructure. The system tracks 13 epistemic vectors
across sessions, computes rolling-average calibration deltas, and generates behavioral
feedback that pairs concrete instructions with raw numbers.

### 1.1 Design Principles

1. **Numbers + instructions, not numbers alone** — Every calibration correction is
   paired with a natural-language behavioral instruction. "You overestimate `know`
   by 0.12" is trivia. "In prior sessions you skipped reading tests when `know` was
   high — read tests first" is actionable.

2. **Context-sensitive calibration** — Aggregate accuracy must not create false
   confidence in novel situations. The system tags sessions by project and domain,
   and warns when historical calibration may not transfer.

3. **Fail-open, fail-loudly** — If any component fails, the session continues
   (exit 0 always). But write warnings to stderr so Claude can surface them to the
   user. Silent failure is worse than noisy failure — "misleading success signals
   are more dangerous than crashes." [F12]

4. **Bash-only, jq for JSON** — No Python runtime dependency. Shell scripts + jq
   for all computation. `awk` as fallback for floating-point if jq unavailable.

5. **Upgrade-ready data model** — Schema designed to support Bayesian updating later
   without migration. Rolling averages are stored alongside the raw data that Bayesian
   updating would consume.

### 1.2 Non-Goals

- Real-time calibration adjustment mid-session (future work)
- Grounded verification against objective evidence like test results (Layer 3, future)
- Cross-AI calibration comparison
- Replacing the preflight/postflight ritual itself (we keep the ritual)

## 2. Data Model

### 2.1 Primary Store: `~/.claude/epistemic.json`

Single JSON file, all projects, all sessions. No SQLite, no fragmentation.

```jsonc
{
  "schema_version": 1,
  "last_updated": "2026-03-19T11:00:00Z",

  // Rolling calibration state per vector (the "beliefs")
  "calibration": {
    "know": {
      "rolling_mean_delta": -0.12,     // mean(postflight - preflight) across sessions
      "observation_count": 8,          // number of paired sessions
      "last_deltas": [-0.1, -0.15, -0.08, -0.2, -0.05, -0.12, -0.15, -0.11],
      "correction": -0.12,            // capped at ±0.25, applied to next preflight
      "behavioral_instruction": "You tend to overestimate 'know'. In past sessions you skipped exploring unfamiliar code paths. Read at least 3 files in unfamiliar areas before rating know > 0.7.",
      "last_updated": "2026-03-19T11:00:00Z"
    }
    // ... repeat for all 13 vectors
  },

  // Per-project calibration context (for context-sensitivity)
  "projects": {
    "claude-sail": {
      "session_count": 15,
      "last_session": "2026-03-19T11:00:00Z",
      "familiarity": "high"           // high (10+), medium (3-9), low (0-2)
    }
  },

  // Recent session history (last N sessions, for trend detection)
  "sessions": [
    {
      "id": "abc-123",
      "project": "claude-sail",
      "timestamp": "2026-03-19T11:00:00Z",
      "preflight": {
        "engagement": 0.9, "know": 0.8, "do": 0.3, "context": 0.7,
        "clarity": 0.8, "coherence": 0.7, "signal": 0.75, "density": 0.6,
        "state": 0.7, "change": 0.2, "completion": 0.0, "impact": 0.7,
        "uncertainty": 0.35
      },
      "postflight": {
        "engagement": 0.85, "know": 0.7, "do": 0.8, "context": 0.8,
        "clarity": 0.85, "coherence": 0.75, "signal": 0.8, "density": 0.7,
        "state": 0.8, "change": 0.7, "completion": 0.6, "impact": 0.75,
        "uncertainty": 0.2
      },
      "deltas": {
        "engagement": -0.05, "know": -0.1, "do": 0.5, "context": 0.1,
        "clarity": 0.05, "coherence": 0.05, "signal": 0.05, "density": 0.1,
        "state": 0.1, "change": 0.5, "completion": 0.6, "impact": 0.05,
        "uncertainty": -0.15
      },
      "task_summary": "Empirica extraction blueprint",
      "paired": true
    }
    // ... last 50 sessions (rolling window)
  ],

  // Bayesian upgrade fields (populated but unused until upgrade)
  "bayesian": {
    "enabled": false,
    "beliefs": {}   // Will hold {vector: {mean, variance, evidence_count}} when enabled
  }
}
```

#### Schema Design Decisions

1. **`last_deltas` array** — Stores raw deltas per vector (last 50). Rolling average
   computed from this. When Bayesian upgrade happens, these same values become the
   observation history.

2. **`projects` map** — Enables context-sensitive warnings. If project familiarity
   is "low" but `know` calibration says "well-calibrated," the system warns:
   "Calibration based on familiar projects — this project is new to you."

3. **50-session rolling window** — Prevents stale data from dominating. Older sessions
   age out naturally.

4. **`paired` flag** — Only sessions with both preflight AND postflight contribute
   to calibration. Unpaired sessions are stored for history but excluded from delta
   computation.

### 2.2 Session ID Persistence

Session IDs must survive context compaction. Three-layer fallback:

1. **In-conversation memory** — Claude remembers the session ID (works until compaction)
2. **File marker** — `~/.claude/.current-session` contains the active session ID + project
3. **Hook injection** — SessionStart hook writes ID; postflight hook reads it back

Format of `~/.claude/.current-session`:
```
SESSION_ID=abc-123
PROJECT=claude-sail
STARTED=2026-03-19T11:00:00Z
```

### 2.3 Obsidian Integration

When vault is available, session vectors are written to Obsidian note frontmatter.
This is the human-readable layer — the JSON file is the machine layer.

Obsidian note frontmatter additions (to existing session log template):
```yaml
epistemic_preflight:
  know: 0.8
  uncertainty: 0.35
  # ... all 13 vectors
epistemic_postflight:
  know: 0.7
  uncertainty: 0.2
  # ... all 13 vectors
epistemic_deltas:
  know: -0.1
  uncertainty: -0.15
  # ... all 13 vectors
calibration_warnings:
  - "know: overestimated in 7/8 recent sessions (mean delta -0.12)"
```

## 3. The 13 Vectors

All vectors retained from Empirica. Each scored 0.0-1.0 by Claude at preflight and postflight.

| Vector | Measures | What a delta reveals |
|--------|----------|---------------------|
| `engagement` | Alignment with the task | Whether Claude was more/less invested than expected |
| `know` | Knowledge of the domain/codebase | Whether understanding was over/underestimated |
| `do` | Ability to execute on the task | Whether implementation difficulty was misjudged |
| `context` | Understanding of surrounding context | Whether relevant context was missed/found |
| `clarity` | Clarity of requirements/goals | Whether requirements became clearer/muddier |
| `coherence` | Internal consistency of approach | Whether the plan held together or fragmented |
| `signal` | Relevance of available information | Whether available data was useful or noise |
| `density` | Information density of the work | Whether the session was substance-rich or thin |
| `state` | Understanding of current system state | Whether current state was accurately assessed |
| `change` | Amount of change produced | Whether change expectations matched reality |
| `completion` | Progress toward done | Whether completion was over/underestimated |
| `impact` | Expected impact of the work | Whether impact predictions were accurate |
| `uncertainty` | Level of unknowns remaining | Whether uncertainty was properly calibrated |

### 3.1 Vector Categories (Informational)

Vectors naturally cluster into three categories. These are informational — all vectors
are tracked equally, but categories help structure feedback:

- **Knowledge vectors**: `know`, `context`, `state`, `signal` — what Claude knows
- **Action vectors**: `do`, `change`, `completion`, `impact` — what Claude produces
- **Meta vectors**: `engagement`, `clarity`, `coherence`, `density`, `uncertainty` — how Claude reasons

## 4. Computation

### 4.1 Rolling Average Calibration

For each vector `v`, given paired sessions `S₁..Sₙ`:

```
delta_i = postflight_i[v] - preflight_i[v]
rolling_mean = mean(delta_1..delta_n)     // over last 50 paired sessions
correction = clamp(rolling_mean, -0.25, 0.25)
```

The correction represents: "on average, your postflight score differs from your
preflight score by this much." A negative correction on `know` means "you tend to
rate yourself higher than you end up."

### 4.2 Minimum Observation Threshold

Calibration corrections only activate after **5 paired sessions** per vector.
Below that threshold, the system reports "insufficient data" rather than a correction.

### 4.3 Context-Sensitive Adjustments

Before presenting calibration at session start, the system checks project familiarity:

```
if project.familiarity == "low" AND calibration.observation_count >= 5:
  append warning: "Calibration based on {observation_count} sessions in familiar
  projects. This project ({project_name}) is new — historical calibration may
  not transfer. Consider rating conservatively."
```

### 4.4 Behavioral Instruction Generation

This is the key innovation. Raw corrections are paired with behavioral instructions.

**Instruction template structure:**
```jsonc
{
  "vector": "know",
  "direction": "overestimate",    // or "underestimate" or "well_calibrated"
  "magnitude": "moderate",        // small (<0.08), moderate (0.08-0.18), large (>0.18)
  "instruction": "...",           // natural language, project-aware
  "based_on": 8                   // observation count
}
```

**Instruction generation rules:**

The SessionEnd hook generates behavioral instructions based on delta patterns.
Instructions are stored in `epistemic.json` and presented at the next session start.

| Vector | Direction | Template |
|--------|-----------|----------|
| `know` | overestimate | "You tend to overestimate understanding. In past sessions, this led to skipping exploration of unfamiliar code. Before rating `know` above 0.7, verify you've read at least 3 files in the target area." |
| `know` | underestimate | "You tend to underestimate understanding. Your actual comprehension is typically higher than you think. Trust your initial assessment more — don't over-research areas you already grasp." |
| `do` | overestimate | "You tend to overestimate your ability to execute. Implementation often takes longer or is more complex than initially assessed. Budget extra time for unexpected complexity." |
| `uncertainty` | overestimate | "You tend to overestimate uncertainty. Your uncertainty predictions are usually higher than warranted — you know more than you think you do." |
| `completion` | underestimate | "You tend to underestimate completion progress. Sessions typically achieve more than you expected. Your milestones may be more conservative than necessary." |

**Catch-all for vectors without specific templates:**
```
"Your {vector} self-assessment tends to be {direction}d by ~{abs(correction):.2f}.
Consider adjusting your next {vector} rating accordingly."
```

**Well-calibrated feedback:**
```
"Your {vector} assessment has been accurate across {count} sessions (delta ±{abs(correction):.2f}).
Note: this accuracy is based on {familiar_project_list}. New projects may differ."
```

### 4.5 Implementation: Shell + jq

All computation happens in shell scripts using `jq` for JSON manipulation and
floating-point arithmetic.

**REQUIRED: Atomic write pattern.** All writes to `epistemic.json` MUST use
temp-file-then-rename to prevent corruption from interrupted writes:

```bash
EPISTEMIC_FILE="$HOME/.claude/epistemic.json"
EPISTEMIC_TMP="$HOME/.claude/epistemic.json.tmp"

# CORRECT: atomic write via temp file
jq '.calibration.know.last_deltas += [-0.1] | .calibration.know.last_deltas |= .[-50:]' \
  "$EPISTEMIC_FILE" > "$EPISTEMIC_TMP" && mv "$EPISTEMIC_TMP" "$EPISTEMIC_FILE"

# WRONG (data loss on interrupt):
# jq '...' ~/.claude/epistemic.json > ~/.claude/epistemic.json   # NEVER DO THIS
```

**REQUIRED: Null-safe computation.** All arithmetic on `last_deltas` MUST filter
nulls and guard against empty arrays. Null propagation through jq is silent — one
null value poisons the entire rolling mean without producing an error. [F9]

```bash
# CORRECT: null-safe rolling mean computation
jq '[.calibration.know.last_deltas[] | select(. != null) | tonumber] |
  if length == 0 then 0 else add / length end' "$EPISTEMIC_FILE"

# WRONG (null propagation):
# jq '[.calibration.know.last_deltas[]] | add / length'   # null/0 = null silently
```

Key operations (all using atomic write + null-safe patterns):
```bash
# Read (no write needed — safe as-is)
jq -r '.calibration.know.rolling_mean_delta' "$EPISTEMIC_FILE"

# Compute rolling mean — null-safe, empty-safe (read-only)
jq '[.calibration.know.last_deltas[] | select(. != null) | tonumber] |
  if length == 0 then 0 else add / length end' "$EPISTEMIC_FILE"

# Update correction with clamp (atomic write)
jq '.calibration.know.correction |= (if . > 0.25 then 0.25 elif . < -0.25 then -0.25 else . end)' \
  "$EPISTEMIC_FILE" > "$EPISTEMIC_TMP" && mv "$EPISTEMIC_TMP" "$EPISTEMIC_FILE"
```

**jq availability:** jq is widely available (apt, brew, most CI images). If jq is
not installed, the system degrades gracefully: vectors are stored but calibration
computation is skipped, with a one-time warning suggesting jq installation.

## 5. Hook Architecture

### 5.1 SessionStart Hook: `hooks/epistemic-preflight.sh`

**Trigger:** SessionStart event
**Exit code:** Always 0 (fail-open — never block session start)

**Behavior:**
1. `mkdir -p ~/.claude/` — ensure directory exists before any writes [F14]
2. Generate a new session ID (UUID via `uuidgen` or `cat /proc/sys/kernel/random/uuid`)
3. Detect current project (from git root basename, fallback to cwd basename)
4. **Unconditionally overwrite** `~/.claude/.current-session` marker file — if a stale
   marker exists from a crashed previous session, overwrite it. The crashed session will
   never submit postflight vectors, so its marker is always safe to replace.
   (Historical lesson: 2026-03-10 Empirica resolver deadlock was caused by stale marker
   files gating lifecycle events.) If write fails, output warning to stderr:
   `WARNING: .current-session write failed — session will not be tracked.` [F12]
5. Read calibration state from `~/.claude/epistemic.json`
6. Compute project familiarity (count sessions for this project)
7. **Pairing rate health check:** If sessions array has 10+ entries and 0 have
   `paired: true`, output warning: `WARNING: 0 of {N} sessions have paired.
   Check that /end is working correctly.` [F17]
8. Build calibration context message (corrections + behavioral instructions + warnings)
9. Output to stderr (injected into Claude's context):

```
[Epistemic Tracking]
Session: {session_id}
Project: {project_name} (familiarity: {high|medium|low})

Calibration ({observation_count} paired sessions):
  know: correction -0.12 (overestimate)
    → You tend to overestimate understanding. Read at least 3 files
      in unfamiliar areas before rating know > 0.7.
  completion: correction +0.08 (underestimate)
    → You typically achieve more than expected. Your milestones may
      be more conservative than necessary.
  [other vectors with |correction| > 0.05]

  Context warning: {project_name} is new (2 prior sessions).
  Calibration based on familiar projects — may not transfer.

Submit preflight vectors by providing 13 scores (0.0-1.0) for:
  engagement, know, do, context, clarity, coherence, signal,
  density, state, change, completion, impact, uncertainty
```

**Timing:** Must complete in < 2 seconds. Enforced via `timeout 1.5s` wrapper around
the computation block (leaving 0.5s headroom for shell startup). On timeout:
- Exit 0 (fail-open — never block session start)
- Output minimal message: `[Epistemic Tracking] Calibration unavailable (timeout).`
- Include a **fast path**: if `~/.claude/epistemic.json` doesn't exist OR is empty
  (0 bytes), skip all computation and just output the vector prompt. Use `-s` test
  (exists AND non-empty), not `-f` (exists only). A 0-byte file from a WSL2/NTFS
  crash is functionally equivalent to no file. [F10]

### 5.2 SessionEnd Hook: `hooks/epistemic-postflight.sh`

**Trigger:** SessionEnd event (or `/end` command)
**Exit code:** Always 0 (fail-open)

**Behavior:**
1. Read `~/.claude/.current-session` for session ID and project
2. Read preflight vectors from `~/.claude/epistemic.json` (latest unpaired session)
3. Prompt Claude for postflight vectors (via stderr output that Claude responds to)
4. Compute deltas: `postflight[v] - preflight[v]` for each vector
5. Update `epistemic.json`:
   a. Mark session as paired
   b. Append deltas to each vector's `last_deltas` array
   c. Recompute `rolling_mean_delta` for each vector
   d. Recompute `correction` (clamped ±0.25)
   e. Regenerate `behavioral_instruction` based on new correction
   f. Update project familiarity count
6. Write Obsidian note frontmatter (if vault available)
7. Clean up `~/.claude/.current-session`

**The postflight problem:** Getting Claude to actually submit postflight vectors at
session end has been the hardest part (15% pairing rate in Empirica).

**Mitigations (ranked by effectiveness):**

1. **PRIMARY: `/end` command integration** — The `/end` command invokes
   `/epistemic-postflight` as part of its workflow. Any session closed with `/end`
   automatically captures postflight vectors. This is the single mechanism that
   structurally solves the problem — it creates an explicit user action that triggers
   vector capture.

2. **SECONDARY: SessionEnd hook reminder** — If postflight vectors haven't been
   submitted when SessionEnd fires, the hook outputs a reminder. This is a fallback,
   not a primary mechanism — SessionEnd may fire when the terminal is already closing.

3. **TERTIARY: CLAUDE.md instructions** — Behavioral nudging. "Suggestions only" by
   the spec's own enforcement tier taxonomy. Helps but cannot be relied upon.

4. **GRACEFUL DEGRADATION: Unpaired sessions stored** — Sessions without postflight
   are stored for history and project familiarity tracking, but excluded from
   calibration delta computation. This is not a mitigation — it's the failure mode.

**Realistic target:** 50-60% pairing rate. Sessions closed via `/end` will pair.
Sessions where the user closes the terminal or context expires will not. This is a
**usage discipline constraint**, not a solvable engineering problem. A 50% pairing
rate with reliable data is worth more than a 100% target with corrupt data.

### 5.3 Vector Capture: Slash Commands

**Why slash commands, not PostToolUse hooks:** PostToolUse hooks receive tool call
payloads (the input/output of Bash, Read, Edit, etc.), NOT Claude's prose messages.
A hook that "scans Claude's output for vectors" would never fire because there is
no tool call to trigger on. Slash commands create an explicit, deterministic trigger
surface — Claude invokes the command, the command writes the file.

#### `/epistemic-preflight` command

A slash command (markdown file in `commands/`) that:
1. Accepts 13 vector values as structured input (Claude provides them inline)
2. Reads `~/.claude/.current-session` for session context
3. Writes preflight vectors to `~/.claude/epistemic.json` under the current session
4. Marks session as "preflight_complete"
5. Confirms: "Preflight vectors recorded for session {id}."

The command is a markdown file with a Bash execution block. Claude invokes it
naturally after seeing the SessionStart hook's prompt. CLAUDE.md instructs Claude
to use `/epistemic-preflight` (not free-form prose) to submit vectors.

**Double submission:** If invoked twice in the same session, the second invocation
overwrites the first. This is the correct behavior — Claude may revise its
self-assessment after gaining context. [F15]

#### `/epistemic-postflight` command

A slash command that:
1. Accepts 13 vector values
2. Reads session_id from `~/.claude/.current-session`
3. Looks up preflight vectors in `epistemic.json` by **strict session_id match**
   (`sessions[] | select(.id == current_session_id)`). Do NOT use "latest unpaired"
   heuristic — cross-session pairing produces meaningless deltas that poison
   calibration. [F11]
4. **If no matching preflight found:** store postflight as standalone (for history),
   skip delta computation, do NOT increment observation_count, output to stderr:
   `Note: No preflight found for this session. Postflight stored but not paired.` [F13]
5. If matching preflight found, computes deltas: `postflight[v] - preflight[v]`
4. Updates `epistemic.json`:
   a. Marks session as paired
   b. Appends deltas to each vector's `last_deltas` array (atomic write)
   c. Recomputes `rolling_mean_delta` for each vector
   d. Recomputes `correction` (clamped ±0.25)
   e. Regenerates `behavioral_instruction` based on new correction
   f. Updates project familiarity count
5. Writes Obsidian note frontmatter (if vault available)
6. Cleans up `~/.claude/.current-session`
7. Reports: "Postflight recorded. Deltas: [summary]. Calibration updated."

#### Why this fixes the pairing rate

The `/end` command (already exists in claude-sail) can be updated to **invoke
`/epistemic-postflight` as part of its workflow**. This means any session closed
with `/end` automatically captures postflight vectors — the user doesn't need to
remember a separate step. This is the single strongest mitigation for the 15%
pairing rate problem.

### 5.4 Hook-to-Command Integration

The hooks and commands work together:

```
SessionStart event
  └→ hooks/epistemic-preflight.sh (hook)
       └→ Outputs calibration context to stderr
       └→ Prompts Claude to run /epistemic-preflight

Claude responds to prompt
  └→ /epistemic-preflight (slash command)
       └→ Writes vectors to epistemic.json

Session work happens...

User runs /end (or session ends)
  └→ /end command invokes /epistemic-postflight
       └→ /epistemic-postflight (slash command)
            └→ Computes deltas, updates calibration
            └→ Writes Obsidian frontmatter

SessionEnd event
  └→ hooks/epistemic-postflight.sh (hook)
       └→ If postflight not yet submitted: outputs reminder
       └→ Always exits 0 (fail-open)
```

This gives us TWO hooks (SessionStart, SessionEnd) and TWO commands
(`/epistemic-preflight`, `/epistemic-postflight`). The hooks handle event-driven
lifecycle; the commands handle data capture with deterministic triggers.

## 6. CLAUDE.md Integration

### 6.1 Replacement Instructions

The existing Empirica section in `~/.claude/CLAUDE.md` is replaced with:

```markdown
# Epistemic Self-Assessment

You have epistemic tracking enabled. This system helps you calibrate
your self-assessments over time.

## Session Lifecycle

1. **Session start**: Review calibration feedback (injected by hook).
   Submit preflight vectors using `/epistemic-preflight` with 13
   scores (0.0-1.0):
   `engagement, know, do, context, clarity, coherence, signal,
    density, state, change, completion, impact, uncertainty`

2. **During session**: Work normally. The vectors are a starting
   checkpoint, not a constraint.

3. **Session end**: Use `/end` to close the session. This
   automatically invokes `/epistemic-postflight` to capture
   postflight vectors and compute calibration deltas.

## Reading Calibration Feedback

At session start you'll see calibration corrections with behavioral
instructions. These are based on {N} paired sessions.

- **Instructions tell you WHAT TO DO**, not just that a number is off
- **Context warnings** flag when you're in an unfamiliar project
  where historical calibration may not apply
- **Well-calibrated** vectors still get a note about the projects
  the calibration is based on

## Key Principle

The ritual of self-assessment (decomposing your state into 13
dimensions) is the primary value. The calibration feedback refines
it over time. Neither is useful alone.
```

## 7. Migration

### 7.1 Data Import

Import existing paired sessions from Empirica's data stores.

**IMPORTANT: Schema verification required before implementation.** The actual Empirica
data format must be verified by inspecting `~/.empirica/` and project-level `.empirica/`
directories. The 2026-03-19 dual-table bug finding proved that `epistemic_snapshots` is
effectively empty — preflights AND postflights may both be in the `reflexes` table, or
data may be in JSONL files rather than SQLite.

**Source (two paths, try in order):**
1. **SQLite path:** Query `reflexes` table for BOTH preflight and postflight phases,
   matched by session_id. Do NOT assume `epistemic_snapshots` has postflight data.
2. **JSONL fallback:** If SQLite tables don't exist or are empty, parse
   `.empirica/insights.jsonl` and any `preflight.jsonl`/`postflight.jsonl` files.

**Script:** `scripts/migrate-empirica.sh` — one-time migration script (NOT installed
to `~/.claude/`, stays in repo).

Steps:
1. Verify data format: check for `.db` files (SQLite) and `.jsonl` files
2. Read paired sessions using the appropriate path (SQLite or JSONL)
3. Extract vector values, match preflight/postflight by session_id
4. Compute deltas
5. Write to `~/.claude/epistemic.json` using atomic write pattern
6. Compute initial rolling averages
7. Report: "Migrated N paired sessions, M unpaired sessions stored for history"
8. If zero paired sessions found: warn and suggest manual schema inspection

### 7.2 Existing Bayesian Beliefs

The 91 Bayesian belief records from Empirica are NOT migrated into the rolling
average system — they're artifacts of a different computation. The raw session
deltas (which we DO import) contain the same information in a form compatible
with both rolling averages and future Bayesian updating.

### 7.3 Orphaned Insights

The 678 orphaned insights in `.empirica/insights.jsonl` files across projects
are NOT migrated by this system. They are already being handled by the separate
vault curation workflow.

## 8. Deprecation

### 8.1 Deployment Procedure (Ordered) [F16, F20]

**CRITICAL: These steps have ordering dependencies.** Partial deployment breaks both
old and new systems. The `/end` command currently calls Empirica MCP tools — if those
are removed before `/end` is updated, the primary pairing mechanism dies silently.

**Step-by-step deployment:**

1. **Install new files** — Run `install.sh` to copy new hooks + commands to `~/.claude/`
2. **Update `/end` command FIRST** — Remove Empirica MCP calls from `/end`, add
   `/epistemic-postflight` invocation. Test that `/end` completes without error.
   This must happen BEFORE Empirica deprecation.
3. **Update `settings.json`** — Add new hook wiring (`epistemic-preflight.sh` on
   SessionStart, `epistemic-postflight.sh` on SessionEnd). Remove old Empirica
   hook wiring.
4. **Run smoke test** — `bash scripts/epistemic-smoke-test.sh` to verify the system
   works end-to-end [F18]
5. **Remove Empirica MCP** — Remove `empirica` entry from `~/.claude/mcp.json`
6. **Remove Empirica CLAUDE.md instructions** — Replace with new epistemic tracking section
7. **Verify** — Start a new Claude session, confirm calibration context appears

**Keep `.empirica/` directories intact** (read-only archive, no deletion).
Optionally: `pipx uninstall empirica` (user decision, not automated).

### 8.2 Rollback Procedure [F19]

If the new system fails after deployment:

1. Re-add `empirica` entry to `~/.claude/mcp.json`
2. Restore Empirica hook wiring in `settings.json`
3. Revert `/end` command to previous version (restore Empirica MCP calls)
4. New hooks remain on disk but don't fire (harmless)
5. Time to execute: ~2 minutes

### 8.3 claude-sail Repo Updates

1. Remove `hooks/empirica-*.sh` (all Empirica-specific hooks)
2. Add new `hooks/epistemic-*.sh` hooks
3. Add new `commands/epistemic-*.md` commands
4. Update `settings-example.json` with new hook wiring
5. Update `install.sh` to include new hooks + commands
6. Update `test.sh` to validate new files
7. Update `commands/end.md` to use new postflight system
8. Update `commands/start.md` to reference new calibration feedback

## 9. File Inventory

### New Files (in claude-sail repo)

| File | Location | Purpose |
|------|----------|---------|
| `hooks/epistemic-preflight.sh` | `hooks/` → `~/.claude/hooks/` | SessionStart: inject calibration context, prompt for vectors |
| `hooks/epistemic-postflight.sh` | `hooks/` → `~/.claude/hooks/` | SessionEnd: reminder if postflight not yet submitted |
| `commands/epistemic-preflight.md` | `commands/` → `~/.claude/commands/` | Slash command: capture preflight vectors, write to JSON |
| `commands/epistemic-postflight.md` | `commands/` → `~/.claude/commands/` | Slash command: capture postflight vectors, compute deltas, update calibration |
| `scripts/migrate-empirica.sh` | `scripts/` (NOT installed) | One-time data migration from Empirica data stores |
| `scripts/epistemic-init.sh` | `scripts/` (NOT installed) | Initialize `~/.claude/epistemic.json` with empty schema |
| `scripts/epistemic-smoke-test.sh` | `scripts/` (NOT installed) | Post-install verification: mock session, verify pairing [F18] |

### Modified Files

| File | Change |
|------|--------|
| `settings-example.json` | Add new hook wiring, remove Empirica hooks |
| `install.sh` | Include new hooks + commands in distribution, update counts |
| `commands/end.md` | Integrate `/epistemic-postflight` invocation into `/end` workflow |
| `test.sh` | Add validation for new hooks + schema |
| `commands/end.md` | Reference new postflight system |
| `commands/start.md` | Reference new calibration feedback format |

### Runtime Files (created by hooks, not in repo)

| File | Location | Purpose |
|------|----------|---------|
| `~/.claude/epistemic.json` | User's machine | Primary data store |
| `~/.claude/.current-session` | User's machine | Active session marker |

### Files Removed

| File | Reason |
|------|--------|
| `hooks/empirica-session-start.sh` | Replaced by epistemic-preflight.sh |
| `hooks/empirica-insight-capture.sh` | Obsidian handles this directly now |
| `hooks/empirica-postflight-reminder.sh` | Merged into epistemic-postflight.sh |

## 10. Work Units

| # | Unit | Dependencies | Est. Complexity |
|---|------|-------------|-----------------|
| 1 | JSON schema + init script | None | Low |
| 2 | Calibration computation (rolling avg, clamping, atomic writes, jq) | 1 | Medium |
| 3a | Behavioral feedback templates (priority 5 + catch-all) | 2 | Medium |
| 3b | Feedback generation logic | 2, 3a | Medium |
| 4 | SessionStart hook (calibration injection, timeout, stale marker handling) | 1, 2, 3b | Medium |
| 5a | `/epistemic-preflight` slash command (vector capture) | 1, 2 | Medium |
| 5b | `/epistemic-postflight` slash command (deltas, calibration update) | 1, 2, 3b, 5a | High |
| 5c | SessionEnd hook (postflight reminder) + `/end` integration | 5b | Medium |
| 6 | CLAUDE.md instruction updates (reference slash commands) | 5a, 5b | Low |
| 7 | Migration script (Empirica → JSON, verify schema, JSONL fallback) | 1 | Medium |
| 8 | Deprecation (remove Empirica hooks + MCP guidance) | 4, 5c | Low |
| 9 | test.sh updates | 4, 5c, 8 | Low |
| 10 | install.sh updates + settings-example.json | 4, 5c | Low |

## 11. Success Criteria

1. **Hooks fire reliably** — SessionStart hook injects calibration context without error
2. **Preflight/postflight vectors stored** — `epistemic.json` updated on each session
3. **Calibration computes** — Rolling averages computed after ≥5 paired sessions
4. **Behavioral feedback generated** — Instructions are specific, not just numbers
5. **Context-sensitive warnings** — New projects get familiarity warnings
6. **Fail-open verified** — Deleting `epistemic.json` doesn't break session start
7. **jq fallback works** — System degrades gracefully without jq
8. **Migration successful** — 27 paired sessions imported from Empirica
9. **Obsidian integration** — Vector frontmatter written to session notes
10. **Empirica fully removable** — After migration, Empirica MCP can be removed cleanly

## 12. Future Work (Not In Scope)

- **Bayesian upgrade** — When observation count reaches ~15-20 per vector, swap
  rolling averages for Bayesian posterior updating. Data model already supports this.
- **Grounded verification** — Compare self-assessment against objective evidence
  (test results, git metrics). This is Layer 3 from our analysis.
- **Cross-session trend detection** — Detect chronic bias, volatility, evidence gaps
  (calibration insights analyzer from Empirica). Requires grounded verification first.
- **Vector pruning/expansion** — After understanding all 13 vectors deeply, consider
  adding domain-specific vectors or pruning low-signal ones.
