# Prior Art Report

## Problem
Persistent state tracking for markdown-based wizard commands in a Claude Code toolkit — stage progression, resume-on-compaction, vault checkpoints. Must support linear, parallel, conditional, and optional stage progressions in a pure bash/markdown toolkit with no dependencies.

## Stack
Bash/Markdown (no package manager, no runtime deps)

## Queries
3 GitHub, 0 package registry (no package manager in this project)

## Candidates

### [1] BMAD Skills — Workflow State Tracking
Source: [aj-geddes/claude-code-bmad-skills](https://deepwiki.com/aj-geddes/claude-code-bmad-skills/5.5-status-tracking-and-workflow-state)

- **Fit: Medium** — Tracks 4-phase workflow with quality gates, complexity-adaptive branching
- **Maturity: Medium** — Active Claude Code plugin, documented on DeepWiki
- **Integration: Low** — YAML-based (`bmm-workflow-status.yaml`), different architecture (skills-based, not commands), requires `bmad/config.yaml` config layer
- **Risk: Medium** — Different paradigm (YAML status files + quality gates), would require significant adaptation

**Approach:** Two YAML files — workflow status + sprint status. Phases track `not_started/in_progress/complete/blocked`. Quality gates with numeric scores. Complexity levels (0-4) determine workflow branching. Files live in `bmad-outputs/` directory.

**Relevant patterns:** Complexity-adaptive branching (simple projects skip phases), quality gates with numeric thresholds, status file is version-controlled with project.

### [2] claude-bot — 7-Phase State Persistence
Source: [siliconagent/claude-bot](https://github.com/siliconagent/claude-bot)

- **Fit: Medium** — 7-phase linear workflow with resume command, full state persistence
- **Maturity: Low-Medium** — Active but relatively new
- **Integration: Low** — Uses `.claude/claude-bot.local.md` (YAML frontmatter + markdown hybrid), different architecture (multi-agent orchestration)
- **Risk: Medium** — Linear-only progression, no parallel or conditional stage support

**Approach:** YAML frontmatter in a `.local.md` file. Tracks current phase, original goal, blockers, decisions, queued actions. Resume via `/bot-resume` command that reconstructs context from saved state.

**Relevant patterns:** YAML frontmatter + markdown hybrid (state + human-readable), resume command reconstructs from disk, blocker tracking with user input gates.

### [3] XState Wizards
Source: [xstate-wizards/xstate-wizards](https://github.com/xstate-wizards/xstate-wizards)

- **Fit: Low** — Formal state machine library for React wizard UIs
- **Maturity: High** — Built on XState (well-established)
- **Integration: None** — JavaScript/React, completely wrong stack
- **Risk: N/A** — Cannot adopt

**Relevant patterns:** Spawned actors for parallel work, formal state machine theory (guards, transitions, context), serializable state snapshots.

### [4] Bash State Machine (Gist)
Source: [rhysrhaven/gist](https://gist.github.com/rhysrhaven/7549226)

- **Fit: Low** — Simple bash case-statement state machine for script re-run on failure
- **Maturity: Low** — Gist, not maintained
- **Integration: Medium** — Pure bash, right stack
- **Risk: Low** — Trivial code

**Relevant patterns:** Writes current state to a file, reads on restart, case-statement dispatch. Minimal but proves the pattern works in bash.

## Recommendation: **Build**

**Rationale:** No candidate solves the core problem. BMAD and claude-bot are the closest but both are:
1. **Linear-only** — neither handles parallel stages (prism Wave 1) or conditional branching (clarify)
2. **Tightly coupled** to their own architecture (BMAD's skills system, claude-bot's agent orchestration)
3. **Different storage model** — YAML status files (BMAD) or `.local.md` frontmatter (claude-bot) vs our existing JSON state pattern

We already have a working state management implementation in `/blueprint` (state.json + manifest.json) that handles linear stages, parallel family mode agents, regression loops, and epistemic integration. The task is to extract a shared subset, not adopt an external solution.

**Patterns worth borrowing:**
- BMAD's complexity-adaptive branching (we already do this with Light/Standard/Full paths)
- BMAD's quality gates with numeric thresholds (maps to our confidence scoring)
- claude-bot's resume command pattern (reconstruct from disk state)
- claude-bot's blocker tracking (maps to our "blocked_pending_resolution" state)

**Next step:** Proceed to Stage 2 (Specify), designing a shared wizard state schema extracted from blueprint's proven patterns.
