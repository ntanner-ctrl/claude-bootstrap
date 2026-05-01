# Change Specification: Codex CLI Cross-Compatibility

> **Revision 2** — Reworked after critique pipeline (18 findings) + Codex ground truth + revalidation (9 findings).
> See `spec.diff.md` for changes from revision 0 → 1 → 2.

## Summary

Build `scripts/convert-to-codex.sh`, a pure-bash compiler that transforms claude-sail's Claude Code extension files (65 commands, 12 agents, 19 hooks, settings, installer) into a standalone `codex/` distribution for OpenAI's Codex CLI v0.117.0. The output maps to Codex's native extension model: skills (SKILL.md + openai.yaml), commands (plain markdown), hooks (hooks.json — same schema as Claude Code), and an AGENTS.md instruction file.

## Codex Ground Truth (from installed v0.117.0)

Validated by inspecting `~/.codex/` and installed plugins on 2026-03-28:

| Aspect | Claude Code | Codex CLI | Implication |
|--------|-------------|-----------|-------------|
| Install root | `~/.claude/` | `~/.codex/` | All path references must be rewritten |
| Config format | `settings.json` | `config.toml` | Different config, but hooks.json is separate |
| Commands | `commands/*.md` (YAML frontmatter) | `commands/*.md` (plain markdown, `# /name` header) | Strip frontmatter, add header |
| Agents | `agents/*.md` (YAML frontmatter) | `agents/*.md` (plain markdown, no frontmatter) + `agents/openai.yaml` (machine metadata) | Strip frontmatter, generate openai.yaml |
| Skills | N/A | `skills/*/SKILL.md` (YAML frontmatter: name, description) + `agents/openai.yaml` | New concept — v2 target. v1 uses commands/ (acknowledged tech debt) |
| Hooks config | `settings.json` `.hooks` | `hooks.json` (identical schema) | Near-direct copy, change paths only |
| Hook scripts | Exit 0/1/2, stderr feedback | Same exit convention, stdout feedback | Feedback channel difference (stderr→stdout) must be validated during WU3. If confirmed, exit-2 hooks need `>&2` → `>&1` rewrite. |
| Instructions | `CLAUDE.md` | `AGENTS.md` (AAIF standard) | Conversion required |
| Plugins | N/A (implicit via `~/.claude/`) | `.codex-plugin/plugin.json` manifest | New: generate plugin.json for distribution |

## What Changes

### Files/Components Touched

| File/Component | Nature of Change |
|----------------|------------------|
| `scripts/convert-to-codex.sh` | **add** — master conversion script (compiler) |
| `codex/` | **add** — generated output directory |
| `codex/commands/` | **add** — frontmatter-stripped, header-added command files |
| `codex/agents/` | **add** — plain markdown agents + generated `openai.yaml` |
| ~~`codex/skills/`~~ | **deferred to v2** — v1 maps commands to `codex/commands/`, skill model is v2 tech debt |
| `codex/hooks.json` | **add** — hook wiring (same schema as Claude Code, paths rewritten) |
| `codex/hooks/` | **add** — copied hook scripts with path references updated |
| `codex/AGENTS.md` | **add** — generated from this repo's CLAUDE.md |
| `codex/plugin.json` | **add** — Codex plugin manifest |
| `codex/install-codex.sh` | **add** — Codex-side installer |
| `test.sh` | **modify** — add `--codex` validation path |
| `.claude/divergence/` | **add** — divergence tracking directory |

### External Dependencies

- [x] None for conversion script (pure bash)
- [x] `jq` for hooks.json path rewriting (already in test.sh)

### Database/State Changes

- [x] None

## Preservation Contract (What Must NOT Change)

- **All existing Claude Code behavior** — conversion reads source, never modifies
- **install.sh** — unchanged, does NOT install Codex artifacts
- **test.sh base categories** — all existing checks pass unchanged (current baseline: **84 checks**)
- **settings-example.json** — read-only input to converter
- **Hook exit-code semantics** — source hooks continue using 0/1/2

