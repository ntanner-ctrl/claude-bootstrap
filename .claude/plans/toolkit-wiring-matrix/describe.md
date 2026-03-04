# Triage: toolkit-wiring-matrix

## Change Summary
Wire all disconnected toolkit components (orphaned commands, unwired plugins, missing cross-references) into the existing workflow fabric so every tool is discoverable through natural routing.

## Context
Audit revealed: 2 true orphan commands (zero inbound refs), 4 weak islands, 8 plugins with zero workflow integration, 1 ghost plugin entry (frontend), missing insight-capture callouts on 3 audit commands, Phase 2 plugin seams not activated.

## Steps (25)
1. Fix frontend ghost entry in blueprint Stage 5 + review Stage 5
2. Add `/vault-query` reference to `/start`
3. Add `/toolkit` escape hatch to `/start`
4. Add `/requirements-discovery` fork to `/describe-change`
5. Add `/collect-insights` callout to `/security-checklist`
6. Add `/collect-insights` callout to `/design-check`
7. Add `/collect-insights` callout to `/requirements-discovery`
8. Fix `/process-doc` dead links (3 non-existent sibling commands)
9. Add `/migrate-docs` reference to `/bootstrap-project`
10. Add `/approve` reference to `/status`
11. Wire commit-commands into `/push-safe`
12. Wire git-workflow into `/blueprint` completion
13. Wire hookify into `/debug`
14. Wire documentation-generator into `/end`
15. Wire devops-automation into `/security-checklist`
16. Wire plugin-dev into `/spec-agent`
17. Wire agentdev into `/spec-agent`
18. Wire project-management-suite into `/start`
19. Cross-reference `/end` ↔ `/collect-insights`
20. Add extended lens table to `/delegate` (match `/dispatch`)
21. Activate Phase 2 seams: code-analysis → `/debug`
22. Activate Phase 2 seams: testing-suite → `/test`
23. Activate Phase 2 seams: ralph-wiggum → `/blueprint` Stage 7
24. Update plugin-enhancers.md registry for new seams
25. Update README.md + commands/README.md counts if needed

## Risk Flags
- User-facing behavior change (commands suggest new tools)

## Path: Full
## Execution Preference: Auto
