# Specification Revision History

## Revision 1 (initial)
- Created: 2026-04-30
- Sections: Architecture, Schema, Sweep Logic, /end Integration, Stock Templates, Hookify Integration, Documentation, Three Starter Entries, Work Units, Acceptance Criteria, Test Strategy, Risks, Open Questions
- Work Units: 7 (WU3 high-complexity)
- Backup: `spec.md.revision-1.bak`

## Revision 1 → Revision 2

**Trigger:** Vanilla challenge stage (Stage 3) found 2 critical + 4 lower-severity findings.
Verdict: REWORK. Regression to Stage 2.

**Date:** 2026-04-30

**Changes by finding:**

| Finding | Severity | Section affected | Change |
|---------|----------|-----------------|--------|
| F1 | critical | Hookify Integration → **Shell Hook Integration** | Replaced section. WU6 pivoted from `hookify-rules/hookify.unsafe-atomic-write.local.md` (would never fire — `event: write` not supported, only `event: bash`) to `hooks/anti-pattern-write-check.sh` PreToolUse on Write/Edit. WU6 complexity bumped Low→Medium. |
| F2 | critical | Sweep algorithm step 3 | Added `EXCLUDE_PATHS` filter: `.claude/anti-patterns/`, `.claude/plans/`, `commands/templates/stock-anti-patterns/`, vault mirror. Catalog entries' `fixture_bad` blocks were self-matching. |
| F3 | high | Three Starter Entries | Dropped `bash-silent-error-suppression` (multi-line detection requires schema extension `detection_kind: regex|awk|external-script`, deferred to v2). Replaced with `bash-rm-rf-with-variable` (single-line regex, exercises `recent_hits=0` path). |
| F4 | medium | Sweep algorithm — new step 5a | Added 10000-line cap on `.events.jsonl`: when exceeded, archive oldest 5000 to `.events.archive.jsonl`, truncate active log. |
| F5 | medium | Sweep algorithm step 6 | Added helper-or-fallback path: source `epistemic_safe_swap` if available, else use inline non-empty + valid-frontmatter validation. |
| F6 | low | WU3 estimate | Bumped 90 min → 150 min (informational, no functional change). |
| F7 | low | WU5 description | Made "file-level copy-if-not-exists" explicit (was ambiguous between dir-level and file-level). |
| F8 | low | (not addressed) | `recent_window_days = 60` default deferred to v2 (project-level config). |

**Sections added:**
- Sweep step 5a: Events log cap

**Sections modified:**
- Sweep step 3: EXCLUDE_PATHS
- Sweep step 6: helper-or-fallback for safe-swap
- Hookify Integration → Shell Hook Integration (full section replacement)
- Three Starter Entries: entry 2 swapped
- Work Units table: WU3, WU5, WU6, WU7 amended

**Sections unchanged:**
- Architecture overview
- Catalog Entry Schema
- Performance budget, fail-open semantics
- /end integration block
- Documentation, Acceptance Criteria, Test Strategy, Risks (some entries refined inline)

**Adversarial findings addressed:** 6/8 (F6, F8 deferred as informational/v2 concerns).

**Work units affected:**
- WU3: estimate bump, EXCLUDE_PATHS added, events cap added, safe-swap fallback added
- WU5: file-level copy semantics specified
- WU6: pivoted from hookify rule to shell hook (file path changed; complexity bumped)
- WU7: hook-firing fixture added to test plan

## Revision 2 → Revision 3

**Trigger:** /review wizard (4-lens analysis: Devil's Advocate, Simplify, Edge Cases,
Prior Art). 16 findings (3H/4M/9L). **No regression** — all HIGH findings are
framing/positioning, not mechanism redesign. Polish edits only.

**Date:** 2026-04-30

**Changes by finding:**

