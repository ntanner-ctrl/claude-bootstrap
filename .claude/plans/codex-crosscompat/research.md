---
topic: "Codex CLI Cross-Compatibility"
topic_slug: codex-crosscompat
date: 2026-03-28
mode: standard
linked_blueprint: codex-crosscompat
coverage:
  prior_art: true
  brainstorm: true
  requirements: true
  extended_investigation: false
gate_score: 4.3
vault_findings: 0
---

# Research Brief: Codex CLI Cross-Compatibility

## Problem Statement

claude-sail is deeply coupled to Claude Code's runtime — 66 commands use YAML frontmatter for proactive invocation, 19 hooks use exit-code conventions, 12 agents use YAML `.md` format. This creates vendor lock-in during a period when Anthropic rate limits restrict Nick's usage during core work hours (7am-3pm Eastern). Codex CLI has emerged as a viable dual-primary platform with a converging but incompatible extension model.

The goal is full parity: seamless failover to a comparable workflow in Codex at a moment's notice. This is not fallback-with-degradation — it's dual-primary operation.

### The Deeper Framing

Cross-model behavioral friction is diagnostic, not defective. claude-sail commands fuse two layers:
1. **Deep structure** — workflow logic (stages, gates, state transitions, checks)
2. **Surface structure** — model-specific persuasion (enforcement tiers, MUST/STOP language, proactive invocation triggers)

The conversion script is a **compiler** from universal workflow grammar to model-specific surface forms. Divergence between models running the same workflow reveals deep structure ambiguity and drives command quality improvement. This is generative grammar applied to agentic workflows.

## Key Findings

### Prior Art

**Codex hooks have matured beyond prior assessment.** The March 27 research concluded hooks were "experimental and off-by-default." Current documentation (March 28) reveals a 5-event model:
- SessionStart (matchers: `startup`, `resume`)
- PreToolUse (matcher: `Bash` only)
- PostToolUse (matcher: `Bash` only)
- UserPromptSubmit (no matcher)
- Stop (no matcher)

The critical PreToolUse/PostToolUse pair exists — security hooks CAN be ported for Bash operations. The limitation is Codex's Bash-only matcher vs Claude Code's any-tool matching.

**Three existing cross-CLI tools, none covering full scope:**
- **rulesync** (npm) — unified instruction file management across 10+ tools. Handles CLAUDE.md/AGENTS.md/Cursor rules. Does NOT handle hooks, agents, or settings.
- **codex-hooks** (Python) — bridge that reads Claude Code settings.json and maps events to Codex. May be partially obsoleted by Codex's native hook support.
- **rule-porter** (npx) — bidirectional .cursor/rules ↔ CLAUDE.md/AGENTS.md converter. Narrower scope.

**AGENTS.md convergence is accelerating:**
- AAIF (Linux Foundation) governs AGENTS.md, MCP, goose. Founded Dec 2025.
- 60,000+ repos adopted. Codex/Amp/Cursor/Devin/Gemini/Copilot/Jules all read natively.
- Claude Code is the notable holdout. Feature requests: anthropics/claude-code#6235, #34235.
- 62% prediction market probability of Claude Code support in 2026.
- MCP Dev Summit April 2-3, 2026 NYC — governance updates expected.

**Recommendation: build.** No existing tool covers the full claude-sail surface (commands + agents + hooks + settings + installer). rulesync and codex-hooks are potential per-platform dependencies where they add value, but the core conversion must be custom.

### Problem Analysis

The conversion is actually a **compilation** problem with two phases:

**Phase 1: Mechanical format translation** (deterministic, testable)
- YAML frontmatter stripping (commands → prompts)
- YAML → TOML conversion (agents)
- settings.json → hooks.json (hook wiring)
- Exit-code → JSON-stdout (hook response format)
- Tool name mapping (Edit → edit, Write → write, etc.)

