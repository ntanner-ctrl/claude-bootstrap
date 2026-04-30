# AC14 Verification Report

**Test:** AC14 (rev3) — PreToolUse hook warning is visible to Claude
**Date:** 2026-04-30
**Run before:** WU6 implementation (pre-impl gating step per spec.md "Decisions" section)

## Question Under Test

The rev3 spec proposes a PreToolUse shell hook (`hooks/anti-pattern-write-check.sh`) that uses `action: warn` (exit 0 with stderr containing `Catalog: <id>`). The spec acknowledges this needs verification: **does PreToolUse stderr from an exit-0 hook surface to Claude as tool feedback, or does it only reach the user's terminal?**

If it doesn't surface to Claude, the catalog's first consumer is wired-but-silent — AC4 mechanically passes (rule cites a catalog ID) while functionally being theater.

## Method

Three test forms, in increasing reliance on the live Claude Code harness:

| Form | Source of evidence | Strength |
|---|---|---|
| Form 1 | Hook script unit test (stdin pipe) | Verifies the hook PRODUCES the warning |
| Form 2 | Live Claude Code session, hook wired via settings.local.json, observe tool feedback | Verifies the harness PROPAGATES the warning to Claude |
| Form 3 | Canonical docs (code.claude.com/docs/en/hooks) | Verifies the documented contract |

Three exit-code paths were tested:

| Path | Mechanism | Behavior |
|---|---|---|
| A | exit 0 + stderr | Spec's rev3 design |
| B | exit 2 + stderr | Block-with-feedback (used by `protect-claude-md.sh`, `tdd-guardian.sh`) |
| C | exit 0 + stdout JSON with `additionalContext` | Discovered during research; documented but not previously known |

## Form 1 — Hook Unit Tests (PASSED)

A minimal prototype hook implementing the spec's contract was tested via stdin:

