# Toolkit Hardening — Specification (Revision 2)

> **Revision 2** — Regression from Stage 3 (Challenge). Addresses 15 findings from debate:
> F2/M1 (guardian livelock → exemption list), F1 (PPID fallback → user+dir hash),
> F3 (catchall → enumerated patterns), F4 (calibration → anchored examples),
> F5 (self-referential → independence check), F6 (dead files → deterministic export),
> F7 (free-text summary → structured template), F10 (stale files → TTL + cleanup),
> M2 (verified CTX_INT), M3 (checkpoint-done signal), M4 (integration test),
> M5 (Light path → shortened gate), F9 (atomic edit pass).
> F8 (traps unenforceable) accepted as-is — traps are compliance layer, not enforcement.

## Overview

Six improvements to the claude-bootstrap toolkit, addressing compaction resilience, planning rigor, behavioral correction, and knowledge lifecycle. Sourced from competitive research (Ouroboros, GodMode) and operational pain points.

**Implementation Phases:**
```
Phase A (foundation):  1-Compaction Guardian + 3-Cognitive Traps    [parallel]
Phase B (blueprint):   2-Ambiguity Gate + 5-Wonder/Reflect          [serial]
Phase C (behavioral):  4-Failure Counter                            [independent]
Phase D (capstone):    6-Knowledge Maturation                       [depends on A+B]
```

---

## Component 1: Compaction Guardian

### Problem

Empirica session state (session ID, preflight vectors, plan context) lives only in conversation context. When auto-compaction triggers at **85% of context window**, this state is lossy-compressed and often lost entirely. The checkpoint command exists but is manual — nothing forces its use before compaction strikes.

### Design

**Architecture: Cross-hook communication via signal files.**

Two hooks cooperate:
1. `statusline.sh` (event-driven, invoked by Claude Code on each status update cycle) — **writes** signal files when thresholds crossed
2. `compaction-guardian.sh` (new PreToolUse hook) — **reads** signal files and gates tool calls

```
statusline.sh (event-driven, invoked per status cycle)
  │
  ├─ CTX_INT >= 65  → write /tmp/.claude-ctx-warning-$$
  ├─ CTX_INT >= 75  → write /tmp/.claude-ctx-critical-$$
  └─ CTX_INT < 75   → remove warning AND critical signal files if they exist
                       (cleanup at < 75 rather than < 65 prevents stale critical
                        files from persisting when context drops below gate but
                        above warning — avoids false guardian triggers on re-entry)

compaction-guardian.sh (PreToolUse, matcher: *)
  │
  ├─ Tool call is on EXEMPTION LIST?  → pass (exit 0) immediately
  │   (see Guardian Exemption List below)
  │
  ├─ /tmp/.claude-ctx-critical-* exists?
  │   ├─ Recent checkpoint signal exists (< 5 min)?  → pass (exit 0)
  │   │   (checks /tmp/.claude-checkpoint-done-<PPID>)
  │   └─ No recent checkpoint?
  │       → exit 2 (stderr message to Claude):
  │         "Context at [N]%. Auto-compaction triggers at 85%.
  │          DELEGATE checkpoint to a subagent to preserve context.
  │          Empirica session: [id from state.json or 'not found']
  │          Active plan: [name from state-index.json or 'none']
  │          NOTE: Agent, Bash(/checkpoint), and Write(.checkpoint)
  │          calls are exempted from this gate."
  │
  └─ /tmp/.claude-ctx-warning-* exists?
      → pass (exit 0) but stderr advisory:
        "Context at [N]%. Consider /checkpoint soon."
```

### Threshold Rationale

| Threshold | Statusline % | Remaining before 85% compaction | Purpose |
|-----------|-------------|--------------------------------|---------|
| Warning | 65% | ~20% (~40k tokens) | Advisory only, printed to stderr as info |
| Critical/Gate | 75% | ~10% (~20k tokens) | Blocks tool calls until checkpoint taken |
| Auto-compaction | 85% | 0% | Claude Code built-in, we can't control this |

The 10% gap between gate (75%) and compaction (85%) provides ~20k tokens of runway for the checkpoint process: reading state files, writing JSON, optional Empirica calls, and the tool call overhead itself.

### Guardian Exemption List (F2/M1 fix)

The guardian MUST NOT block tool calls that are part of the checkpoint escape path. The hook parses the tool name from stdin JSON and exempts:

| Tool | Why Exempted |
|------|-------------|
| `Agent` | Subagent dispatch for lifeboat checkpoint |
| `Bash` (if command contains `/checkpoint` or `checkpoint.sh`) | Inline checkpoint fallback |
| `Write` (if path contains `.checkpoint` or `checkpoints/`) | Direct checkpoint file writes |
| `Read` (if path contains `state.json`, `manifest.json`, `state-index.json`) | State reads needed for checkpoint |
| `Skill` (if skill is `checkpoint`) | Skill-based checkpoint invocation |

**Implementation:** The hook reads `tool_name` from the PreToolUse JSON. For `Bash`, it also reads the `command` field. For `Write`/`Read`, it reads the `file_path` field. Exemption checks are simple string matches (contains), not regex — fast and predictable.

**Non-exempted tools remain blocked.** Claude cannot call Edit, Grep, Glob, or any other tool until checkpoint completes. This prevents Claude from "just doing one more thing" before checkpointing.

### Checkpoint Completion Signal (M3 fix)

When a checkpoint completes (via any path — subagent, inline, or emergency), the checkpoint process writes:

```
/tmp/.claude-checkpoint-done-<PPID>
```