**Phase 2: Behavioral adaptation** (requires empirical tuning)
- Proactive invocation → passive trigger hints (hardest — Claude auto-invokes, Codex doesn't)
- Enforcement language calibration (MUST/STOP patterns may need different phrasing for GPT-4.1)
- Claude-specific references → model-agnostic language
- Edit/Write hook gap compensation (instruction-level + Stop-hook verification)

### Requirements

**Scope:** Full parity — all 120+ files across 8 categories.

**Repo structure:** Single repo, `codex/` directory alongside Claude source. Generated artifact, not hand-maintained. Checked into git for reviewable diffs.

**Instruction strategy:** Dual pathway (CLAUDE.md + AGENTS.md) until Claude Code adopts AGENTS.md natively.

**Conversion script:**
- Pure bash, idempotent, deterministic
- `scripts/convert-to-codex.sh` reads Claude source, emits `codex/` directory
- Extensible: `--target codex` now, `--target gemini` future
- Includes `_codex-adapter.sh` wrapper for hook response format translation

**Testing:** `test.sh --codex` validates file counts, format correctness, schema validity, idempotency, and source file integrity.

**Hook portability matrix:**

| Category | Count | Status |
|----------|-------|--------|
| Direct port (SessionStart, PreToolUse Bash, PostToolUse Bash) | 6 | ✓ |
| Behavioral adaptation (SessionEnd → Stop) | 3 | ⚠️ |
| Blocked by Bash-only matcher (Edit/Write hooks) | 7 | ✗ → compensate via instructions + Stop hook |
| No Codex equivalent (Notification, statusLine) | 2 | ✗ → accept gap |
| Utility (called by other hooks) | 1 | ✓ |

**Compensating strategy for Edit/Write gap:** Hybrid of instruction-level guidance in AGENTS.md ("never edit CLAUDE.md directly") plus Stop-hook post-hoc verification. Weaker than Claude's gate-before-execute model — defense-in-depth degrades from 3 layers to 2 in Codex mode.

## Open Questions

1. **Codex enforcement language calibration** — What phrasing patterns does GPT-4.1 respond to most reliably? MUST/STOP may not be the right surface structure. Needs empirical testing.
2. **Proactive invocation compensation** — How much of Claude's auto-invocation behavior can be recovered via AGENTS.md instruction rules ("before implementing, run /blueprint")? What's the compliance rate?
3. **codex-hooks bridge vs native hooks** — Is the hatayama/codex-hooks bridge still needed now that Codex has native PreToolUse/PostToolUse, or does it add value for the event types Codex doesn't cover natively?
4. **Hook response format edge cases** — The `_codex-adapter.sh` wrapper must translate every exit-code + stderr combination. Are there hooks that use non-standard patterns?

## Constraints Discovered

- **Codex PreToolUse/PostToolUse only match Bash tool.** This is a hard platform limitation. 7 of 19 hooks cannot gate before execution on Codex. No workaround exists at the hook level.
- **Codex has no SessionEnd event.** The Stop event fires at turn completion, not session end. SessionEnd hooks (vault export, cleanup, epistemic postflight) need behavioral adaptation — they may fire multiple times per session or not at all if the session is abandoned.
- **Codex has no Notification event.** The notify.sh hook has no equivalent. Desktop notifications require a different mechanism.
- **Codex has no statusLine.** The status bar integration has no equivalent.
- **Pure bash constraint.** The conversion script must work without node/python/ruby. This constrains TOML generation (no library) — must template TOML by hand.

## Recommendation

**Direction: Conversion script architecture with deep-structure/surface-structure separation.**

Build `scripts/convert-to-codex.sh` as a compiler:
1. Extract deep structure (workflow logic) from Claude-native source files
2. Apply mechanical format adapters (YAML → TOML, frontmatter stripping, etc.)
3. Apply behavioral adapters (enforcement language, invocation patterns)
4. Emit `codex/` directory as standalone Codex distribution

Track behavioral divergence in `.claude/divergence/` with structured findings categorized as compliance (fix adapter), interpretation (clarify deep structure), capability (document gap), or format (cosmetic).

The conversion script is extensible to future platforms (`--target gemini`, `--target cursor`) by adding new adapter modules while sharing the deep-structure extraction.

**Implementation order suggestion:**
1. Mechanical format adapters (commands → prompts, agents → TOML) — highest file count, most testable
2. Hook adapter (`_codex-adapter.sh` + hooks.json generation) — highest value, security layer
3. AGENTS.md generation from CLAUDE.md — convergence pathway
4. Codex installer (`codex/install-codex.sh`) — completes the distribution
5. Behavioral adapters (enforcement language tuning) — requires empirical testing
6. Divergence tracking infrastructure — supports ongoing quality improvement

## Sources

- https://developers.openai.com/codex/hooks — Codex hooks documentation (5-event model)
- https://github.com/hatayama/codex-hooks — Bridge: Claude Code hooks → Codex
- https://github.com/dyoshikawa/rulesync — Unified instruction file management
- https://github.com/nedcodes-ok/rule-porter — Cursor rules → CLAUDE.md/AGENTS.md converter
- https://www.linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation — AAIF announcement
- https://github.com/anthropics/claude-code/issues/6235 — AGENTS.md support request
- https://github.com/anthropics/claude-code/issues/34235 — Native AGENTS.md context file request
- https://manifold.markets/bessarabov/will-claude-code-support-agentsmd-i — 62% probability prediction
- https://blakecrosley.com/blog/codex-vs-claude-code-2026 — Architecture comparison
