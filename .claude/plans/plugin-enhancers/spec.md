# Specification: Plugin Enhancers (Revision 1)

> **Revision history:** Rev 0 → Rev 1 regression triggered by debate chain (2 critical findings).
> See `adversarial.md` for full findings. See `spec.md.revision-0.bak` for previous version.

## Summary

Add a plugin integration layer to claude-bootstrap that allows external Claude Code plugins to augment existing workflow stages at natural decision points. The integration is opt-in at each seam, requires no package dependencies, and degrades gracefully when plugins are absent.

**Phased delivery:** This spec defines the full vision but implementation is phased. Phase 1 (the primary deliverable) targets ONE integration seam (review) with ONE plugin (pr-review-toolkit) to validate the pattern before expanding.

---

## Design Decisions

### Opt-In with Smart Defaults (preserved from rev 0)

Plugin capabilities are **offered as options** at workflow seams, not auto-engaged. This matches bootstrap's existing pattern (Pre-Mortem: "optional, recommended"; Review: "optional"). The most relevant option is marked `(recommended)` based on context.

### Single Registry File (preserved from rev 0)

All plugin-to-workflow mappings live in one file: `commands/plugin-enhancers.md`. Workflow commands reference this file's patterns at their integration seams.

### Detection via installed_plugins.json [NEW — addresses F1]

Plugin availability is determined by reading `~/.claude/plugins/installed_plugins.json`. This file is maintained by Claude Code's plugin system and contains all installed plugins with their names and versions. It is deterministic, fast (single file read), and requires no custom API.

**Detection protocol** (canonical — all commands MUST use this):

```
PLUGIN DETECTION PROTOCOL

Step 1: Read ~/.claude/plugins/installed_plugins.json
  - If file doesn't exist → no plugins installed, skip all enhancements
  - If file exists → parse JSON, extract plugin names from top-level keys

Step 2: For each plugin needed at this seam, check if its key exists:
  - Key format: "<plugin-name>@<marketplace-name>"
  - Example: "pr-review-toolkit@claude-code-plugins"
  - Match on plugin name prefix (ignore marketplace suffix)

Step 3: If plugin is detected, offer its capabilities
  - If plugin is NOT detected, silently skip (no error, no warning)

TIMEOUT: If file read takes >3 seconds, abort detection and proceed without enhancements.
FALLBACK: If JSON parsing fails, log warning and proceed without enhancements.
```

**Why this works:** Claude Code already maintains this file. We're reading it, not writing it. No new mechanism needed. The file is updated when plugins are installed/uninstalled — we inherit that lifecycle for free.

**What this does NOT solve:** Agent-level detection (checking if a specific agent within a plugin exists). If a plugin is installed but an agent was removed in a version update, we'll attempt dispatch and handle the failure gracefully (see Failure Modes).

### Registry Maintenance Model [NEW — addresses F2]

The registry (`plugin-enhancers.md`) is **maintained by the bootstrap project** (not by plugin authors). It documents known plugins as of each bootstrap release.

**Ownership:** Bootstrap maintainers update the registry when:
1. A new plugin is added to the user's recommended set
2. A plugin renames agents (discovered via issue report or testing)
3. A new bootstrap release is prepared

**Staleness mitigation:**
1. Registry entries include a `tested_with` version note (e.g., "pr-review-toolkit v1.0.0")
2. Agent dispatch failures are handled gracefully (see Failure Modes) — stale entries degrade, not crash
3. Detection is at the PLUGIN level (installed_plugins.json), not the AGENT level — plugin renames are rare, agent renames are common but handled by graceful dispatch failure

**Update protocol:** PRs to `commands/plugin-enhancers.md` in the claude-bootstrap repo. Plugin authors can submit PRs. Bootstrap releases include registry updates in the changelog.

### No Package Dependencies (renamed from "No New Dependencies" — addresses F5)

The plugin-enhancers system adds zero package dependencies. `install.sh` requires only bash and curl. If no plugins are installed, all workflows behave exactly as they do today. The enhancer sections in commands are effectively no-ops when no plugins are detected.