Contents: Unix timestamp of completion. The guardian reads this file and passes (exit 0) if it's less than 5 minutes old. This prevents the guardian from re-triggering immediately after a successful checkpoint.

**Who writes this signal:**
- Subagent lifeboat: the subagent writes it as its last action before returning
- Inline `/checkpoint`: the checkpoint command writes it after saving JSON
- Emergency fallback: written alongside the emergency signal file

**TTL:** 5 minutes. After that, if context is still above 75%, the guardian fires again. This handles the case where a checkpoint was taken but the session continued working and context grew further.

### Subagent Lifeboat Strategy

**Key insight:** Subagents get their own isolated context windows. The parent's context is only charged for the prompt sent and the result received — not the subagent's internal work.

When the guardian triggers at 75%, the exit 2 message should instruct Claude to **delegate the checkpoint to a subagent** rather than running it inline:

```
"Context at [N]%. Auto-compaction triggers at 85%.
 DELEGATE checkpoint to a subagent to avoid consuming remaining context.

 Subagent prompt should include:
   - Empirica session: [id from state.json]
   - Active plan: [name from state-index.json]
   - Plan directory: [path]
   - Signal path: /tmp/.claude-checkpoint-done-[PPID]
     (literal path — subagent writes HERE, not its own $PPID)

 The subagent reads state files, writes checkpoint JSON, and optionally
 calls Empirica. The parent receives only the compact result.

 If subagent dispatch fails, fall back to inline /checkpoint."
```

**Why this matters:** The inline checkpoint process (reading state.json, manifest.json, writing checkpoint JSON, calling Empirica finding_log) itself consumes context. At 75%, spending 3-4% of window on checkpoint mechanics could push the parent past 85% *while trying to save state from compaction*. The subagent approach burns only the prompt + result (~0.5% of window) in the parent context.

**Fallback chain:**
1. Subagent checkpoint (preferred — minimal parent context cost)
2. Inline `/checkpoint` (if subagent dispatch fails)
3. Minimal signal write to `/tmp/.claude-checkpoint-emergency-<PPID>` (if checkpoint itself fails — just the session ID and plan name, enough to resume)

### Signal File Format

```
/tmp/.claude-ctx-warning-<PPID>     # PPID = parent process (Claude Code session)
/tmp/.claude-ctx-critical-<PPID>
```

Contents: single line with the percentage, e.g., `72`. This allows the guardian hook to include the actual percentage in its message without re-parsing stdin.

**Why PPID not PID:** The statusline hook runs as a child process of Claude Code. Each invocation gets its own PID but shares the same PPID (the Claude Code session). The guardian hook also runs as a child of the same session. Using PPID ensures both hooks reference the same signal files.

**Fallback for unreliable PPID (F1 fix):** If `$PPID` is 1 (init — indicates containerized/orphaned process), fall back to `/tmp/.claude-ctx-critical-$USER-$(pwd | md5sum | cut -c1-8)`. This uses the username + working directory hash as a secondary discriminator, providing session isolation even without a stable PPID. Two sessions in different directories get different signal files. Two sessions in the same directory may collide, but this is an acceptable edge case (same user, same project = likely the same work).

### Signal File TTL and Cleanup (F10 fix)

All signal files include a Unix timestamp as the second line:
```
75
1709913600
```

**TTL rules:**
- Warning signal files: 10-minute TTL (advisory, low cost of staleness) — timestamp on line 2
- Critical signal files: 30-minute TTL (blocking, higher cost but still bounded) — timestamp on line 2
- Checkpoint-done signal files: 5-minute TTL (short-lived by design) — timestamp on line 1 (single-line format, no percentage)

**Note:** The guardian's TTL check must handle both formats: for ctx-warning/ctx-critical, read line 2 for timestamp; for checkpoint-done, read line 1.

The guardian hook checks the timestamp before acting. If the signal file is older than its TTL, the hook ignores it (treats as stale) and removes it.

**SessionEnd cleanup:** Add to `session-end-cleanup` logic:
```bash
rm -f /tmp/.claude-ctx-warning-$PPID /tmp/.claude-ctx-critical-$PPID /tmp/.claude-checkpoint-done-$PPID /tmp/.claude-debug-reset-$PPID /tmp/.claude-guardian-heartbeat-$PPID /tmp/.claude-fail-count-$PPID 2>/dev/null
```

This handles clean exits. Crashes leave stale files, which the TTL check handles.

### Checkpoint Enrichment

The existing checkpoint JSON (from `checkpoint.md`) needs two new fields:

```json
{
  "timestamp": "ISO-8601",
  "summary": "...",
  "decisions": [...],
  "next_action": "...",
  "blockers": [],
  "context": {
    "active_plan": "...",
    "active_plan_stage": "...",
    "active_tdd_phase": "...",
    "files_in_progress": [...]
  },
  "empirica": {
    "session_id": "uuid or null",
    "preflight_complete": true,
    "last_finding_count": 5
  },
  "compaction_context": {
    "triggered_by_guardian": true,
    "context_percentage_at_checkpoint": 76,
    "key_context": {
      "current_task": "Implementing JWT refresh token rotation",
      "blocking_question": "Whether to use sliding or fixed expiry windows",
      "last_file_edited": "src/auth/refresh.ts",
      "next_intended_action": "Write the token rotation middleware",
      "confidence_caveat": "At 76% context — early conversation details may already be compressed"
    }
  }
}
```

