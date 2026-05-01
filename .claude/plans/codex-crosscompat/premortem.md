# Pre-Mortem: codex-crosscompat

> Premise: Implemented and deployed two weeks ago. It failed operationally.

## Findings

| # | Scenario | Classification | Severity |
|---|----------|----------------|----------|
| PM-1 | Stale codex/ at failover time — sha256 check only in test.sh, not on habitual path | NEW (operational gap) | high |
| PM-2 | install-codex.sh overwrites user-customized hooks without warning | NEW | high |
| PM-3 | Exit-2 hook feedback silent in Codex (stderr→stdout unvalidated) | COVERED (RV-6) | — |
| PM-4 | Codex v0.118.0 ships breaking change to hooks.json schema | NEW | high |
| PM-5 | SessionEnd hooks never fire because /end is never typed under failover pressure | COVERED (spec acknowledges) | — |
| PM-6 | Enforcement language stops working in GPT models — user expects parity | COVERED (D3 deferral), NEW as doc gap | medium |
| PM-7 | SAIL_DISABLED_HOOKS bleeds between Claude/Codex sessions | COVERED (EC-9) | — |
| PM-8 | Divergence tracking stays empty — useless when first needed | NEW | medium |

## NEW Findings (not previously caught)

### PM-1: Staleness check not on habitual path
**Scenario:** 7am, rate limits kick in. codex/ was last generated 3 days ago. User has no way to know.
**Root cause:** `convert-to-codex.sh` is not in any normal workflow. `install.sh` does not invoke it.
**Recommendation:** Add sha256 staleness warning to `install.sh` output. Zero friction on happy path.

### PM-2: Hook overwrite without warning
**Scenario:** User customized `dangerous-commands.sh` in `~/.codex/hooks/`. Upstream update + reinstall silently overwrites.
**Root cause:** `install-codex.sh` does blind copy, not copy-if-not-exists or backup-before-overwrite.
**Recommendation:** Compare sha256 before overwrite. If installed file differs from both last-generated and new-generated: warn and backup.

### PM-4: Codex CLI version drift
**Scenario:** Codex auto-updates to v0.118.0. Event names change. All PostToolUse hooks go silent.
**Root cause:** Spec pinned to v0.117.0 with no version-lock mechanism.
**Recommendation:** Include `codex --version` in `.codex-manifest.sha256`. Emit warning if installed version != validated version.

### PM-6: Enforcement language expectations not reset
**Scenario:** User expects /blueprint in Codex to enforce the same stage gates as Claude Code. GPT-4.1 ignores enforcement language.
**Root cause:** V1 passes enforcement language unchanged (D3). AGENTS.md doesn't warn users.
**Recommendation:** Add prominent AGENTS.md disclaimer about enforcement being guidance-only in Codex mode.

### PM-8: Divergence tracking cold start
**Scenario:** First Codex CLI breaking change hits. `.claude/divergence/` is empty. No historical context.
**Root cause:** WU8 creates directory + template but doesn't seed it with initial decisions.
**Recommendation:** Seed with v0.117.0 validation decisions (stderr/stdout, confirmed events, schema version) as part of initial conversion.

## Cross-Cutting Patterns

1. **Opt-in checks don't fire under pressure.** sha256 staleness, test.sh --codex, and divergence tracking all require conscious invocation. Failover is defined by time pressure.

2. **"Accepted" degradations need operational surfacing.** The spec accepts several degradations. None appear in the deployed AGENTS.md or startup behavior.

3. **Cold-start problem for operational infrastructure.** Divergence tracking, version pinning, and sha256 manifest are all empty on day one.

## Overlap Assessment
- COVERED findings: 3/8 (PM-3, PM-5, PM-7) — already in adversarial.md
- NEW findings: 5/8 (PM-1, PM-2, PM-4, PM-6, PM-8)
- Overlap ratio: 37.5% (moderate — stages 3-4 caught design issues, pre-mortem found operational gaps as intended)