| Test | Result |
|---|---|
| Matching `fixture_bad` content emits `Catalog: <id>` to stderr | PASS |
| Non-matching `fixture_good` content produces no stderr | PASS |
| `SAIL_DISABLED_HOOKS=anti-pattern-write-check` disables the hook | PASS |
| Exit code on match | 0 (matches spec's "warn" semantics) |

The hook script behaves exactly as the spec describes.

## Form 2 — Live Harness Tests

### Path A: exit 0 + stderr → **NOT visible to Claude**

Wired a minimal warn-only hook into `.claude/settings.local.json` PreToolUse Write|Edit. Made a Write to a path matching the hook's filter. The hook fired (verified by side-channel log file timestamp). The stderr marker `AC14_MARKER_EXIT0_FIRED__warn_path` was **NOT** present in the tool feedback I (Claude) received. Tool result was just `File created successfully at: ...`.

**Evidence:** `/tmp/ac14-hook-log.txt` line 2 records the hook firing at the exact timestamp of the Write attempt. My tool result for that Write contains no marker text.

**Conclusion:** stderr from `exit 0` PreToolUse hooks goes to the user's terminal; Claude does not see it. The rev3 spec's `action: warn` mechanism is invisible to Claude.

### Path B: exit 2 + stderr → **Visible to Claude**

Wired a block-with-feedback hook on a different filter. Made a Write to that path. The tool feedback surfaced **as a `PreToolUse:Write hook error`** containing the markers `AC14_MARKER_EXIT2_FIRED__block_path` and `AC14_MARKER_EXIT2_LINE2: this should reach Claude as feedback`.

**Conclusion:** exit 2 + stderr propagates to Claude — but the price is blocking the tool call. This matches the established convention in `protect-claude-md.sh` and `tdd-guardian.sh` (both line ~93–101).

### Path C: exit 0 + stdout JSON with `additionalContext` → **Inconclusive in-session**

Wired a hook that outputs structured JSON to stdout with the documented format:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "additionalContext": "anti-pattern detected\n  Catalog: <id>"
  }
}
```

Hook script unit-tested cleanly (valid JSON, correct structure). However, in-session Write attempts did not fire the new hook — the existing hooks list appears to be cached at session start. The earlier warn/block hooks fired only because they were the wired-at-cache-time hooks. The new additionalContext hook would require a fresh session to verify.

**Side finding:** Settings.local.json hooks are loaded at session start and not reloaded mid-session. This is itself useful for documenting the toolkit's hook lifecycle.

## Form 3 — Canonical Docs Confirmation

`https://code.claude.com/docs/en/hooks` — PreToolUse JSON output schema:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow" | "deny" | "ask" | "defer",
    "permissionDecisionReason": "...",
    "updatedInput": { ... },
    "additionalContext": "..."
  }
}
```

> "`additionalContext` – String added to Claude's context alongside the tool result."

> "When several hooks return `additionalContext` for the same event, Claude receives all of the values."

The docs confirm Path C as the canonical mechanism for warn-with-visibility: exit 0, allow the tool call, surface text to Claude via `additionalContext`.

## Verdict on AC14

**Path A (rev3 spec's current design) FAILS verification.**

A warn-only PreToolUse hook with `exit 0 + stderr` produces no Claude-visible feedback. WU6 cannot be implemented as specified without breaking AC14's intent.

## Redesign Options for WU6

| Option | Mechanism | Pros | Cons |
|---|---|---|---|
| **C — additionalContext (recommended)** | exit 0 + stdout JSON with `permissionDecision: "allow"` + `additionalContext` | Surfaces to Claude AND user proceeds; matches "warn" intent perfectly; documented; supported as of v2.1.9+ | Requires fresh-session empirical confirmation; hook output shape changes from stderr-text to stdout-JSON |
| B — exit 2 with single-flight approval | Block first, approval file enables retry (like `protect-claude-md.sh`) | Proven to work in this codebase; warning is unmissable | Heavy UX for warn-only; user must approve every detection unless auto-approved; conflicts with toolkit's "warn != block" posture |
| B-light — exit 2 with permissive deny | Block + provide reason; no approval flow, just retry path | Surfaces clearly | Effectively makes the hook block-on-detection — not warn |
| D — Marker file approach | Hook writes warning to `.claude/anti-patterns/.last-warning.txt`; separate mechanism (PostToolUse?) surfaces it | Decouples detection from delivery | Loose; user/Claude has to know to look; timing may not be useful |
| E — Different consumer entirely | Make first consumer a generative reviewer that reads the catalog (e.g., `pr-review-toolkit:silent-failure-hunter` extended), not a hook | Sidesteps the PreToolUse propagation question | Major scope change; describe.md's "first consumer wired at runtime" promise is weaker |

**Strong recommendation: Option C (additionalContext).**

Rationale:
1. It's the documented contract for exactly this use case.
2. It preserves "warn" semantics: tool call proceeds, Claude sees the warning.
3. It's the cleanest delta from the rev3 spec — only the hook's output format changes (stderr → stdout JSON), the rest of the architecture stays.
4. It supports multi-pattern citation natively (multiple hooks can each add context).
5. Empirical verification is one fresh-session test away.

## Required spec updates (rev4)

Treat as a **rev3 → rev4 polish** since this is mechanism-correctness, not redesign:

1. **`spec.md` Hook Script Contract section**: change output mechanism from "exit 0 + stderr `Catalog: <id>`" to "exit 0 + stdout JSON `{hookSpecificOutput: {hookEventName: 'PreToolUse', permissionDecision: 'allow', additionalContext: '...'}}`".
2. **`spec.md` "Decisions" section, Why warn-only PreToolUse**: replace "needs explicit verification" anchor with "Verified — additionalContext mechanism propagates to Claude. Stderr-only path was tested and confirmed invisible (see ac14-verification.md)."
3. **`tests.md` AC14**: update the form-1 unit test to assert hook outputs valid JSON to stdout containing the citation, not stderr text. Form-2 still requires fresh-session manual verification, but the question is now narrower (does additionalContext propagate? — docs say yes).
4. **No regression to specify** — the architectural choice (PreToolUse hook as first consumer, citing catalog IDs) is unchanged. Only the output format shifts.

## Side findings recorded for the toolkit

These are not part of the anti-pattern-catalog blueprint but were discovered during this verification. Worth noting somewhere stable (CLAUDE.md or hook authoring docs):

1. **Hook output channel matrix** — useful reference for future hook authors:

   | Goal | Mechanism |
   |---|---|
   | Block + tell Claude why | `exit 2 + stderr` |
   | Allow + tell Claude something | `exit 0 + stdout JSON additionalContext` |
   | Allow silently (most hooks) | `exit 0 + no output` |
   | Allow + tell *user* (not Claude) | `exit 0 + stderr` — works but Claude doesn't see |
   | Modify tool input before execution | `exit 0 + stdout JSON updatedInput` |

2. **Settings.local.json hooks are session-locked** — added/changed hooks in settings.local.json don't take effect until next session start. This matters for hook development: the "edit-and-test" loop requires session restarts, not just reload.

3. **`exit 2` is heavyweight for warn-only patterns** — the existing toolkit hooks (`protect-claude-md`, `tdd-guardian`) use exit 2 because they actually want to block. Hooks designed for "advisory" roles should prefer additionalContext, not stderr.

## Disposition

- AC14 (rev3 wording) status: **FAIL on Path A; PASS-pending-fresh-session on Path C**
- Blueprint status: HOLD on Execute / WU6 until rev4 spec edits applied
- All other WUs (WU1, WU2, WU3, WU4, WU5, WU7) are unblocked — rev4 only touches the hook contract section