| Finding | Severity | Section affected | Change |
|---------|----------|-----------------|--------|
| PA-1 | high | describe.md (new "Positioning vs. External Detection Tools" section) | Reframes the catalog as **bookkeeping/temporal observability**, not detection. Explicit contrast with semgrep/ast-grep/shellcheck. Documents that bash+curl constraint is the reason for regex-not-AST. |
| PA-2 | medium | spec.md (new "Decisions" section) | Documents why-regex-over-AST anchoring on the toolkit constraint. Future readers see the design choice, not a perceived oversight. |
| DA-1 | high | spec.md ("Decisions" + WU6 + AC14) | Documents why warn-only PreToolUse, flags hook visibility verification as a pre-impl gating step in WU6. AC14 added to verify warning is surfaced to Claude. Strongest open risk. |
| S-1 | high | spec.md ("Decisions") | Anchors heartbeat+nudge ceremony in pre-mortem evidence (silent-decay history). Documents walk-back path (delete `.last-sweep.json`). |
| S-3 | low | spec.md ("Decisions") | Documents why `bash-rm-rf-with-variable` ships despite recent_hits=0 — exercises real-codepath honesty test. Trade-off acknowledged. |
| PA-3 | low | spec.md (Catalog Entry Schema) | Added optional `references: []` field — links to incidents/PRs/CVEs. Forward-compat with semgrep's metadata.references. |
| E20 | medium | spec.md (Sweep algorithm step 5) | Split into 5a (dedupe by (id, file, line) tuple, keep latest ts) and 5b (counter recompute over deduped set). Prevents manual-then-session-sweep double-attribution. |
| E23 | low | spec.md (Sweep algorithm step 7) | Vault export moved outside the 5s timeout wrapper. Network-mounted vaults can't blow the project-local sweep budget. |
| DA-3 | medium | spec.md (Sweep algorithm step 7) | Vault mirror prefixed with `<!-- AUTO-GENERATED MIRROR -->` contract header. Obsidian editors see the contract before they lose work. |
| E21 | low | Risks/Limitations | Documented: regex mutation invalidates old events; users with substantive regex changes should archive old events. |
| E22 | low | Risks/Limitations | Documented: orphaned events for deleted patterns aren't gc'd; v2 `--full --prune`. |
| E24 | low | Risks/Limitations | Documented: `@{1.hour.ago}` reflog ambiguous after rebase; mitigation via `git rev-parse ... \|\| echo HEAD` fallback. |
| DA-2 | medium | (not addressed — deferred) | Vault export decoupling considered; rejected for v1 — bookkeeping + aggregation is one cohesive product, splitting adds command surface for marginal gain. Revisit if vault export becomes a hot path. |
| DA-4 | low | (not addressed — accepted) | `bash-missing-fail-fast` regex-coarseness accepted with documented false-positive rate (already in v2 spec). Same trade-off as F3 but lower risk because the pattern's bad shapes are simpler. |
| S-2 | medium | (not addressed — accepted) | Two sweep modes retained. `--full` is genuinely needed for initial catalog seeding (first run on a project). Speculative-demand challenge rejected. |
| S-4 | low | (not addressed — deferred) | `recent_window_days` 3-layer config; v1 keeps per-pattern frontmatter only, project-level override is v2 (already in F8 deferral). |

**Sections added:**
- spec.md: "Decisions" (between Architecture and Catalog Entry Schema)
- describe.md: "Positioning vs. External Detection Tools" (between Problem and Desired Outcome)

**Sections modified:**
- spec.md: revision header, Catalog Entry Schema (`references[]` field), Sweep algorithm steps 5/5a/5b/7, WU6 description, Acceptance Criteria (AC13/AC14), Risks/Limitations (4 new rows)

**Sections unchanged:**
- Architecture diagram, fail-open semantics, /end Integration block, Stock Templates, Documentation, Test Strategy, Open Questions

**Findings deferred (accepted-with-rationale):** DA-2, DA-4, S-2, S-4.

**Total review findings addressed:** 12/16 inline; 4 deferred with documented reasoning.

**Work units affected:** WU6 (DA-1 visibility verification gating step), WU3 (E20 dedupe in counter regen, E23 vault outside timeout, DA-3 mirror header).

## Revision 3 → Revision 4

**Trigger:** AC14 pre-impl gating verification (per rev3 spec's "Decisions" section directing
hook visibility verification before WU6). Empirical test confirmed DA-1: rev3's `exit 0 + stderr`
PreToolUse mechanism is invisible to Claude — only the user terminal sees the warning.

**Date:** 2026-04-30

**Status:** Mechanism correctness, not architectural regression. The PreToolUse-hook-as-first-consumer
architecture is unchanged. Only the output channel shifts.

**Changes by finding:**

| Finding | Severity | Section affected | Change |
|---------|----------|-----------------|--------|
| AC14 form 2 empirical | critical (mechanism) | Hook Script Contract + Decisions section + AC14 + WU6 + tests.md AC14 form 1 | Switched output mechanism from `exit 0 + stderr "Catalog: <id>"` to `exit 0 + stdout JSON {hookSpecificOutput: {permissionDecision: "allow", additionalContext: "..."}}`. Documented as the canonical Claude Code primitive for warn-with-visibility on PreToolUse. |

**Empirical evidence captured:** see `ac14-verification.md` for the three-form test report.

**Sections modified:**
- `spec.md`: revision header rev3→rev4 with rev4 note prepended
- `spec.md`: Decisions → "Why warn-with-visibility via additionalContext (DA-1, rev4 verified)" replaces "Why warn-only PreToolUse" — anchors on empirical evidence
- `spec.md`: Shell Hook Integration → Hook Script Contract — full rewrite of the example script using additionalContext mechanism + multi-pattern accumulation + alternative comparison
- `spec.md`: Acceptance Criteria → AC14 wording updated to specify additionalContext mechanism + form 1/form 2 split
- `spec.md`: Work Units → WU6 description updated to reflect new output mechanism + final-manual-gate retained
- `tests.md`: AC14 form 1 unit test rewritten — asserts JSON-stdout output with valid `hookSpecificOutput` shape, empty stderr on warn

**Sections unchanged:**
- Architecture diagram, Catalog Entry Schema, Sweep Logic (all 9 steps), /end Integration, Stock Templates, Three Starter Entries, all other ACs (AC1-AC13), Risks/Limitations, Test Strategy, Open Questions

**Side findings captured to vault:** see vault notes 2026-04-30-claude-code-hook-output-channels.md
and 2026-04-30-claude-code-settings-session-locked.md (and others — see vault index).

**Why this is rev4 not a regression:** the architectural choice (PreToolUse hook as first
consumer, citing catalog IDs) is preserved. The output mechanism was wrong; we fixed the
mechanism. No WU dependencies change; only WU6's hook script body differs from what would
have been written under rev3.
