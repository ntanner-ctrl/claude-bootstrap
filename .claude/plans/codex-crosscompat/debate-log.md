# Critique Pipeline: codex-crosscompat (Challenge Stage)

## Orient Phase

### Intent
Build a pure-bash compiler that mechanically transforms claude-sail's Claude Code-native files into a Codex CLI-compatible distribution. Primary motivation: operational resilience (rate limit failover). Compiled output committed to git because divergence diffs are the diagnostic signal.

### Constraints
- Pure bash only (no package manager)
- codex/ is additive only (no source modification)
- fail-open hook semantics must survive wrapping
- Codex hooks: Bash-only matcher (7/19 structurally unportable)
- jq available but optional
- test.sh categories 1-8 unchanged

### Scope Boundaries
- **In:** command YAML stripping, agent YAML→TOML, hook wrapping (6 portable), hooks.json generation, AGENTS.md generation, Stop-hook gap compensator, Codex installer, test.sh --codex, divergence tracking skeleton
- **Out:** behavioral adapter substance (v1 pass-through), hookify-rules porting, plugin porting, vault/epistemic integration on Codex side, remote install path for Codex

### Historical Context
- March 27 finding: hooks layer "no stable equivalent" — contradicted by March 28 research (5-event model)
- March 28 cross-model friction finding: reframes as compiler (universal grammar), not translator (surface mapping). Already embedded in spec architecture.

### Unvalidated Assumptions
1. **Codex hooks.json schema stability** — research says "matured" but earlier finding said "experimental." Schema may change.
2. **exit-code → JSON-stdout is correct adapter direction** — needs confirmation against Codex hook API docs before WU3.
3. **SessionStart fires on both startup AND resume (D4)** — if Codex fires distinct events, duplicate execution is a risk for idempotency-sensitive hooks.
4. **CLAUDE.md → AGENTS.md is parseable** — CLAUDE.md is structured hybrid; which sections translate vs. drop is underspecified (hardest part of WU6).
5. **_codex-adapter.sh in scripts/ bypasses hook lint** — test.sh Category 5 only lints hooks/. If adapter uses set -e or eval, lint won't catch it.

## Diverge Phase — Correctness Perspective

FINDING-C1: Command count 66 is wrong — 65 commands + 1 README.md (high, conf 0.97)
FINDING-C2: TOML agent frontmatter requirement unsourced — Codex may not use TOML at all (critical, conf 0.82)
FINDING-C3: exit-code → JSON-stdout adapter direction unvalidated — may be unnecessary or inverted (critical, conf 0.88, false-known)
FINDING-C4: "Check recent turns" heuristic architecturally impossible for hooks (high, conf 0.93)
FINDING-C5: Success criteria references 75 checks; current baseline is 84 (medium, conf 0.99)
FINDING-C6: File-count staleness check misses content edits/renames — need content hash (high, conf 0.96)
FINDING-C7: _codex-adapter.sh bypasses hook lint — fail-open guarantee at risk (high, conf 0.95, false-known)
FINDING-C8: Vault export creates duplicate session notes on every Stop without /end (high, conf 0.91)
FINDING-C9: CLAUDE.md input ambiguous — three candidates, none specified (medium, conf 0.88, false-known)
FINDING-C10: Behavioral adapter table presents empirical hypotheses as established fact (medium, conf 0.85, false-known)

## Diverge Phase — Completeness Perspective

FINDING-M1: _codex-adapter.sh JSON schema not defined — silent security failure if wrong (critical, conf 0.88)
FINDING-M2: protect-claude-md.sh approval flow stateful — Stop-hook cannot replicate gate semantics (critical, conf 0.92)
FINDING-M3: SessionStart resume matcher inconsistent with epistemic session ID pairing (high, conf 0.82)
FINDING-M4: No staleness detection mechanism — codex/ can silently drift (high, conf 0.90)
FINDING-M5: vault-config.sh Codex install path unaddressed — silently disabled vault export (high, conf 0.85)
FINDING-M6: YAML frontmatter stripping regex unspecified — naive sed corrupts commands with --- in body (high, conf 0.87)
FINDING-M7: _audit-log.sh source path hardcoded to ~/.claude/hooks/ — breaks in Codex install root (high, conf 0.91)
FINDING-M8: WU5 marked TDD=false — compensation rules have no automated verification (medium, conf 0.84)
FINDING-M9: Concurrent conversion runs unaddressed — partial codex/ state possible (medium, conf 0.75)
FINDING-M10: Codex install root path never specified — blocks WU4 and WU7 (medium, conf 0.80)