**Atomic write requirement (B7 fix):** Checkpoint JSON MUST be written atomically: write to a temp file first (`checkpoint.json.tmp`), then rename to `checkpoint.json`. This prevents partial reads if the guardian or a subagent reads the checkpoint mid-write. On read, validate that the JSON parses before trusting it — if parse fails, fall back to `.tmp` file or log a warning.

The `compaction_context` block is only populated when the checkpoint is triggered by (or in response to) the compaction guardian. The `key_context` object replaces the previous free-text `key_context_summary` field (F7 fix) with a structured template:

- **`current_task`**: What you're doing right now (max 100 chars)
- **`blocking_question`**: The open question that matters most for resumption (max 150 chars)
- **`last_file_edited`**: Most recent file path — concrete anchor for the next session
- **`next_intended_action`**: What you were about to do (max 100 chars)
- **`confidence_caveat`**: Mandatory epistemic honesty — state what you might have lost

The structured template forces prioritization (can't ramble) and the `confidence_caveat` field explicitly asks Claude to acknowledge its degraded context state, so the post-compaction reader knows to verify rather than trust blindly.

### Statusline Integration Verification (M2 fix)

The statusline hook already parses `context_window.used_percentage` from Claude Code's JSON stdin (line 19 of `statusline.sh`). This is confirmed by reading the existing hook — `CTX_INT` is extracted via jq and used for the context bar display. The threshold logic will use this same variable.

**Verified:** `CTX_INT` is available in every statusline invocation. If jq parsing fails, `CTX_INT` defaults to 0 (line 42: `CTX_INT=${CTX_PCT%.*}; CTX_INT=${CTX_INT:-0}`), which means the guardian never fires on parse failure — correct fail-open behavior.

### Guardian Heartbeat (PM1 fix)

On every invocation, the guardian writes `/tmp/.claude-guardian-heartbeat-<PPID>` with a Unix timestamp. This is a diagnostic artifact only — nothing reads it automatically. Its purpose: when debugging "why didn't the guardian fire?", check if the heartbeat file exists. If yes, the guardian is running but thresholds weren't crossed. If no, the guardian isn't being invoked (settings.json misconfigured, hook file missing, etc.). This distinguishes "all clear" from "silently broken."

The heartbeat write is the FIRST action in the hook, before any threshold checks — even if everything else fails, the heartbeat confirms the hook was invoked.

### Changes Required

| File | Change |
|------|--------|
| `hooks/statusline.sh` | Add signal file writes in threshold section (after line 116) |
| `hooks/compaction-guardian.sh` | **New file.** PreToolUse hook with exemption list, ~80 lines |
| `commands/checkpoint.md` | Add `empirica` and `compaction_context` to JSON schema; write checkpoint-done signal |
| `settings-example.json` | Add PreToolUse entry for compaction-guardian.sh (matcher: `*`) |
| `hooks/session-end-*.sh` | Add signal file cleanup |
| `install.sh` | Hook count update (20 → 21) |

### Acceptance Criteria

1. When context reaches 65%, a warning appears in Claude's stderr (advisory, no blocking)
2. When context reaches 75%, non-exempted tool calls are blocked with exit 2
3. **Exempted tool calls (Agent, checkpoint-related Bash/Write/Read, Skill:checkpoint) pass through the gate** (F2/M1 fix)
4. The checkpoint includes Empirica session ID and structured `key_context` (not free-text)
5. After checkpoint completes, a checkpoint-done signal file allows subsequent tool calls for 5 minutes (M3 fix)
6. Signal files are scoped via PPID with user+directory fallback for unreliable PPID (F1 fix)
7. Signal files have TTL; stale files are ignored and cleaned up (F10 fix)
8. SessionEnd cleans up all signal files for the current session
9. If no signal files exist, the guardian hook is a no-op (exit 0, zero overhead)
10. The guardian follows fail-open: if signal file reads or jq parsing fails, exit 0
11. Guardian writes a heartbeat file on every invocation for liveness diagnostics (PM1 fix)
12. Each new hook includes a documented disable procedure in its file header comment (PM2 fix): "To disable: remove the [PreToolUse/PostToolUse] entry for [filename] from ~/.claude/settings.json"

---

## Component 2: Ambiguity Gate

### Problem

Blueprint's describe→specify transition has no readiness check. Under-specified descriptions proceed to spec generation, where ambiguity becomes baked into the spec and is only caught later (if at all) by adversarial review. Ouroboros demonstrated that front-loading clarity (via quantified ambiguity scoring) catches problems earlier and cheaper.

### Design

**A lightweight scoring gate between Stage 1 (Describe) and Stage 2 (Specify) in the blueprint workflow.**

After the describe stage completes and before the specify stage begins, Claude self-scores the description across three dimensions:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  AMBIGUITY CHECK │ Before proceeding to Specify
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Scoring the description across three dimensions:

  Goal Clarity       [?/5] — Is the desired outcome unambiguous?
                              Can two people read this and agree
                              on what "done" looks like?

  Constraint Clarity  [?/5] — Are boundaries explicit?
                              What's in scope vs out of scope?
                              What can't change?

  Success Criteria    [?/5] — Are acceptance criteria testable?
                              Could you write a test for "done"
                              without asking clarifying questions?

  Composite Score: [weighted average] / 5.0
    (Goal: 40%, Constraint: 30%, Success: 30%)

  Threshold: >= 3.5 to proceed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Gate Behavior

| Score | Action |
|-------|--------|
| >= 3.5 | Pass. Proceed to Specify. |
| 2.5 - 3.4 | Warn. Present specific ambiguities. Ask user to clarify OR override with reason. |
| < 2.5 | Block. "This description isn't ready for specification. Here's what's unclear: [list]." User must clarify or explicitly override. |

**Override mechanism:** User can always say "proceed anyway" — this is logged in `state.json` as:
```json
{
  "ambiguity_gate": {
    "scores": { "goal": 3, "constraint": 2, "success": 2 },
    "composite": 2.4,
    "result": "blocked",
    "override": true,
    "override_reason": "Constraints will emerge during spec — this is exploratory"
  }
}
```

### Scoring Prompt

Claude scores itself using this internal prompt (not shown to user):

```
Review the describe stage output and score each dimension 1-5:

GOAL CLARITY (1-5) — with calibration examples (F4 fix):
  1 = Vague aspiration. Example: "Make auth better"
  2 = General direction but ambiguous outcome. Example: "Add token refresh"
  3 = Clear outcome, some interpretation needed. Example: "Add JWT refresh tokens so sessions don't expire during use"
  4 = Specific outcome, minimal ambiguity. Example: "Add JWT refresh token rotation with configurable expiry"
  5 = Unambiguous, two people would agree on "done". Example: "Add JWT refresh token rotation: 7-day expiry, sliding window, revocation on password change"

CONSTRAINT CLARITY (1-5):
  1 = No constraints mentioned. Example: (nothing about scope, compatibility, or limits)
  2 = Implied constraints only. Example: "Should work with existing auth" (what existing auth?)
  3 = Some explicit constraints, gaps remain. Example: "Must work with our Express middleware. No breaking API changes."
  4 = Clear boundaries, scope defined. Example: "In scope: token rotation. Out of scope: SSO, OAuth providers. Must maintain backwards compat with v2 API."
  5 = Explicit in/out scope, unchangeables named. Example: Full scope table with explicit "will not change" list.

SUCCESS CRITERIA (1-5):
  1 = No criteria. Example: "It should work"
  2 = Subjective criteria. Example: "Auth should feel seamless"
  3 = Some testable criteria, some subjective. Example: "Tokens refresh without user action; auth feels smooth"
  4 = Mostly testable criteria. Example: "Refresh token issued on login; auto-refreshes when access token < 5min from expiry; refresh token rotated on each use"
  5 = All criteria are testable assertions. Example: Each criterion maps to a specific test case with inputs and expected outputs.

For each dimension, cite the specific text from the describe output that supports your score.
If you can't find supporting text, that IS the score evidence (it's missing).
IMPORTANT: Compare the describe output to the calibration examples above. Your score should match the example level that most closely resembles the text.
```

### Why Self-Scoring Works Here (and confidence gating doesn't)

The user correctly identified that self-assessed confidence is unreliable for "should I check myself?" decisions. But ambiguity scoring is different:

- **Confidence** asks "how right am I?" — Dunning-Kruger applies directly
- **Ambiguity** asks "is the INPUT clear?" — this is about the text on the page, not Claude's understanding
- A description that says "make auth better" is objectively more ambiguous than one that says "add JWT refresh token rotation with 7-day expiry" regardless of how confident Claude is about either

The scoring is grounded in observable textual evidence ("cite the specific text"), not self-assessed understanding. It's still imperfect — Claude can rationalize high scores — but the failure mode is much less dangerous than confidence-gated debate skipping.

### Changes Required

| File | Change |
|------|--------|
| `commands/blueprint.md` | Add ambiguity gate section between Stage 1 and Stage 2 transitions |
| `.claude/plans/*/state.json` | Add `ambiguity_gate` field to schema |

### Acceptance Criteria

1. After Stage 1 completes, the ambiguity gate scores the description before allowing Stage 2
2. Scores are presented to the user with supporting evidence citations
3. Score >= 3.5 passes automatically; 2.5-3.4 warns; < 2.5 blocks
4. User can always override with a logged reason
5. Gate adds ~30 seconds to the workflow, not minutes
6. On Light path, run a **shortened gate** (M5 fix): score Goal Clarity only (the single most impactful dimension). If Goal Clarity < 3, warn. This catches "make it better" descriptions even on abbreviated paths without adding the full 3-dimension gate overhead. The rationale: Light path users are already abbreviating the process, so they're the most likely to have under-specified goals. **Known gap:** Constraint Clarity and Success Criteria are intentionally not checked on Light path to preserve its lightweight nature. Under-specified constraints can pass the shortened gate — this is an accepted tradeoff.

---

## Component 3: Cognitive Trap Tables

### Problem

Claude rationalizes skipping critical commands. Current enforcement uses description-tier language ("STOP. You MUST...") but doesn't preempt the *specific excuses* Claude generates. GodMode demonstrated that listing known rationalizations with explicit counters significantly improves compliance.

### Design

**A markdown table added to MUST-tier and Safety-Critical commands that lists known rationalizations and their counters.**

Format:
```markdown
## Cognitive Traps

Before skipping or simplifying this command, check yourself:

| Rationalization | Why It's Wrong |
|----------------|---------------|
| "This is too simple for /blueprint" | Simple-looking tasks have the highest rate of confident mistakes. If you can't articulate why it's simple, it isn't. |
| "Those test failures are pre-existing" | You don't know that without checking. Run the tests, compare to baseline. Pre-existing failures are documented; unknown ones are yours. |
| "I already know the answer" | Knowledge is not the same as verification. The process exists to catch what you're confident about but wrong. |
```

### Tables Per Command

**`blueprint.md`** — Traps for skipping planning:

| Rationalization | Why It's Wrong |
|----------------|---------------|
| "This is too simple for a blueprint" | Simple tasks have the highest confident-mistake rate. The describe stage takes 2 minutes. The mistake it prevents takes 20. |
| "I'll just do it and fix issues later" | Fixing is always more expensive than preventing. You're trading 5 minutes of planning for 30 minutes of debugging. |
| "The user seems to want speed" | The user wants *correct results* quickly. A fast wrong answer wastes more time than a slightly slower right one. |
| "I already explored this in conversation" | Conversation exploration ≠ structured decomposition. The blueprint forces you to make implicit assumptions explicit. |

**`push-safe.md`** — Traps for skipping push safety:

| Rationalization | Why It's Wrong |
|----------------|---------------|
| "I already checked the diff" | You checked your *intent*. Push-safe checks the *reality* — secrets, large files, force-push targets. These are different checks. |
| "It's just a small change" | Small changes to CI/CD, auth, or config can have outsized blast radius. Size ≠ risk. |
| "We're in a hurry" | Pushing a secret to a public repo creates an emergency that dwarfs any time saved by skipping checks. |

**`test.md`** — Traps for skipping tests:

| Rationalization | Why It's Wrong |
|----------------|---------------|
| "Those test failures are pre-existing" | Prove it. Run the tests on the base branch. If you can't, you can't claim they're pre-existing. |
| "The change is too small to break anything" | The smallest changes cause the most surprising failures. A one-character typo can break a build. |
| "I'll write tests after" | "After" never comes. Tests written alongside code catch design issues; tests written after just verify the (possibly wrong) implementation. |

**`quality-gate.md`** — Traps for skipping quality checks:

| Rationalization | Why It's Wrong |
|----------------|---------------|
| "The code works, that's enough" | Working code that's unmaintainable, insecure, or untested creates technical debt that compounds. |
| "We already reviewed in the challenge stage" | Challenge reviewed the *spec*. Quality gate reviews the *implementation*. Specs can be correct while implementations diverge. |

### Placement

The trap table goes immediately after the `description` frontmatter and before the main content — it's the first thing Claude reads when invoking the command. This is intentional: it primes self-checking before the workflow begins, not after Claude has already decided to skip.

```markdown
---
description: STOP. You MUST...
---

## Cognitive Traps

[table here]

# [Command Name]

[rest of command...]
```

### Changes Required

| File | Change |
|------|--------|
| `commands/blueprint.md` | Add trap table after frontmatter |
| `commands/push-safe.md` | Add trap table after frontmatter |
| `commands/test.md` | Add trap table after frontmatter |
| `commands/quality-gate.md` | Add trap table after frontmatter |

### Acceptance Criteria

1. Each MUST-tier command has a trap table with 3-4 entries
2. Tables are placed between frontmatter and main content
3. Each rationalization has a specific, grounded counter (not generic "don't skip")
4. The "pre-existing test failures" trap is specifically included (user-flagged)
5. Tables don't add more than ~20 lines to each command file

---

## Component 4: Failure Counter Escalation

### Problem

Claude sometimes enters edit-test-fail loops, making the same category of fix repeatedly without stepping back to analyze the root cause. There's no mechanism to detect this pattern and force a change in approach. GodMode's failure counter with escalation thresholds directly addresses this.

### Design

**A PostToolUse hook that tracks consecutive test/build failures and escalates when thresholds are hit.**

### Counter Mechanism

**What counts as a "failure" (F3 fix — enumerated patterns only, no catchall):**
- Bash tool call with non-zero exit code where the command matches ONLY these specific patterns:
  - Test runners: `npm test`, `npx test`, `yarn test`, `bun test`, `pytest`, `python -m pytest`, `cargo test`, `go test`, `jest`, `vitest`, `npx jest`, `npx vitest`
  - Build tools: `npm run build`, `yarn build`, `bun build`, `cargo build`, `make` (without arguments or with standard targets like `all`, `build`, `test`), `tsc`, `tsc --build`
- The match checks whether the **command string starts with** any listed pattern (after stripping leading whitespace). This is prefix matching, not substring matching. `test -f somefile` does NOT match (no pattern starts with bare `test `). `build/run.sh` does NOT match. `make test_data` does NOT match (`make` only matches with no args or with `all`/`build`/`test` targets).
- New frameworks are added explicitly — no broad catchall. This eliminates the false-positive class entirely at the cost of missing novel test runners (acceptable: Yellow/Orange on unknown frameworks isn't worth the false-positive risk on Red).

**What resets the counter:**
- A successful (exit 0) test/build command (matched by the same pattern list)
- A `/debug` invocation — detected via signal file `/tmp/.claude-debug-reset-<PPID>` written by the `/debug` command. The hook checks for this file's existence before incrementing; if present, it resets the counter and removes the file.
- User explicitly says "reset counter" or equivalent

**Why signal file for /debug detection:** The hook cannot read state-index.json reliably (race conditions, file may not exist yet). A signal file is the same proven pattern used by the compaction guardian — lightweight, session-scoped, no coordination needed.

**Where the counter lives:**
Signal file at `/tmp/.claude-fail-count-<PPID>`. Contents: integer count. This is the same pattern as the compaction guardian — lightweight, session-scoped, no persistent state needed.

### Escalation Thresholds

| Level | Count | Color | Action |
|-------|-------|-------|--------|
| Green | 0-1 | — | Normal operation |
| Yellow | 2 | Warning | stderr: "2 consecutive failures on [test/build]. Consider a different approach." |
| Orange | 3 | Stronger | stderr: "3 consecutive failures. Stop and analyze: is this the same root cause? Run /debug if stuck." |
| Red | 4+ | Blocking | exit 2: "4+ consecutive failures on the same type of command. You MUST run /debug or explain your approach to the user before continuing to retry." |

### Hook Implementation

**Matcher:** `Bash` (PostToolUse)

```bash
#!/bin/bash
# failure-escalation.sh — PostToolUse hook for Bash
# Tracks consecutive test/build failures, escalates at thresholds
set +e

# Read tool result from stdin (NOT env var — Claude Code hooks receive JSON on stdin)
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
EXIT_CODE=$(echo "$INPUT" | jq -r '.exit_code // 0' 2>/dev/null)
COMMAND=$(echo "$INPUT" | jq -r '.command // empty' 2>/dev/null)

# Only track test/build commands
[regex match check for test/build patterns]

# If success, reset counter
# If failure, increment and check thresholds
```

### Known Limitations (Edge Case Findings B3, B4, B6)

- **Compound commands (B3):** `cd /project && npm test` won't match the prefix check because the command starts with `cd`, not `npm test`. This is intentional — parsing compound shell commands is fragile and error-prone. The prefix match catches the overwhelmingly common case (direct invocations). Users who chain test commands with `&&` or `;` may not trigger escalation.
- **Piped commands (B4):** `npm test | tee output.log` may report exit code 0 (from `tee`) even if `npm test` failed, unless `pipefail` is set. The hook cannot control the user's shell settings. This is an accepted false-negative — the test failure won't be counted, but no harm is done.
- **First tool call gap (B6):** The statusline hook runs event-driven. If the very first tool call in a session occurs before the first statusline update, the signal files won't exist yet. This is a sub-second window and has no practical impact — the guardian is a no-op when no signal files exist.

**Why PostToolUse and not hookify rule:** Hookify rules are prompt-based — they advise but can't block. The escalation needs a *deterministic* block at Red level (exit 2). Only a shell hook can do this. The hook uses enumerated pattern matching against known test/build commands, eliminating the false-positive class that a broad catchall would create.

### Interaction with Compaction Guardian

Both hooks use the same signal-file-per-PPID pattern. They don't interact — the failure counter is orthogonal to context window usage. But if both fire simultaneously (context high + repeated failures), the compaction guardian takes priority (PreToolUse blocks before PostToolUse can advise).

### Changes Required

| File | Change |
|------|--------|
| `hooks/failure-escalation.sh` | **New file.** PostToolUse hook, ~50 lines |
| `settings-example.json` | Add PostToolUse entry for failure-escalation.sh (matcher: `Bash`) |
| `install.sh` | Hook count update |

### Acceptance Criteria

1. Consecutive test/build failures are counted per session
2. Yellow (2) and Orange (3) produce advisory stderr messages
3. Red (4+) blocks further **matched test/build** Bash calls with exit 2 until `/debug` is invoked or counter resets (non-matched Bash commands are never blocked — see criterion 6)
4. Successful test/build resets the counter to 0
5. Counter is session-scoped (PPID signal file) and doesn't persist across sessions
6. The hook is a no-op for non-test/non-build Bash commands (exit 0, minimal overhead)
7. Follows fail-open: if parsing fails, exit 0
8. Hook file header includes documented disable procedure (PM2 fix)

---

## Component 5: Wonder/Reflect Phase

### Problem

Blueprint is a single-pass workflow: plan → implement → done. There's no structured moment to capture what was learned during implementation and feed it back. Ouroboros demonstrated that post-execution reflection ("Wonder: what don't we know?" + "Reflect: how should the spec evolve?") closes a real learning loop.

### Design

**A new optional Stage 7.5 in the blueprint workflow, after Execute completes but before the blueprint is marked fully done.**

### Stage Flow Update

```
Stage 7: Execute     → Implementation
Stage 7.5: Reflect   → Post-implementation learning capture  [NEW]
Stage 8: Complete     → Vault export, cleanup (renumbered from implicit)
```

Actually — adding a numbered stage to a well-established workflow creates confusion. Instead: **the reflection is part of Stage 7 completion, not a separate stage.** When Stage 7 (Execute) is about to be marked complete, the reflection fires inline.

### Reflection Prompt

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  POST-IMPLEMENTATION REFLECTION │ [blueprint name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Implementation is complete. Before closing this blueprint,
  capture what was learned.

  WONDER — What surprised you?
  1. What assumption from the spec turned out to be wrong?
  2. What was harder than expected? What was easier?
  3. What would you add to the spec if starting over?
  4. Did any adversarial finding turn out to be more (or less)
     important than rated?

  REFLECT — What should change for next time?
  1. Which spec sections were most useful during implementation?
  2. Which were ignored or irrelevant?
  3. What's one thing the blueprint process missed?
  4. If a similar feature were planned tomorrow, what would you
     tell the planner?

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Output

Written to `.claude/plans/[name]/reflect.md`:

```markdown
# Post-Implementation Reflection

## Wonder (Surprises)

### Assumptions Proven Wrong
- [list]

### Difficulty Calibration
- Harder than expected: [list]
- Easier than expected: [list]

### Spec Gaps (would add if starting over)
- [list]

### Adversarial Finding Recalibration
- F3 (rated medium) was actually critical because [reason]
- F7 (rated high) was a non-issue because [reason]

## Reflect (Process Improvements)

### Most Useful Spec Sections
- [list]

### Least Useful Spec Sections
- [list]

### Blueprint Process Gap
- [description]

### Advice for Next Planner
- [guidance]
```

### Integration Points (F6 fix — deterministic export, not aspirational)

After writing `reflect.md`, the reflection step MUST execute this export sequence (not optional):

1. **Empirica (mandatory if session active):** Iterate the findings list from reflect.md. For each finding in "Assumptions Proven Wrong" and "Spec Gaps", call `finding_log` with prefix "[Reflection]". This is a loop, not a single call — each discrete finding gets its own log entry. If Empirica session is not active, write findings to `.empirica/insights.jsonl` as fallback.

2. **Vault (mandatory if vault available):** Export a summary finding to `Engineering/Findings/YYYY-MM-DD-reflect-[blueprint-name].md` using the finding template. This is ONE note per reflection (not per finding) — it's a summary that links back to the full `reflect.md`.

3. **Knowledge Maturation (Component 6):** The vault finding from step 2 is automatically discoverable by `/promote-finding` via vault search. The Empirica findings from step 1 create the observation count trail. This closes the loop: reflection → vault note + Empirica entries → discoverable by maturation.

**If both Empirica and vault are unavailable:** Write findings to `reflect.md` only and log a warning: "Reflection findings captured locally only — not exported to Empirica or vault."

### Skippability

The reflection is prompted but skippable. On Light/Standard paths, it's suggested but brief. On Full path, it's recommended and the full prompt is shown.

When skipped: `"reflection": { "status": "skipped", "reason": "user declined" }` in state.json.

### Changes Required

| File | Change |
|------|--------|
| `commands/blueprint.md` | Add reflection section to Stage 7 completion flow |
| `.claude/plans/*/reflect.md` | **New artifact** per blueprint |

### Acceptance Criteria

1. After Stage 7 (Execute) completes, the reflection prompt fires before blueprint closure
2. Reflection output is written to `reflect.md` in the blueprint directory
3. Findings are logged to Empirica if session is active
4. Findings are exported to vault if available
5. The reflection is skippable with a reason
6. Reflection does not block blueprint completion — it's a capture step, not a gate

---

## Component 6: Knowledge Maturation Cycle

### Problem

Empirica captures findings and the vault stores them, but there's no progression path from "interesting observation" to "codified project rule." Insights accumulate without promotion or pruning. The user recently pruned large CLAUDE.md files, confirming that unmanaged accumulation is a real problem.

### Design

**A `/promote-finding` command that manages the lifecycle of findings from isolated observation to codified CLAUDE.md rule, with mandatory capacity checking and paired pruning.**

### Maturation Tiers

```
Tier 1: ISOLATED     — Single observation, one session
                        Source: Empirica finding_log, vault notes

Tier 2: CONFIRMED    — Observed 2+ times across sessions
                        Source: Cross-referencing vault findings by similarity

Tier 3: CONVICTION   — 3+ confirmations, consistent pattern
                        Source: User acknowledgment or automatic detection

Tier 4: PROMOTED     — Codified into CLAUDE.md as a project rule
                        Source: /promote-finding command
```

### Promotion Process

```
/promote-finding [finding-text or vault-path]
```

**Step 1: Identify the finding**
- If argument is a vault path: read the finding
- If argument is text: search vault for matching findings
- If no argument: list recent Tier 3 (conviction) findings as candidates

**Step 2: Verify maturation (F5 fix — independence check + user acknowledgment)**
- Check: has this been observed 3+ times? (Search vault for similar findings)
- **Independence assessment:** For each observation, note:
  - Session date and ID
  - Whether the observation was in a DIFFERENT session than the others
  - Whether the observation arose from a DIFFERENT context (different blueprint, different task)
  - Flag if 2+ observations trace to the same original finding (e.g., a reflect.md that was also logged to Empirica = 1 observation, not 2)
- Present the evidence trail with independence markers:
  ```
  Evidence trail for "[finding]":
    [1] 2026-02-15 — Session abc123 — Blueprint: auth-feature    [INDEPENDENT]
    [2] 2026-02-28 — Session def456 — Blueprint: api-refactor    [INDEPENDENT]
    [3] 2026-03-01 — Session def456 — Reflection from [2]        [CORRELATED with #2]

  Independent observations: 2 of 3 (minimum 2 required for Conviction)
  ```
- If fewer than 2 INDEPENDENT observations: warn "Only N independent observations. Promote anyway?"
- **User acknowledgment is REQUIRED at this step** (not just at Step 4). The user must confirm the evidence is valid before the promotion draft is generated.

**Step 3: Capacity check** (CRITICAL)
- Read the target CLAUDE.md file
- Count current lines
- Count current sections
- If > 200 lines: "CLAUDE.md is at [N] lines. Before promoting, identify a stale entry to retire."
- Present candidates for retirement: entries that haven't been referenced in recent sessions, entries that conflict with newer findings, entries that are too specific/situational

**Step 4: Draft the rule**
- Convert the finding into a CLAUDE.md-appropriate rule
- Format: concise, actionable, in the appropriate section
- Show the draft to the user

**Step 5: Paired operation**
- If capacity check flagged: present the retirement candidate alongside the promotion
- User approves both (promote new + retire old) or neither
- This ensures CLAUDE.md doesn't grow unboundedly

**Step 6: Apply**
- Add the new rule to CLAUDE.md (using Edit tool)
- Remove the retired entry (if applicable)
- Log the promotion in vault: `Engineering/Decisions/YYYY-MM-DD-promoted-[slug].md`
- Update the source finding's tier to PROMOTED in vault

### Capacity Rules

| CLAUDE.md Size | Behavior |
|---------------|----------|
| < 150 lines | Promote freely |
| 150-200 lines | Warn: "Getting full. Consider pruning on next promotion." |
| > 200 lines | Require paired retirement before promotion |
| > 300 lines | Block promotion: "CLAUDE.md is too large ([N] lines). Run /vault-curate to triage before promoting." |

### Staleness Detection

A finding is "stale" if:
- It was added > 90 days ago AND
- No recent vault notes or Empirica findings reference the rule text (fuzzy search, last 60 days) AND

Staleness is advisory — the user decides what to retire. The command surfaces candidates, it doesn't auto-delete.

### Changes Required

| File | Change |
|------|--------|
| `commands/promote-finding.md` | **New file.** The promotion command |
| `commands/templates/vault-notes/promotion.md` | **New template.** Decision record for promotions |

### Acceptance Criteria

1. `/promote-finding` walks through the full maturation check: evidence, capacity, draft, paired operation
2. CLAUDE.md capacity is checked before any promotion
3. When over 200 lines, retirement is required before promotion
4. When over 300 lines, promotion is blocked until curation happens
5. Promotions are logged as decision records in the vault
6. The command works without vault (degrades to Empirica-only evidence trail)
7. The command works without Empirica (degrades to vault-only evidence trail)
8. If both vault and Empirica are unavailable, the command still works but warns about limited evidence

---

## Work Graph

```
                    ┌─────────────┐
                    │ Phase A     │
              ┌─────┤ (parallel)  ├─────┐
              │     └─────────────┘     │
              ▼                         ▼
    ┌─────────────────┐     ┌───────────────────┐
    │ 1: Compaction    │     │ 3: Cognitive      │
    │    Guardian       │     │    Traps          │
    └────────┬────────┘     └───────┬───────────┘
             │                       │
             │     ┌─────────────┐   │
             └─────┤ Phase B     ├───┘
                   │ (serial)    │
                   └──────┬──────┘
                          │
              ┌───────────┴───────────┐
              ▼                       ▼
    ┌─────────────────┐     ┌───────────────────┐
    │ 2: Ambiguity    │────▶│ 5: Wonder/Reflect │
    │    Gate          │     │    Phase          │
    └─────────────────┘     └────────┬──────────┘
                                     │
    ┌─────────────────┐              │
    │ 4: Failure      │              │
    │    Counter       │              │
    │  (independent)  │              │
    └─────────────────┘              │
                                     │
                          ┌──────────┴──────────┐
                          │ Phase D (capstone)   │
                          ▼                      │
                ┌───────────────────┐            │
                │ 6: Knowledge      │◀───────────┘
                │    Maturation     │
                └───────────────────┘
```

### Dependencies

| Component | Depends On | Why |
|-----------|-----------|-----|
| 1: Compaction Guardian | Nothing | Foundation layer |
| 2: Ambiguity Gate | Nothing directly, but shares blueprint.md with 5 | Edit coordination |
| 3: Cognitive Traps | Nothing | Independent command augmentation |
| 4: Failure Counter | Nothing | Independent hook |
| 5: Wonder/Reflect | 2 (both modify blueprint.md) | Must be designed in one pass with 2 to get stage flow right |
| 6: Knowledge Maturation | 1 (session survival), 5 (findings production) | Data flow: guardian preserves → reflect produces → maturation promotes |

### Critical Path

**1 → (2+3+5 atomic pass on blueprint.md) → 6** is the critical path.
Component 4 is fully independent and can be done anytime.

### blueprint.md Atomic Edit Pass (F9 fix)

Components 2 (Ambiguity Gate), 3 (Cognitive Traps), and 5 (Wonder/Reflect) all modify `blueprint.md`. To avoid edit conflicts and ensure consistency:

**All three components' blueprint.md changes MUST be implemented in a single edit session:**
1. First: Add Component 3's cognitive trap table (between frontmatter and content — non-structural)
2. Second: Add Component 2's ambiguity gate (between Stage 1 and Stage 2 — structural)
3. Third: Add Component 5's reflection prompt (at Stage 7 completion — structural)

This ordering puts the non-structural change first, then the two structural changes in stage order.

### Phase D Integration Test (M4 fix)

After all components are implemented, verify the end-to-end data flow chain with this acceptance test:

```
1. Start a session with Empirica active
2. Work until context reaches 75% (or simulate by writing signal file)
3. Guardian fires → checkpoint is taken via subagent
4. Verify: checkpoint JSON contains empirica.session_id and structured key_context
5. Complete a blueprint with the reflection phase
6. Verify: reflect.md exists AND Empirica finding_log was called for each finding
7. Run /promote-finding on one of the reflection findings
8. Verify: evidence trail shows the finding, independence is assessed, user is prompted
```

This tests the chain: guardian preserves → reflect produces → maturation promotes.

### Estimated Work Units

| Component | Files | Effort | Type |
|-----------|-------|--------|------|
| 1: Compaction Guardian | 5 | Medium | New hook + statusline mod + checkpoint enrichment |
| 2: Ambiguity Gate | 2 | Small | Blueprint command modification |
| 3: Cognitive Traps | 4 | Small | Command augmentations (tables only) |
| 4: Failure Counter | 3 | Medium | New hook |
| 5: Wonder/Reflect | 2 | Small | Blueprint command modification |
| 6: Knowledge Maturation | 2 | Medium | New command + template |
| **Total** | **~15 unique files** | | |
