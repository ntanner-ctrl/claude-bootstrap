# Triage: plugin-enhancers

## Change
Adding a plugin integration layer to claude-bootstrap — a capability registry and workflow seam modifications that allow external Claude Code plugins (pr-review-toolkit, feature-dev, frontend, code-analysis, ralph-wiggum, etc.) to augment existing bootstrap workflows at natural decision points, without changing the core workflow structures or adding hard dependencies.

## Steps (9 discrete actions)
1. Create the plugin capability registry file — maps installed plugins to workflow integration slots
2. Modify `/describe-change` — add technology context detection and plugin-aware routing
3. Modify `/blueprint` Stage 5 — expand external review options
4. Modify `/blueprint` Stage 7 completion — add plugin-backed execution options
5. Modify `/dispatch` review pipeline — register extended lens options from plugins
6. Modify `/review` — add optional deep-analysis stage using plugin agents
7. Modify `/test` — add optional enhanced test quality analysis
8. Modify `/bootstrap-project` — add plugin-aware setup step
9. Update documentation — CLAUDE.md, README.md, commands/README.md

## Risk Flags
- [x] User-facing behavior change

## Triage
- Steps: 9
- Risk flags: 1
- Path: **Full**
- Execution preference: **Auto**
