# Specification: toolkit-wiring-matrix

## Summary

Wire all disconnected toolkit components into the existing workflow fabric. Every command should have >=1 inbound reference, every plugin should have a natural seam, and every audit-type command should capture insights.

## Tracks

### Track A: Command Cross-References (Steps 1-10, 19-20)

Surgical edits to existing commands — add cross-references at natural decision points.

### Track B: Plugin Seams (Steps 11-18, 21-24)

Wire standalone plugins into workflow commands and activate Phase 2 registry entries.

### Track C: Documentation (Step 25)

Update counts/tables in README files if needed.

---

## Work Units

### WU-1: Fix Ghost + Orphans (Steps 1-3, 10)

**Files:** `commands/blueprint.md`, `commands/review.md`, `commands/start.md`, `commands/status.md`

**Changes:**

1. **blueprint.md Stage 5** (~line 871): Add frontend to the options block. Between the superpowers/feature-dev option and the Skip option, add:
   ```
   [If frontend detected:]
     [N] Multi-Model Consensus — frontend:reviewer
         Parallel assessment from multiple AI models
   ```
   Note: This option already exists in the Stage 5 Options Presentation template (it's documented there). Verify it's also in the ACTUAL option-building logic lower in the file. If already present in the logic section, this is a no-op.

2. **review.md Stage 5** (~line 95-151): Add frontend to Deep Analysis options. After the feature-dev entry, before Skip:
   ```
   [If frontend detected:]
     [N] Multi-Model Review — frontend:reviewer
         Parallel assessment from multiple AI models
   ```

3. **start.md** (~line 105-112): In the alternatives/output section, add:
   - After vault context display: `Search deeper: /vault-query`
   - At bottom of alternatives: `Full command index: /toolkit`
   - If project context suggests planning: `Need roadmap? project-management-suite has product-strategist and business-analyst agents`

4. **status.md** (~line 124-128): Add to "Leads to" list:
   ```
   - **Leads to:** `/blueprint [name]`, `/overrides`, `/approve` (advance a stage)
   ```

### WU-2: Insight Capture Gaps (Steps 5-7)

**Files:** `commands/security-checklist.md`, `commands/design-check.md`, `commands/requirements-discovery.md`

**Changes:**

1. **security-checklist.md** (after line 314): Add integration section:
   ```markdown
   ## Integration

   - **Insight capture:** Security findings are high-value epistemic data. Run `/collect-insights` after completing the checklist to flush findings to vault + Empirica.
   - **Deeper audit:** If `security-pro` plugin is installed, run `/security-audit` for comprehensive vulnerability assessment.
   - **Infrastructure focus:** If `devops-automation` plugin is installed, the `cloud-architect` agent can review infrastructure security posture.
   ```

2. **design-check.md** (replace lines 128-133): Expand integration:
   ```markdown
   ## Integration

   - Use `/blueprint` for full planning workflow (includes this as a phase check)
   - Use `/spec-change` to formalize requirements identified here
   - Use `/edge-cases` to probe boundaries identified in step 1
   - **Insight capture:** Prerequisite gaps and design boundary discoveries are prime findings material. Run `/collect-insights` to flush to vault + Empirica.
   ```

3. **requirements-discovery.md** (after line 118, before $ARGUMENTS): Add integration section:
   ```markdown
   ## Integration

   - **Feeds into:** `/spec-change`, `/blueprint` Stage 2
   - **Fed by:** `/brainstorm` (if direction unclear)
   - **Insight capture:** Requirement gaps and stakeholder constraints are epistemic gold. Run `/collect-insights` to flush to vault + Empirica.
   ```

### WU-3: Orphan Rescue + Cleanup (Steps 4, 8-9, 19)

**Files:** `commands/describe-change.md`, `commands/process-doc.md`, `commands/bootstrap-project.md`, `commands/end.md`, `commands/collect-insights.md`

**Changes:**

1. **describe-change.md** (~line 62, Step 2): After the decomposition red flags table, add:
   ```
   **Requirements unclear?** If the user can't articulate steps clearly, suggest:
   > Requirements seem unclear. Consider running `/requirements-discovery` first to validate assumptions.
   ```

2. **process-doc.md** (lines 28-31 and 130-138): Fix dead links to non-existent sibling commands:
   - Replace `/tutorial-doc` references with: `templates/documentation/tutorial template`
   - Replace `/reference-doc` references with: `templates/documentation/reference template`
   - Replace `/explanation-doc` references with: `templates/documentation/explanation template`
   - Update Related Skills table to reference templates instead of planned commands
   - Add note: "Use `/process-doc` for how-to guides. For other Diataxis types, use the templates in `commands/templates/documentation/`"

3. **bootstrap-project.md** (~line 427-435, Next Steps): Add docs suggestion:
   ```
   4. Existing documentation? Run `/migrate-docs` to restructure into Diataxis framework
   ```

4. **end.md** (~line 267): In Step 3 intro, add cross-reference:
   ```
   **Note:** For mid-session insight capture, use `/collect-insights` directly.
   This step runs the same sweep automatically at session close.
   ```

5. **collect-insights.md** (~line 152, Examples section): Add cross-reference:
   ```
   **Relationship to `/end`:** The `/end` command runs this same insight sweep
   automatically (Step 3). Use `/collect-insights` for mid-session flushes;
   `/end` handles the final sweep at session close.
   ```

### WU-4: Plugin Seam Wiring (Steps 11-18)

**Files:** `commands/push-safe.md`, `commands/blueprint.md`, `commands/debug.md`, `commands/end.md`, `commands/security-checklist.md`, `commands/spec-agent.md`, `commands/start.md`

**Changes:** Small "also available" callouts at natural decision points. These are 1-3 line additions, not workflow changes. Format: check if plugin is installed via `~/.claude/plugins/installed_plugins.json`, mention only if detected.

However — since these are markdown command files (not executable scripts), we can't do runtime detection. Instead, use the same pattern as plugin-enhancers.md: **conditional display instructions**.

1. **push-safe.md** (after Step 5, ~line 70): Add:
   ```
   ### Plugin Integration
   If `commit-commands` plugin is detected (check `~/.claude/plugins/installed_plugins.json`):
   suggest `/commit` for streamlined commit workflow before pushing.
   ```

2. **blueprint.md completion** (~line in completion section): Add after implementation options:
   ```
   [If git-workflow plugin detected:]
     Working on a feature branch? `/feature` and `/finish` manage Git Flow lifecycle.
   ```

3. **debug.md** (~line 129, Integration section): Add:
   ```
   - **Same mistake recurring?** If `hookify` plugin is installed, run `/hookify` to create a prevention hook
   - **Deep investigation:** If `code-analysis` plugin is installed, use `/analyze` or the `detective` agent for deep code path tracing
   ```

4. **end.md** (near session summary section): Add:
   ```
   [If documentation-generator plugin detected:]
     Docs changed this session? Run `/update-docs` before closing.
   ```

5. **security-checklist.md**: Already covered in WU-2 (devops-automation reference).

6. **spec-agent.md** (~line 190, after "Implement → Create the agent file"): Add:
   ```
   • Full-cycle development → `/develop` (agentdev plugin) for multi-model agent creation
   • Building a plugin? → `/create-plugin` (plugin-dev plugin) for guided plugin workflow
   ```

7. **start.md**: Already covered in WU-1 (project-management-suite reference).

### WU-5: Delegate Lens Table + Phase 2 Activation (Steps 20-24)

**Files:** `commands/delegate.md`, `commands/plugin-enhancers.md`, `commands/debug.md`, `commands/test.md`, `commands/blueprint.md`

**Changes:**

1. **delegate.md** (~lines 281-298): Expand lens table to match dispatch.md:
   ```markdown
   | Lens | Agent | Focus |
   |------|-------|-------|
   | `security` | security-reviewer | OWASP top 10, injection, auth gaps |
   | `perf` | performance-reviewer | N+1 queries, blocking I/O, allocations |
   | `arch` | architecture-reviewer | Layer violations, circular deps, cohesion |
   | `cfn` | cloudformation-reviewer | Tagging, naming, security posture, CF best practices |

   **Extended lenses** (require plugins — availability depends on what's installed):

   | Lens | Agent | Plugin | Focus |
   |------|-------|--------|-------|
   | `silent-failures` | pr-review-toolkit:silent-failure-hunter | pr-review-toolkit | Silent failures, error handling |
   | `types` | pr-review-toolkit:type-design-analyzer | pr-review-toolkit | Type design, encapsulation |
   | `comments` | pr-review-toolkit:comment-analyzer | pr-review-toolkit | Comment accuracy |
   | `simplify` | pr-review-toolkit:code-simplifier | pr-review-toolkit | Simplification opportunities |
   | `test-coverage` | pr-review-toolkit:pr-test-analyzer | pr-review-toolkit | Test coverage gaps |
   | `deep-security` | security-pro:security-auditor | security-pro | Deep vulnerability assessment |
   | `deep-perf` | performance-optimizer:performance-engineer | performance-optimizer | Bottleneck identification |
   | `methodology` | superpowers:code-reviewer | superpowers | Methodology-based review |
   | `conventions` | feature-dev:code-reviewer | feature-dev | Convention-focused review |
   ```

   Update the tip block to include extended lenses.

2. **plugin-enhancers.md** (~lines 203-243): Update Phase 2 section to reflect activation:
   - code-analysis: mark seams as "Wired" at `/debug` HYPOTHESIZE step
   - testing-suite: mark seams as "Wired" at `/test` Stage 3
   - ralph-wiggum: mark seam as "Wired" at `/blueprint` Stage 7
   - Add new entries for plugins not yet in registry: commit-commands, git-workflow, hookify, plugin-dev, agentdev, documentation-generator, devops-automation, project-management-suite
   - Update Phase 1 Scope Reminder to reflect Phase 2 activations

3. **debug.md**: Plugin references already added in WU-4.

4. **test.md** (~lines 207-212): Expand integration:
   ```
   - **Deep test analysis:** If `testing-suite` plugin is installed, `/generate-tests` and `/test-coverage` provide comprehensive test automation
   ```

5. **blueprint.md** Stage 7: Add ralph-wiggum suggestion:
   ```
   [If ralph-wiggum plugin detected:]
     Long implementation? `/ralph-loop` adds verification checkpoints during execution.
   ```

### WU-6: Documentation Update (Step 25)

**Files:** `README.md`, `commands/README.md`

**Changes:**
- Verify command count is still 46 (no new commands added, just edits)
- No count changes expected — this is a verification-only WU
- If plugin-enhancers.md Phase 2 status change is significant, update the Plugin Integration section in README.md to note Phase 2 activations

---

## Work Graph

```
WU-1 (ghost + orphans)     ──┐
WU-2 (insight capture)      ──┤── all independent ──→ WU-6 (docs verification)
WU-3 (orphan rescue)        ──┤
WU-4 (plugin seams)         ──┤
WU-5 (delegate + phase 2)  ──┘
```

Width: 5 (WU-1 through WU-5 are independent)
Critical path: any WU → WU-6
Parallelization: strong recommendation for `/delegate`

---

## Constraints

- **No new commands** — only edits to existing files
- **No runtime detection** — commands are markdown, use conditional display instructions
- **Minimal additions** — 1-5 lines per edit point, not workflow restructuring
- **Plugin references are advisory** — "if detected" language, never block workflow
- **Preserve existing structure** — append to integration sections, don't reorganize
- **Max suggestions rule** — each command gets at most 2 plugin suggestions + 1 toolkit command. Prioritize by relevance to the command's purpose.
- **Advisory language** — plugin mentions use "Also available (user-initiated):" not imperative "Run /X". This prevents Claude from proactively invoking plugins the user didn't request.
- **"Wired" not "Active"** — Phase 2 entries in plugin-enhancers.md use "Wired" to mean "the command references this plugin" vs "Active" which implies runtime detection. Phase 1 = Active (runtime detection), Phase 2 = Wired (cross-reference only).
- **Vault-gated suggestions** — `/vault-query` suggestion in `/start` gated by: "If vault context was displayed above, search deeper with `/vault-query`"
- **Toolkit command cross-refs** — limited to direct-next-step suggestions (1-2 per command), not comprehensive menus. Only reference commands the user would naturally want at that decision point.
- **Dual table maintenance** — delegate.md's extended lens table mirrors dispatch.md. Add sync comment: `<!-- Extended lens table mirrors dispatch.md — keep in sync -->`

## Shared File Coordination

blueprint.md, end.md, debug.md, and start.md are touched by multiple WUs. To prevent conflicts:
- **blueprint.md**: WU-1 edits Stage 5 options. WU-4 edits completion section. WU-5 edits Stage 7 section. Non-overlapping zones — execute sequentially within the file.
- **end.md**: WU-3 edits Step 3 intro. WU-4 edits near session summary. Non-overlapping zones.
- **debug.md**: WU-4 edits integration section. WU-5 references it but doesn't edit (already handled by WU-4).
- **start.md**: WU-1 edits alternatives. WU-4 would also edit start.md but project-management-suite reference is consolidated into WU-1.