## Diverge Phase — Coherence Perspective

FINDING-H1: WU5 orphaned from WU11 and WU9 dependency lists — stop-verifier silently absent (critical, conf 0.97)
FINDING-H2: WU5 and WU6 both claim codex/AGENTS.md with no merge protocol (critical, conf 0.95)
FINDING-H3: _codex-adapter.sh in scripts/ violates hooks convention it will bypass (high, conf 0.93)
FINDING-H4: WU8 listed as optional in D3 but required in WU11 dependencies (high, conf 0.92)
FINDING-H5: Success criteria says 75 checks; actual count is 84 (high, conf 0.99)
FINDING-H6: Portability matrix shows startup-only for session-sail.sh, contradicting D4 (resume too) (high, conf 0.91)
FINDING-H7: Success criteria claims 5 events in hooks.json but only 4 are mapped (medium, conf 0.88)
FINDING-H8: .gitignore still in "What Changes" table despite D1 resolving against modification (medium, conf 0.97)
FINDING-H9: Pre-gate → post-detect degradation qualitatively understated as "2 layers" (medium, conf 0.96)
FINDING-H10: "Full parity" goal silently contradicted by multiple accepted degradations (medium, conf 0.89)

## Clash Phase — Cross-Examination Results

Zero rebuttals across all 3 lenses. Every cross-examination reinforced or escalated the original finding.

**Key escalations:**
- H1 + M2 compound: Security compensation is simultaneously orphaned (H1), has no merge protocol (H2), AND is architecturally non-viable for gate semantics (M2)
- C3 + M1 compound: Adapter direction unvalidated AND output schema undefined — doubly unverified contract
- M7 + M10 compound: All source paths break without defined Codex install root
- C7 + H3 compound: Lint gap + convention violation = silent fail-closed risk
- C4 + C8 + M5 compound: SessionEnd→Stop semantic mismatch causes vault duplication, impossible heuristic, and broken paths

## Converge Phase — Final Verdict

**Verdict: REWORK** (regression target: specify)

### Deduplication Results
30 raw findings → 18 consolidated findings (CF-1 through CF-18)

### Severity Distribution
- Critical: 3 (CF-1: adapter contract, CF-2: security compensation, CF-3: TOML unsourced)
- High: 8 (CF-4 through CF-11)
- Medium: 5 (CF-12 through CF-16)
- Low: 2 (CF-17, CF-18)

### Key Statistics
- False knowns: 5 (spec presents unvalidated assumptions as decided facts)
- Compound failures: 8 (findings that interact to produce worse outcomes than either alone)
- Unresolved tensions requiring human decision: 4

### Verdict Rationale
The spec has strong mechanical architecture but 3 critical findings block implementation. CF-1 (adapter contract unverified) blocks WU3/WU4/WU11 — the core pipeline. CF-2 (security compensation orphaned+non-viable) means the defense-in-depth story has a structural gap. CF-3 (TOML unsourced) could invalidate WU2 entirely. Eight high-severity findings cover install root, lint gaps, session semantics, frontmatter algorithm, matrix contradictions, CLAUDE.md ambiguity, staleness detection, and success criteria drift. This is a tighten-and-verify rework, not a redesign.

### Human Decisions Required
1. Validate Codex hook response protocol (CF-1) — blocks core pipeline
2. Verify Codex agent file format (CF-3) — blocks WU2
3. Accept protect-claude-md security gap or redesign compensation (CF-2)
4. Set parity framing: "full parity" vs "structural parity with documented degradations" (CF-12)

Full structured verdict: `.claude/plans/codex-crosscompat/converge.json`