**Acknowledged overhead:** Modified commands gain ~30-80 lines of plugin integration logic per seam. This is conditional code that's dormant when plugins are absent, but present in the file. This is comparable to existing conditional logic (e.g., blueprint challenge modes add ~200 lines that are dormant in vanilla mode).

---

## Phased Rollout [NEW — addresses F10]

### Phase 1: Review Integration (Primary Deliverable)

Validate the core pattern with ONE seam and ONE plugin:

| Component | What | Plugin |
|-----------|------|--------|
| Registry (W1) | `commands/plugin-enhancers.md` with detection protocol | — |
| Blueprint Stage 5 (W3a) | Expanded external review options | pr-review-toolkit |
| /review deep analysis (W5) | Optional Stage 5 after core adversarial review | pr-review-toolkit |
| /dispatch extended lenses (W4) | Additional lens options | pr-review-toolkit |
| Documentation (W8a) | README + commands/README updates | — |

**Phase 1 validates:**
- Detection protocol works reliably
- Registry format is sufficient
- Plugin agent dispatch succeeds
- Results handling (advisory, tagged, size-limited) works
- Graceful degradation on missing plugins

### Phase 2: Execution Engines (Future)

Add technology-aware execution routing:
- `/describe-change` technology context detection
- Blueprint Stage 7 plugin-backed execution options
- Context handoff protocol for execution engines
- Rollback strategy for failed executions

**Phase 2 depends on:** Phase 1 working reliably + user feedback on the pattern.

### Phase 3: Project Setup + Testing (Future)

Add project-level integration:
- `/bootstrap-project` plugin-aware setup (claudemem indexing)
- `/test` enhanced quality analysis
- Per-project plugin disable list

**Phase 3 depends on:** Phase 2 working reliably.

---

## Component 1: Plugin Capability Registry

### File: `commands/plugin-enhancers.md`

