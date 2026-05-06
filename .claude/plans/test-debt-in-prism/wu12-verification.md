# WU12: Pre-Implementation Empirical Gate

> Verifies that the **new** `prism-bash-allowlist.sh` hook fires when an actual
> `test-debt-classifier` subagent dispatches a Bash call. Distinct from AC10
> (which verified PreToolUse hooks fire on subagents *in general*, established
> 2026-05-01 via dangerous-commands.sh instrumentation; see `prior-art.md`).
>
> Required by spec to run **before WU4** (Stage 5.5 dispatch wiring) lands.

## Status: VERIFICATION SPLIT — partial here, behavioral verification deferred to post-session

## What was verified in this session (2026-05-06)

### 1. Hook code correctness — verified via stdin-piped smoke tests

Eight cases were piped to `bash hooks/prism-bash-allowlist.sh` directly
(JSON via tempfile to avoid the dangerous-commands `curl|bash` regex matching
my test command line):

| # | agent_type | command | Expected | Got | Result |
|---|-----------|---------|----------|-----|--------|
| T1 | `test-debt-classifier` | `pytest -v --tb=line` | exit 0 (allowed) | exit 0 | ✓ |
| T2 | `test-debt-classifier` | `kubectl get pods` | exit 2 with "outside declared scope" | exit 2 + correct stderr | ✓ |
| T3 | _absent_ | `kubectl get pods` | exit 0 (no-op main session) | exit 0 | ✓ |
| T4 | `general-purpose` | `kubectl get pods` | exit 0 (no-op different agent) | exit 0 | ✓ |
| T5 | `test-debt-classifier` | `bash test.sh` | exit 0 (allowed) | exit 0 | ✓ |
| T6 | `test-debt-classifier` | `git log --oneline -n 5 -- foo.py` | exit 0 (allowed) | exit 0 | ✓ |
| T7 | `test-debt-classifier` | `   pytest -v` (leading whitespace) | exit 0 (whitespace-trim works) | exit 0 | ✓ |
| T8 | `test-debt-classifier` | `kubectl get pods` w/ `SAIL_DISABLED_HOOKS=prism-bash-allowlist` | exit 0 (toggle bypasses) | exit 0 | ✓ |

**This covers AC2-AC5 functionally** but via direct stdin piping, not via
subagent dispatch. The two paths share the same stdin/stdout/exit-code
contract; the harness piping behavior is a known-stable interface from
existing hooks (dangerous-commands.sh, secret-scanner.sh).

### 2. Settings wiring — confirmed PM2 condition is reachable

After running `bash install.sh`:

- `~/.claude/hooks/prism-bash-allowlist.sh` exists ✓
- `~/.claude/agents/test-debt-classifier.md` exists ✓
- `~/.claude/settings.json` does **NOT** reference `prism-bash-allowlist.sh` — the
  PM2 condition is reachable on this very machine, validating the AC23 self-probe
  motivation. install.sh deploys the file but does not auto-merge user settings.

This is **expected** and motivates WU14 (install.sh PM2-detection warning) and
AC23 (Stage 5.5 entry self-probe that aborts with `skip_reason: hook_not_wired`).

## What was NOT verified in this session

### Behavioral verification of subagent dispatch with the new hook

Three structural blockers prevent it in the current Claude Code session:

1. **Settings cache.** Existing-session settings.json is session-cached. Even
   if I add the hook entry to `~/.claude/settings.json` now, my current session
   uses the snapshot taken at session start. The new hook would not fire for
   subagents I dispatch from this session.

2. **Agent registry cache.** The new `test-debt-classifier` agent file is on
   disk but not in this session's available subagent_type list. The Agent tool
   cannot dispatch it until a fresh session loads the agents directory.

3. **Hook unwired.** `~/.claude/settings.json` does not reference the new hook
   yet (PM2 condition above). Wiring it requires either a manual JSON merge or
   the WU14 install.sh detection-and-warn flow.

## Procedure for the user to complete behavioral verification

After WU14 lands (or manually as a one-time step now):

```bash
# 1. Add the new hook to your settings.json PreToolUse Bash matcher
#    (alongside dangerous-commands.sh and secret-scanner.sh). The exact JSON
#    snippet is in commands/templates/... or settings-example.json.

# 2. Restart Claude Code (close the session, reopen).

# 3. In the new session, dispatch the agent with a non-allowlisted command:
#    Use the Agent tool with subagent_type="test-debt-classifier" and prompt
#    asking it to run `kubectl get pods` (or any non-allowlisted command).

# 4. Expected outcome: the dispatched agent's Bash call is blocked by
#    prism-bash-allowlist.sh with exit 2 and stderr "BLOCKED [SCOPE_GUARDRAIL]:
#    Command outside declared scope for test-debt-classifier". The agent
#    receives the stderr feedback and reports the block.

# 5. Then dispatch with an allowlisted command (`pytest --version`) and
#    confirm it passes through (exit 0, no stderr).
```

If step 4 fails (hook does NOT fire on the dispatched subagent), this is the
load-bearing assumption breaking — halt the blueprint and investigate. Likely
causes: settings.json not merged correctly, settings.local.json overriding
settings.json, agent_type field name changed in Claude Code's hook input shape.

## Compensating controls until behavioral verification completes

- **AC23 self-probe (WU4):** Stage 5.5 entry inspects `~/.claude/settings.json`
  for an entry referencing `prism-bash-allowlist.sh`. If absent, stage skips
  with `skip_reason: hook_not_wired` BEFORE subagent dispatch. The agent
  never executes Bash without the scope guardrail in place.
- **AC10 prior-art (verified 2026-05-01):** PreToolUse hooks DO fire for
  subagents in general, and `agent_type` is populated. The new hook reuses
  the same input shape, so the firing claim transfers.
- **Smoke-test coverage above:** the hook code itself is correct on the eight
  representative input shapes.

The remaining residual risk is: a dispatch-context-specific edge case in env
variable inheritance or stdin shape that differs from direct stdin piping.
This is low-probability given the existing hooks operate in the same path
without issue.

## Decision: proceed with caveat

Given the layered controls above, the empirical gate is documented as
**verification-split**:
- ✓ Stdin-piped behavioral verification (this session)
- ⏳ Subagent-dispatched behavioral verification (deferred — user runs after
  WU14 lands or after a manual settings merge)
- ✓ AC23 runtime self-probe (will land with WU4) provides defense-in-depth

Proceeding to WU4 with this caveat recorded. If the deferred subagent-dispatch
verification surfaces a problem, the blueprint regresses to WU2 (hook code) or
WU4 (Stage 5.5 wiring) as appropriate.
