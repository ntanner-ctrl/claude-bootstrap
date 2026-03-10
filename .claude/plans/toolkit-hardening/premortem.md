# Pre-Mortem — toolkit-hardening

> Premise: These 6 components were implemented two weeks ago. Something failed.

## Most Likely Failure

**Silent guardian degradation.** A Claude Code update changed the statusline JSON schema. The `jq` extraction in `statusline.sh` started returning empty/null. `CTX_INT` defaulted to 0 (fail-open). Signal files were never written. The guardian exited 0 on every call. The entire protection layer was invisible-off for a week before anyone noticed sessions losing context again.

## Contributing Factors

1. **No guardian health signal** — a guardian that never fires and a broken guardian look identical
2. **Hook wiring is manual** — `install.sh` copies files, user must manually update `settings.json`
3. **No rollback documentation** — if a hook breaks sessions, user must figure out `settings.json` edits
4. **Signal file cleanup gaps** — debug reset files not in SessionEnd cleanup
5. **No operational metrics** — can't answer "how often does each component fire?" without per-session archaeology

## Findings

| ID | Severity | Status | Finding |
|----|----------|--------|---------|
| PM1 | Medium | NEW | No guardian liveness signal — silent failure indistinguishable from "all clear" |
| PM2 | Medium | NEW | No rollback/disable documentation for hooks |
| PM3 | Low | NEW | Debug reset signal missing from SessionEnd cleanup |
| PM4 | Low | COVERED | External /tmp cleanup — mitigated by statusline rewrite cycle |
| PM5 | Low | NEW | No aggregate operational metrics |
| PM6 | Low | COVERED | Trap table staleness — intentionally manual maintenance |

## Recommendations

### PM1: Guardian Heartbeat (Medium — spec patch)
Write `/tmp/.claude-guardian-heartbeat-<PPID>` with timestamp on every guardian invocation. Diagnostic artifact — not consumed by any automation, but answers "is the guardian running?" when debugging.

### PM2: Hook Disable Guide (Medium — new documentation)
Each hook's acceptance criteria should include a documented disable procedure. Central reference in README or a troubleshooting section.

### PM3: Cleanup List (Low — trivial spec patch)
Add `/tmp/.claude-debug-reset-<PPID>` to the SessionEnd cleanup list alongside existing signal files.

### PM5: Metrics Log (Low — future enhancement)
Append-only `~/.claude/toolkit-metrics.log` with one-line entries per hook firing. Nice-to-have, not blocking.