## Architecture

### Compiler Pipeline

```
Source (Claude Code native)           Compiler                     Output (Codex native)
──────────────────────────           ────────                     ──────────────────────
commands/*.md (YAML fm)      ──┐                           ┌──→  codex/commands/*.md (no fm, # header)
agents/*.md (YAML fm)        ──┤   convert-to-codex.sh     ├──→  codex/agents/*.md (no fm) + openai.yaml
hooks/*.sh (exit-code)       ──┤   ├─ strip_frontmatter()  ├──→  codex/hooks/*.sh (path-rewritten)
settings-example.json        ──┤   ├─ rewrite_paths()      ├──→  codex/hooks.json (paths: ~/.codex/)
.claude/CLAUDE.md            ──┤   ├─ generate_agents_md() ├──→  codex/AGENTS.md
install.sh                   ──┘   └─ generate_manifest()  └──→  codex/plugin.json
                                                                  codex/install-codex.sh
```

### YAML Frontmatter Stripping Algorithm

Commands and agents use `---` delimited YAML frontmatter. The stripping algorithm:

1. If line 1 is exactly `---`: enter frontmatter mode
2. Scan forward for the next line that is exactly `---` (line N)
3. Remove lines 1 through N (inclusive)
4. Preserve everything after line N as the body
5. **Edge case:** `---` appearing in body content (code fences, horizontal rules) is safe because we only match the FIRST `---` pair starting at line 1

This is safe because YAML frontmatter MUST start at line 1. A `---` on line 47 is body content, not frontmatter.

**Post-strip cleanup:** After removing frontmatter, strip any leading blank lines from the body. This prevents blank-line residue from pushing existing `# ` headers past the scan window.

**Exclusions:** Skip `README.md` files — they are documentation, not commands/agents. Use `commands/*.md` (non-recursive glob) to avoid processing `commands/templates/` subdirectories.

**For commands:** After stripping + cleanup, prepend `# /[filename-without-extension]` as a header if no `# ` header exists in the first 5 lines (widened from 3 to account for `## ` sub-headers that some commands use as their opening).

**For agents:** After stripping, output as plain markdown. Generate a **single** `codex/agents/openai.yaml` that describes the toolkit's agent surface as a whole (matching Figma plugin convention — one openai.yaml per plugin, not per agent):
```yaml
interface:
  display_name: "Claude Sail"
  short_description: "Structured workflows, safety guardrails, and planning discipline"
```
Individual agent metadata (name, description from frontmatter) is preserved in the agent markdown files themselves — Codex discovers agents by reading the `agents/` directory.

### Hook Portability Matrix (Revised)

hooks.json uses the **identical schema** to Claude Code's settings.json hooks section. The critical difference is path prefixes (`~/.claude/hooks/` → `~/.codex/hooks/`) and event-name availability.

**Path rewriting rules:**
- **hooks.json command paths:** Use **relative paths** (`./hooks/<script>.sh`) for plugin-distribution compatibility. The Figma plugin confirms this convention.
- **Within hook scripts (ALL `~/.claude/` references):** Rewrite `~/.claude/` to `~/.codex/` globally (not just `~/.claude/hooks/`). Hooks reference `~/.claude/epistemic.json`, `~/.claude/.current-session`, `~/.claude/scripts/`, `~/.claude/commands/` in addition to `~/.claude/hooks/`. Use `sed "s|~/.claude/|~/.codex/|g"` on all copied hook scripts.
- **install-codex.sh:** Resolves relative plugin paths to absolute `~/.codex/` paths at install time.
- **Scope boundaries:** WU3 owns path rewriting in hook scripts only. WU4 owns path rewriting in AGENTS.md only. No overlap.

**`CODEX_INSTALL_ROOT` variable:** Defined once as `~/.codex` in the conversion script. All generated paths reference this variable. This single definition resolves all path-related findings (CF-4, M5, M7, M10).