A **reference command** (Claude reads it, users don't invoke directly) that documents available plugin integration slots, the detection protocol, and invocation patterns.

```yaml
---
description: Use when a workflow command reaches a plugin integration seam. Maps installed plugins to workflow enhancement options.
allowed-tools:
  - Read
---
```

### Registry Structure

The file contains:

**Section 1: Detection Protocol** — The canonical detection mechanism (installed_plugins.json check). All commands MUST use this protocol. No ad-hoc detection.

**Section 2: Capability Slots** — Abstract capabilities that plugins can fill:

| Slot | What It Provides | Phase | Used At |
|------|-----------------|-------|---------|
| `review:specialized` | Specialized review agents | **Phase 1** | `/review`, `/dispatch`, Blueprint Stage 5 |
| `review:multi-model` | Multi-model consensus review | **Phase 1** | `/review`, Blueprint Stage 5 |
| `review:cross-platform` | Cross-platform adversarial (Claude+GPT) | existing | Blueprint Stage 5 (already `/gpt-review`) |
| `execute:frontend` | Frontend-guided implementation | Phase 2 | Blueprint Stage 7, `/describe-change` |
| `execute:backend` | Backend-guided implementation | Phase 2 | Blueprint Stage 7, `/describe-change` |
| `execute:feature` | Technology-agnostic guided dev | Phase 2 | Blueprint Stage 7, `/describe-change` |
| `test:quality` | Enhanced test quality analysis | Phase 3 | `/test` Stage 3 |
| `search:semantic` | Semantic code search (claudemem) | Phase 3 | `/bootstrap-project` setup |
| `iterate:loop` | Self-referential iteration loops | Phase 2 | Blueprint Stage 7 |

**Section 3: Plugin-to-Slot Mapping** — For each known plugin:

```markdown
### pr-review-toolkit (Phase 1)

**Fills:** `review:specialized`
**Tested with:** v1.0.0 (claude-code-plugins marketplace)
**Detection:** Check installed_plugins.json for key containing "pr-review-toolkit"
**Agents:**
  - pr-review-toolkit:silent-failure-hunter
  - pr-review-toolkit:type-design-analyzer
  - pr-review-toolkit:pr-test-analyzer
  - pr-review-toolkit:comment-analyzer
  - pr-review-toolkit:code-simplifier
  - pr-review-toolkit:code-reviewer

**Invocation:**
  Dispatch via Task tool: subagent_type = "pr-review-toolkit:<agent-name>"
  Each agent receives: file paths to review + context summary
  Results: markdown format, advisory only

**If agent dispatch fails:**
  Log: "[PLUGIN] pr-review-toolkit:<agent> dispatch failed: <error>"
  Action: Skip this agent, continue with remaining agents
  User message: "Note: <agent> unavailable, continuing with remaining analyses"
```

Similar entries for: `frontend` (Phase 1 — fills `review:multi-model`), `feature-dev` (Phase 2), `bun` (Phase 2), `ralph-wiggum` (Phase 2), `testing-suite` (Phase 3), `code-analysis` (Phase 3).

**Section 4: Graceful Degradation Rules**

1. **Plugin not installed:** Slot not offered. No error, no warning, no log.
2. **Plugin installed but agent dispatch fails:** Log failure, skip agent, continue workflow. Show user one-line note: "Note: [agent] unavailable, skipping."
3. **Plugin returns oversized output (>2000 tokens):** Truncate to 2000 tokens, append `[truncated — full output available via direct plugin invocation]`.
4. **Multiple plugins fill same slot:** Offer all as options, ordered alphabetically by plugin name.
5. **Detection file missing or unparseable:** Skip all enhancements. Log: "[PLUGIN] installed_plugins.json not found or corrupted, skipping plugin detection."
6. **Detection exceeds 3-second timeout:** Abort, proceed without enhancements.

**Section 5: Plugin Results Format**

All plugin results MUST be formatted as:

```markdown
### [plugin-review] pr-review-toolkit: silent-failure-hunter

**Findings:**
- [severity: high] Description of finding (file:line)
- [severity: medium] Description of finding (file:line)

**Summary:** N findings (N high, N medium, N low)
```

Max 2000 tokens per agent. Tag `[plugin-review]` enables filtering and distinguishes from debate chain findings (which CAN trigger regressions — plugin results CANNOT).

**"Advisory" semantics defined:** Plugin results are surfaced to the user for awareness. They are appended to the relevant output file (adversarial.md, review summary, etc.). They do NOT block workflow progression. They do NOT affect confidence scoring. They do NOT trigger regression logic. The user may choose to act on them or ignore them.

### Success Criteria
- [ ] Detection protocol reads installed_plugins.json successfully
- [ ] Detection returns empty set gracefully when file is missing
- [ ] Registry documents all Phase 1 plugins with tested versions
- [ ] Graceful degradation rules cover all 6 scenarios
- [ ] Plugin results format is defined with token limits

---

## Component 2: Blueprint Stage 5 Modification (Phase 1)

### Current Behavior
Offers only `/gpt-review` as external review.

### New Behavior
Present expanded options based on detected plugins:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BLUEPRINT: [name] │ Stage 5 of 7: External Review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  External review options:

    [1] GPT Surgical Review (/gpt-review)
        Claude diagnoses → GPT implements fixes → Claude reviews PR

  [If pr-review-toolkit detected in installed_plugins.json:]
    [2] Deep Dive — pr-review-toolkit agents
        6 specialized lenses: silent failures, type design,
        test coverage, comments, simplification, conventions

  [If frontend plugin detected:]
    [3] Multi-Model Consensus
        Parallel assessment from multiple AI models

    [N] Skip — local challenge stages were sufficient

>
```

Options are numbered dynamically. Always starts with GPT review (existing), always ends with Skip. Plugin options only appear when the corresponding plugin is detected.

### Invocation

- **GPT Review**: Existing `/gpt-review` invocation (unchanged)
- **Deep Dive**: Dispatch up to 6 pr-review-toolkit agents in parallel via Task tool. Each receives: spec.md summary + adversarial.md summary + file paths to review. 5-minute timeout per agent. Collect results, format per Section 5, present consolidated.
- **Multi-Model**: Invoke `frontend:review` command if available.

### Results Handling

Plugin review findings are appended to `adversarial.md` under a `## Plugin Review Findings` heading with the `[plugin-review]` tag. They are advisory per the defined semantics (see Component 1, Section 5).

### Success Criteria
- [ ] Existing GPT review option works identically to current behavior
- [ ] Plugin options only appear when plugins are detected
- [ ] Plugin findings are appended to adversarial.md with correct tags and format
- [ ] Plugin agent failures don't halt the blueprint workflow
- [ ] Each agent result is ≤2000 tokens
- [ ] 5-minute timeout per agent is enforced

---

## Component 3: `/review` Deep Analysis Stage (Phase 1)

### Current Behavior
4-stage adversarial review: Devil's Advocate → Simplify → Edge Cases → GPT Review (optional).

### New Behavior
After the existing 4 stages complete, add an optional **Stage 5: Plugin Deep Analysis**:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 5 of 5: Deep Analysis (optional)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Core adversarial review complete.

  Deep analysis available:
    [1] PR Toolkit — 6 specialized agents in parallel
        (silent failures, type design, test coverage, ...)
    [2] Skip — core review is sufficient

>
```

This stage only appears if `review:specialized` slot is filled (pr-review-toolkit detected).

Results are incorporated into the Review Summary under a new "### Deep Analysis" section.

Quick mode (`/review --quick`) skips this stage entirely.

### Success Criteria
- [ ] Existing 4-stage review works identically when no plugins installed
- [ ] Stage 5 only appears when pr-review-toolkit is detected
- [ ] Results are added to the summary under correct heading
- [ ] Quick mode skips plugin stages

---

## Component 4: `/dispatch` Extended Lenses (Phase 1)

### Current Behavior
`--lenses` accepts: `security`, `perf`, `arch`, `cfn`.

### New Behavior
Register pr-review-toolkit agents as additional lens options:

| Lens Name | Agent | Source | Phase |
|-----------|-------|--------|-------|
| `security` | security-reviewer | bootstrap | existing |
| `perf` | performance-reviewer | bootstrap | existing |
| `arch` | architecture-reviewer | bootstrap | existing |
| `cfn` | cloudformation-reviewer | bootstrap | existing |
| `silent-failures` | pr-review-toolkit:silent-failure-hunter | plugin | **Phase 1** |
| `types` | pr-review-toolkit:type-design-analyzer | plugin | **Phase 1** |
| `comments` | pr-review-toolkit:comment-analyzer | plugin | **Phase 1** |
| `simplify` | pr-review-toolkit:code-simplifier | plugin | **Phase 1** |
| `test-coverage` | pr-review-toolkit:pr-test-analyzer | plugin | **Phase 1** |

Extended lenses only available when pr-review-toolkit is detected. If user requests an extended lens and the plugin isn't installed, show:

```
Lens 'silent-failures' requires pr-review-toolkit plugin (not installed).
Proceeding with standard lenses only.
```

**Tip line**: After standard review completes, if pr-review-toolkit is detected:
```
Review complete (spec: PASS, quality: PASS).
Tip: Extended lenses available: --lenses silent-failures,types,comments,simplify,test-coverage
```

### Success Criteria
- [ ] Standard lenses work identically to current behavior
- [ ] Extended lenses dispatch correct pr-review-toolkit agents
- [ ] Missing plugin produces clear message, not error
- [ ] Mixed standard + extended lens combinations work

---

## Component 5: Documentation Updates (Phase 1)

### Files to Update

1. **`commands/README.md`** — Add plugin-enhancers to command reference under new "Integration" category. Document as reference command (not user-facing).
2. **`README.md`** — Add "Plugin Integration" section: what enhancers are, how detection works, Phase 1 scope, future phases.
3. **`.claude/CLAUDE.md`** (repo's own docs) — Add plugin-enhancers to architecture overview. Note new command in command count.
4. **`GETTING_STARTED.md`** — Add brief "Plugins" note: "If you have Claude Code plugins installed, bootstrap workflows will offer plugin-powered enhancements at review stages."

### Success Criteria
- [ ] All four files updated
- [ ] Command count in README reflects new command
- [ ] Plugin integration section is clear for users who have zero plugins

---

## Schema Changes [NEW — addresses F4]

### state.json Additions

New optional fields (additive — old blueprints remain valid):

```json
{
  "plugin_enhancers_version": "1.0",
  "plugins_detected": ["pr-review-toolkit", "frontend"],
  "plugin_results": {
    "stage_5_review": {
      "plugins_used": ["pr-review-toolkit"],
      "agents_dispatched": 6,
      "agents_succeeded": 5,
      "agents_failed": 1,
      "total_findings": 12
    }
  }
}
```

### Migration Rules

When resuming a blueprint that lacks `plugin_enhancers_version`:
- Default all plugin fields to `null`
- Plugin features silently unavailable (no migration prompt, no error)
- If user reaches a plugin seam, detection runs fresh
- No schema version bump required — fields are purely optional

When resuming a blueprint WITH `plugin_enhancers_version` on a bootstrap install WITHOUT plugin-enhancers:
- Unknown fields are ignored by old commands (JSON is forward-compatible)
- Blueprint resumes normally on its current stage

### Backward Compatibility Test Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Old blueprint resumes on new bootstrap (with plugins) | Plugin features available at future seams, no migration needed |
| Old blueprint resumes on new bootstrap (no plugins) | Identical to current behavior |
| New blueprint resumes on old bootstrap | Unknown fields ignored, works normally |
| Blueprint created with plugins, resumed without plugins | Plugin seams silently skipped |

---

## Execution Rollback Protocol [NEW — addresses M1]

> **Note:** This section applies to Phase 2 (execution engines). Included here for completeness.

When a plugin execution engine is selected at Blueprint Stage 7 and fails:

1. **state.json records:** `"execution_option": "frontend:implement", "execution_status": "failed", "execution_error": "<reason>"`
2. **User prompt:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EXECUTION FAILED │ frontend:implement
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Error: [description]
  Duration: [time]

  Options:
    [1] Retry same engine
    [2] Switch to standard implementation (sequential)
    [3] Switch to parallel dispatch (/delegate)
    [4] Abort — inspect partial changes manually

>
```
3. **On switch:** Clear `execution_option` and `execution_status`, set `execution_status: "retrying"`. Partial changes from the failed engine remain in the working directory for the user to inspect.
4. **Git safety:** If `--isolate` was used (worktree), the failed attempt is in an isolated worktree and can be discarded cleanly.

---

## Context Handoff Protocol [NEW — addresses M2]

> **Note:** This section applies to Phase 2. Included here for completeness.

When passing blueprint context to a plugin execution engine:

```
CONTEXT HANDOFF FORMAT

The workflow command constructs a context summary and includes it
in the Task prompt for the plugin agent:

  BLUEPRINT CONTEXT:
  - Spec: [inline summary of spec.md, ≤1000 tokens]
  - Known Risks: [inline summary of adversarial.md critical+high findings]
  - Test Criteria: [inline summary of tests.md acceptance criteria]
  - Work Units: [inline list from work-graph.json]

  Full artifacts available at:
  - .claude/plans/[name]/spec.md
  - .claude/plans/[name]/adversarial.md
  - .claude/plans/[name]/tests.md
  - .claude/plans/[name]/work-graph.json

Context is passed INLINE in the Task prompt (not as env vars or file paths only),
because subagents may not have access to the same filesystem context.
```

---

## Preservation Contract (updated from rev 0)

The following MUST NOT change:

1. **Workflow stage structures** — Blueprint still has 7 stages, Review still has 4 core stages, Test still has 3 core stages
2. **Enforcement language** — No escape hatches, no softening of existing MUST-tier triggers
3. **Defense-in-depth model** — Shell hooks, hookify rules, CLAUDE.md guidance layers unchanged
4. **Empirica integration** — Preflight/postflight/finding/mistake logging unchanged
5. **Existing option numbering** — Current options at each decision point keep their numbers; plugin options are appended after
6. **No package dependency guarantee** — bootstrap installs and works with `bash` and `curl` only
7. **Manifest/state.json backward compatibility** — New fields are optional and additive; old blueprints resume without migration (see Schema Changes)
8. **[NEW] Detection mechanism** — All commands MUST use the canonical detection protocol (installed_plugins.json). No ad-hoc detection methods.

---

## Work Units (Phase 1 only)

| ID | Unit | Dependencies | Est. Complexity |
|----|------|-------------|-----------------|
| W1 | Create `commands/plugin-enhancers.md` (registry + detection protocol + format rules) | None | Medium |
| W1-review | Validate W1: test detection against installed_plugins.json, confirm agent dispatch works | W1 | Low |
| W2 | Modify `commands/blueprint.md` (Stage 5 expanded review options) | W1-review | Medium |
| W3 | Modify `commands/review.md` (deep analysis Stage 5) | W1-review | Low |
| W4 | Modify `commands/dispatch.md` (extended lenses) | W1-review | Low |
| W5 | Update documentation (README, commands/README, CLAUDE.md, GETTING_STARTED) | W2, W3, W4 | Medium |

**Critical path:** W1 → W1-review → [W2, W3, W4 in parallel] → W5

**Work graph width:** 3 (W2, W3, W4 concurrent after W1-review gate)

**Phase 1 total:** 6 work units (down from 8 in rev 0)

### W1-review Gate [NEW — addresses F8]

After W1 is complete, validate before proceeding:
1. Read `~/.claude/plugins/installed_plugins.json` — confirm it parses correctly
2. Check for `pr-review-toolkit` in the parsed data — confirm detection logic works
3. Attempt to dispatch one pr-review-toolkit agent via Task tool — confirm invocation works
4. Verify the result fits the defined format (markdown, ≤2000 tokens)

Only proceed to W2-W4 after all 4 checks pass. If any check fails, revise W1 before continuing.

---

## Failure Modes (expanded — addresses F6)

| Failure | Impact | Mitigation |
|---------|--------|------------|
| **Detection** | | |
| installed_plugins.json missing | No plugins detected | Graceful: skip all enhancements, no error |
| installed_plugins.json malformed | Can't parse | Log warning, skip all enhancements |
| Detection takes >3 seconds | Workflow lag | Timeout, abort detection, continue |
| **Plugin Dispatch** | | |
| Agent dispatch fails (agent renamed/removed) | Enhancement unavailable | Log "[PLUGIN] agent dispatch failed", skip agent, show user note |
| Agent times out (>5 min) | Workflow delayed | Kill agent, log timeout, continue with partial results |
| Agent returns non-markdown output | Can't format | Wrap in code block, append as-is |
| Agent returns >2000 tokens | Context bloat | Truncate, append "[truncated]" note |
| **Integration** | | |
| Plugin installed but older/newer than tested_with version | May have different agents | Dispatch attempt handles gracefully — works or fails cleanly |
| Two plugins fill same slot | Multiple options shown | Both offered, alphabetical order, user picks |
| User requests extended lens but plugin not installed | Confusing error | Clear message: "Lens requires [plugin] (not installed)" |
| Registry references plugin that was uninstalled | Phantom slot | Detection (installed_plugins.json) prevents — plugin won't be found |
| **State** | | |
| Blueprint resumed without plugin-enhancers | Unknown fields in state.json | Fields ignored — JSON forward-compatible |
| Blueprint created with plugins, resumed without | Plugin seams unavailable | Silently skipped, no error |
| Plugin execution fails mid-run (Phase 2) | Partial changes in working directory | Rollback prompt (see Execution Rollback Protocol) |

---

## Logging Protocol [NEW — addresses F9]

### Responsibility
The **workflow command** that invokes the plugin is responsible for logging. Never rely on the plugin to log its own failure.

### Format
```
[PLUGIN] <plugin-name>:<agent-name> <event>: <detail>
```

Examples:
```
[PLUGIN] pr-review-toolkit:silent-failure-hunter dispatched successfully
[PLUGIN] pr-review-toolkit:type-design-analyzer timed out after 5min
[PLUGIN] pr-review-toolkit:code-reviewer dispatch failed: agent not found
[PLUGIN] detection skipped: installed_plugins.json not found
```

### Destinations
1. **Empirica** (if session active): `deadend_log` for failures, `finding_log` for successful plugin insights
2. **User-facing**: One-line note in workflow output (e.g., "Note: type-design-analyzer unavailable, skipping")
3. **If Empirica unavailable**: Log to stderr only (fail-open, no file creation)

### What's NOT logged
- Successful detection (silent — reduces noise)
- Plugin results content (already in adversarial.md)
- Per-token metrics (out of scope for Phase 1)
