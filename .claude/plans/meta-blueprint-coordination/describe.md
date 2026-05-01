# Describe: Meta-Blueprint Coordination

## What is being changed?

Add a meta-blueprint coordination system to claude-sail — three integrated components:

1. **Debrief Stage (Stage 8)** — A mandatory completion ceremony for ALL blueprints. Updates state.json to "complete", captures ship reference (commit hashes), spec delta (what changed from original spec), deferred items, and lessons learned. For linked blueprints, additionally surfaces discoveries that affect parent/sibling blueprints.

2. **`/link-blueprint` command** — Declares parent/child relationships between blueprints. User runs `/link-blueprint child-name --parent meta-name` to establish bidirectional linkage. Sub-blueprint state.json gets a `parent` field; meta-blueprint gets a `meta_units` map tracking sub-blueprint status.

3. **Commit-Time Blueprint Signal** — When active blueprints exist, the commit flow prompts "does this advance a blueprint?" and logs to `.claude/plans/<name>/commits.jsonl`. Implemented as a plugin-enhancer integration (not a core hook) since `/commit` comes from the commit-commands plugin.

## Why?

Scout March 2026 sprint proved:
- 10/11 state.json files went stale because blueprints "just end" without a completion ceremony
- Sub-blueprint discoveries changed meta assumptions with no propagation protocol
- Lateral drift between sibling blueprints was invisible
- Supersession chains existed only in human memory

## Prior Art Search

| Area | Exists | Missing |
|------|--------|---------|
| Blueprint execute stage | Yes — Stage 7 in state.json | No post-execute closing ceremony |
| Work unit dependencies | Yes — work-graph.json edges | No cross-blueprint dependencies |
| Parent/child blueprints | No | No `parent`, `meta_units` fields |
| Commit blueprint awareness | No | `/commit` is a plugin, not core sail |
| Blueprint vault export | Yes — completion summary | No debrief-specific export |
| Existing reflection | Yes — reflect.md (post-implementation) | Not gated, easily skipped |

Key finding: `/commit` comes from the `commit-commands` plugin, not from sail core. The commit-time signal should be a plugin-enhancer integration rather than a direct modification.

## Files Affected

| Action | Target | Description |
|--------|--------|-------------|
| Modify | `commands/blueprint.md` | Add debrief stage after execute, add meta-awareness |
| Create | `commands/link-blueprint.md` | New command for parent/child declaration |
| Modify | `docs/PLANNING-STORAGE.md` | Debrief schema, parent/meta_units fields, commits.jsonl |
| Modify | `commands/plugin-enhancers.md` | Add commit-commands blueprint integration |
| Modify | `test.sh` | Update command count, add debrief/linkage validations |
| Modify | `README.md` | Update command count, document feature |
| Modify | `commands/README.md` | Add /link-blueprint entry |
| Create | `evals/evals.json` entries | Behavioral eval fixtures for debrief |

## Risk Flags

1. **Modifies blueprint.md** — most complex command (~1600+ lines)
2. **Extends state.json schema** — must not break 23 existing plan directories
3. **Plugin integration seam** — commit-commands is external, needs graceful degradation

## Triage

| Dimension | Score |
|-----------|-------|
| Files touched | 7-8 |
| Risk flags | 2 (blueprint complexity, schema compat) |
| Novelty | Medium (new concept on existing patterns) |
| Reversibility | High (additive, no breaking changes) |

**Recommended path: Full**
**Execution preference: auto**

## Scope Boundaries

**In scope:**
- Debrief stage for all blueprints (universal value)
- Parent/child linkage within a single project
- Commit-time signal via plugin-enhancer pattern
- Backward-compatible schema extensions

**Out of scope:**
- Cross-project coordination (deferred)
- Auto-detection of blueprint relationships (user declares explicitly)
- Retroactive debrief for completed blueprints (new blueprints only)
- Research pipeline (separate upcoming session)