| Hook | Event (Claude) | Matcher | Codex Event | Codex Matcher | Status |
|------|----------------|---------|-------------|---------------|--------|
| session-sail.sh | SessionStart | "" | SessionStart | startup \| resume | ✓ direct (D4: both matchers) |
| worktree-cleanup.sh | SessionStart | "" | SessionStart | startup | ✓ direct (startup only — cleanup on resume risks deleting active worktrees) |
| epistemic-preflight.sh | SessionStart | "" | SessionStart | startup | ✓ direct (startup only — handles upsert, D4) |
| dangerous-commands.sh | PreToolUse | Bash | PreToolUse | Bash | ✓ direct |
| secret-scanner.sh | PreToolUse | Bash | PreToolUse | Bash | ✓ direct |
| failure-escalation.sh | PostToolUse | Bash | PostToolUse | Bash | ✓ direct |
| protect-claude-md.sh | PreToolUse | Edit\|Write | — | — | ✗ **no equivalent** (see Security Degradation) |
| tdd-guardian.sh | PreToolUse | Edit\|Write | — | — | ✗ compensate via AGENTS.md |
| freeze-guard.sh | PreToolUse | Edit\|Write | — | — | ✗ compensate via AGENTS.md |
| after-edit.sh | PostToolUse | Edit\|Write | PostToolUse | Write\|Edit | ✓ direct (Figma plugin confirms matcher works) |
| cfn-lint-check.sh | PostToolUse | Edit\|Write | PostToolUse | Write\|Edit | ✓ direct |
| state-index-update.sh | PostToolUse | Edit\|Write | PostToolUse | Write\|Edit | ✓ direct |
| blueprint-stage-gate.sh | PostToolUse | Edit\|Write | PostToolUse | Write\|Edit | ✓ direct |
| session-end-vault.sh | SessionEnd | "" | — | — | ⚠️ adapt via marker file (see below) |
| session-end-cleanup.sh | SessionEnd | "" | — | — | ⚠️ adapt via marker file |
| epistemic-postflight.sh | SessionEnd | "" | — | — | ⚠️ adapt via marker file |
| notify.sh | Notification | "*" | — | — | ✗ no equivalent |
| statusline.sh | statusLine | — | — | — | ✗ no equivalent |
| _audit-log.sh | (utility) | — | (utility) | — | ✓ copy (path-rewritten) |

### Security Degradation Summary

> **Parity framing:** This is **structural parity with documented security degradations**, not full parity. The Codex distribution provides equivalent workflow discipline with a weaker security enforcement layer.

| Lost Guarantee | Claude Code Behavior | Codex Behavior | Severity |
|----------------|---------------------|----------------|----------|
| CLAUDE.md/AGENTS.md write protection | Pre-gate: blocks write, requires user approval via temp marker | **No equivalent.** AGENTS.md instruction rule + post-hoc detection only. The approval flow (stateful marker file, single-use, 5-min expiry) cannot be replicated in a post-execution model. | **Critical — accepted** |
| PreToolUse Edit/Write gating (3 hooks: protect-claude-md, tdd-guardian, freeze-guard) | PreToolUse gate: blocks before execution | **No equivalent.** AGENTS.md instruction rules only. PostToolUse Edit/Write hooks (4 hooks) ARE portable — confirmed by Figma plugin. | High — accepted |
| Session-end cleanup | SessionEnd: fires once at session termination | Marker-file gated: only fires if `/end` sets marker. Abandoned sessions get no cleanup. | Medium — accepted |
| Notification | Desktop notification on completion | No equivalent | Low — accepted |
| Status line | Live status bar | No equivalent | Low — accepted |
| Agent tool restrictions | `tools:` field in YAML frontmatter restricts agent capabilities (e.g., lens agents have no Bash) | **Silently dropped.** Codex agent files have no per-agent tool restriction mechanism. 6 lens agents lose their sandbox. | Medium — accepted |

### SessionEnd → Stop Adaptation

Codex has no SessionEnd event. The adapted hooks use a **marker-file protocol**:

1. The `/end` command (converted to a Codex skill) writes `~/.codex/.session-ending` marker
2. Adapted session-end hooks check for this marker before executing
3. If marker absent: exit 0 (no-op)
4. If marker present: execute cleanup, then remove marker
5. **Known degradation:** Sessions abandoned without `/end` get no vault export, no cleanup, no epistemic postflight

The "check recent turns" heuristic from revision 0 is removed — it was architecturally impossible (hooks cannot inspect conversation history).

### Compensation Strategy for Edit/Write Gap

The 19 hooks break down as: **10 direct ports** (6 original + 4 PostToolUse Edit|Write), **3 PreToolUse Edit|Write blocked** (no Codex equivalent), **3 SessionEnd adapted** (marker-file protocol), **2 no equivalent** (Notification, statusLine), **1 utility** (copy).

For the **3 blocked PreToolUse Edit|Write hooks** (protect-claude-md, tdd-guardian, freeze-guard):

1. **AGENTS.md instruction rules** — Behavioral guidance for each (e.g., "Before editing AGENTS.md, verify the change is intentional")
2. **Human review** — Accept that Codex mode relies more on human oversight
3. **No stop-verifier** — Cannot replicate gate semantics; partial solutions create false confidence

The success criterion for AGENTS.md compensation references these 3 hooks by name, not by count.

### CLAUDE.md → AGENTS.md Conversion

**Input:** This repo's `.claude/CLAUDE.md` (the toolkit's project instructions). Not the user's global `~/.claude/CLAUDE.md` and not target project CLAUDE.md files.

**Mapping:**

| CLAUDE.md Section | AGENTS.md Treatment |
|-------------------|---------------------|
| Quick Reference | Keep — universal |
| Architecture Overview | Keep — reference |
| Key Conventions (Command/Agent/Hook Authoring) | Keep — applicable to Codex skills/agents |
| Key Patterns | Keep — universal |
| Common Tasks | Adapt — rewrite paths from `~/.claude/` to `~/.codex/` |
| Testing | Adapt — add `--codex` references |
| Do Not | Keep — universal |
| Claude-specific references | Drop — e.g., "Claude invokes proactively" |

**Additionally:** Append compensation rules for the 3 blocked PreToolUse Edit/Write hooks (part of WU4's scope).

### Behavioral Adapter Rules

> **HYPOTHETICAL — requires GPT-4.1/GPT-5.4 compliance testing.**
> These mappings are untested starting hypotheses. The v1 conversion script passes enforcement language through unchanged (per D3). This table documents the intended v2 tuning direction.

| Claude Pattern | Hypothesized Codex Adaptation | Confidence |
|----------------|-------------------------------|------------|
| `STOP. You MUST...` | TBD — needs empirical testing | Low |
| `REQUIRED after...` | TBD — needs empirical testing | Low |
| Proactive invocation via `description:` | AGENTS.md rule: "Before implementing, check available skills" | Medium |
| Claude-specific tool names (Edit, Write) | Generic: "file editing", "file creation" | High |

## Work Units

| ID | Description | Files | Dependencies | Complexity | TDD |
|----|-------------|-------|-------------|------------|-----|
| WU1 | Command adapter — strip YAML frontmatter, add `# /name` header | `scripts/convert-to-codex.sh`, `codex/commands/` | None | Medium | true |
| WU2 | Agent adapter — strip YAML frontmatter, generate `openai.yaml` from extracted fields | `scripts/convert-to-codex.sh`, `codex/agents/`, `codex/agents/openai.yaml` | None | Medium | true |
| WU3 | Hook path rewriter — rewrite ALL `~/.claude/` → `~/.codex/` in hook scripts (not just hooks/ subdir), generate `hooks.json` by extracting ONLY the `hooks` key from `settings-example.json` (exclude `statusLine` and `_mcpServers_note`), use relative paths (`./hooks/`), port 4 PostToolUse Edit\|Write hooks, copy only `*.sh` files (exclude README/docs). **Validation:** test stderr vs stdout feedback channel. | `scripts/convert-to-codex.sh`, `codex/hooks/`, `codex/hooks.json` | None | Medium | true |
| WU4 | AGENTS.md generator — convert `.claude/CLAUDE.md` to AGENTS.md with path rewrites + append compensation rules for 7 blocked hooks | `scripts/convert-to-codex.sh`, `codex/AGENTS.md` | None | High | true |
| WU5 | Plugin manifest generator — create `.codex-plugin/plugin.json` with required fields including `"hooks": "./hooks.json"`, `"skills"`, and `"interface"` block | `scripts/convert-to-codex.sh`, `codex/plugin.json` | WU1, WU2, WU3 | Low | true |
| WU6 | Codex installer — `codex/install-codex.sh` deploying to `~/.codex/` | `codex/install-codex.sh` | WU1, WU2, WU3, WU4, WU5 | Medium | false |
| WU7 | Test extension — `test.sh --codex` validation path | `test.sh` | WU1, WU2, WU3, WU4, WU5, WU6 | Medium | true |
| WU8 | Divergence tracking — `.claude/divergence/` structure + finding template | `.claude/divergence/` | None | Low | false |
| WU9 | Master script assembly — wire adapters into `convert-to-codex.sh` with `--target codex`, `CODEX_INSTALL_ROOT`, atomic output (`.codex-tmp/` → `codex/`). **CWD contract:** anchor inputs to `$(dirname "$0")/..`. Preflight: abort if `commands/*.md` < 60 files. | `scripts/convert-to-codex.sh` | WU1, WU2, WU3, WU4, WU5 | High | true |

**Changes from revision 0:**
- WU2 redesigned: TOML removed, openai.yaml generation added
- WU3 simplified: no _codex-adapter.sh needed — hooks.json schema is identical, just rewrite paths
- WU4 restructured: single owner of AGENTS.md (was split between WU5/WU6 in rev 0)
- WU5 is now plugin manifest (was Edit/Write compensation — that's folded into WU4)
- WU6 replaces old WU7 (installer)
- WU7 replaces old WU9 (tests)
- WU8 replaces old WU10 (divergence tracking)
- WU9 replaces old WU11 (master assembly) — includes atomic output strategy
- Old WU8 (behavioral adapter) removed — v1 is pass-through per D3, no separate WU needed
- Total: **9 WUs** (down from 11)

## Success Criteria

| Criterion | How to Verify |
|-----------|---------------|
| All 65 commands converted to frontmatter-free markdown with `# /name` headers | `test.sh --codex` counts + frontmatter absence + header check |
| All 12 agents converted to plain markdown + valid `openai.yaml` generated | `test.sh --codex` validates YAML structure (interface.display_name, interface.short_description) |
| `hooks.json` uses correct schema and all command paths use relative form `./hooks/<script>.sh` | `test.sh --codex` schema validation + relative path grep (no `~/` in hooks.json) |
| All hook scripts have `~/.claude/hooks/` rewritten to `~/.codex/hooks/` | Grep source references in `codex/hooks/`, verify zero `~/.claude/` occurrences |
| `AGENTS.md` contains compensation rules for 3 blocked PreToolUse hooks (protect-claude-md, tdd-guardian, freeze-guard) | Grep for each hook name in AGENTS.md |
| `AGENTS.md` contains no `~/.claude/` path references | Grep for path correctness |
| `.codex-plugin/plugin.json` validates against Codex plugin schema | `test.sh --codex` JSON validation + required fields |
| `codex/install-codex.sh` deploys to `~/.codex/` correctly | Dry-run install in temp `$HOME` |
| Conversion is idempotent and deterministic | Run twice, diff — must be identical |
| Source files never modified | `git diff` after conversion shows zero source changes |
| `test.sh` base categories still pass | Run without `--codex` — all 84 existing checks pass |
| Content staleness detected | `test.sh --codex` computes sha256sum of source files, compares to `.codex-manifest.sha256` generated alongside output |

## Failure Modes

| What Could Fail | Detection Method | Recovery Action |
|-----------------|------------------|-----------------|
| Frontmatter stripping corrupts body (--- in content) | Test: commands with `---` in body (code fences, HR rules) produce correct output | Fix: only match first `---` pair starting at line 1 |
| openai.yaml generation produces invalid YAML | Test: YAML lint on all generated openai.yaml files | Fix: quote all string values, escape special chars |
| Path rewriting misses a reference | Grep `codex/` tree for `~/.claude/` — must find zero | Fix: add missed pattern to rewrite list |
| hooks.json references non-existent scripts | Cross-reference hooks.json commands with `codex/hooks/` contents | Fix: ensure all referenced scripts are copied |
| plugin.json missing required fields | Validate against plugin-json-spec.md field requirements | Fix: add missing fields |
| Concurrent conversion produces partial output | Atomic: write to `.codex-tmp/`, mv on success | N/A — atomic by design |
| Source files accidentally modified | `git diff` check in test | Bug in script — fix write targets |
| Content drift after source edit | sha256 manifest comparison in `test.sh --codex` | Re-run conversion |

## Rollback Plan

1. `rm -rf codex/` — entire output is generated
2. `git checkout -- test.sh` — revert test extension
3. `rm scripts/convert-to-codex.sh` — remove script
4. `rm -rf .claude/divergence/` — remove tracking

No database, no external state. Rollback is `git checkout`.

## Dependencies (Preconditions)

- [x] Research brief completed (gate 4.3/5.0)
- [x] Codex v0.117.0 installed and inspected for ground truth
- [x] hooks.json schema confirmed identical to Claude Code
- [x] Agent format confirmed (plain markdown + openai.yaml, NOT TOML)
- [x] Install root confirmed (`~/.codex/`)
- [x] `bash` and `jq` available

## Open Questions (Resolved)

All open questions from revision 0 are now resolved:

1. ~~codex/ git tracking~~ → **D1: Commit** ✓
2. ~~_codex-adapter.sh placement~~ → **Eliminated** — adapter not needed, hooks.json uses same schema
3. ~~Behavioral adapter v1 scope~~ → **D3: Pass-through** ✓ (no separate WU)
4. ~~Codex resume matcher~~ → **D4: session-sail startup+resume, others startup only** ✓ (worktree-cleanup startup-only for safety)
5. ~~TOML agent format~~ → **Ground truth: plain markdown + openai.yaml** ✓
6. ~~Exit-code → JSON-stdout adapter~~ → **Ground truth: same exit convention** ✓
7. ~~Codex install root~~ → **Ground truth: ~/.codex/** ✓
8. ~~CLAUDE.md input ambiguity~~ → **Specified: this repo's .claude/CLAUDE.md** ✓

## Senior Review Simulation

- **They'd ask about:** "Is hooks.json really identical? Did you test that Codex actually reads it and the exit codes work?" — **Answer: The Figma plugin ships a hooks.json with identical schema and a hook script that uses echo (not JSON-stdout). The structure is confirmed. Exit-code semantics should be validated with a simple test hook during WU3 implementation.**

- **Non-obvious risk:** The skill model is richer than the command model. Claude Code commands are flat files; Codex skills have `SKILL.md` + `openai.yaml` + optional `references/` + `scripts/` + `agents/`. For v1, we emit commands (not skills) — but the Codex skill model is where the long-term parity lives. This is tech debt we're knowingly taking on.

- **Standard approach I might be missing:** The `.codex-plugin/plugin.json` manifest enables distribution via Codex's plugin marketplace. We should generate it even if we don't publish there immediately — it's the standard distribution format.

- **What bites first-timers:** Path rewriting with sed is fragile when paths contain special characters or are embedded in strings. Use `sed "s|~/.claude/hooks/|~/.codex/hooks/|g"` (pipe delimiters, not slashes) to avoid escaping issues with path separators.
