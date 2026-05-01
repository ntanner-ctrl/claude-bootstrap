# Describe: prism

## Change Summary

Add a new `/prism` command — a holistic code health assessment that examines any project through multiple paradigm lenses and serial domain reviews, producing a themed remediation plan.

## Context

Current review infrastructure (quality-sweep + 6 reviewer agents) is scoped to recent changes and runs agents in parallel without shared context. Prism fills the gap: whole-project assessment where each review stage reads accumulated findings from prior stages, and a parallel paradigm swarm provides cross-cutting observations that enrich the domain reviews.

Key design decisions from brainstorming:
- Serial domain review (not parallel) so later agents respect earlier constraints
- Paradigm lens agents are observation-only (flag patterns, don't suggest fixes)
- Output organized by themes, not by agent
- Remediation plan categorizes fixes as discrete (specific file:line) or nebulous (pattern + scope)
- Vault-aware at context-gathering and output stages for longitudinal tracking

## Steps

1a. Create `dry-lens` agent
1b. Create `yagni-lens` agent
1c. Create `kiss-lens` agent
1d. Create `consistency-lens` agent
1e. Create `cohesion-lens` agent
1f. Create `coupling-lens` agent
2. Create `prism` orchestrator command (`commands/prism.md`)
3. Create vault-notes template for prism reports (`commands/templates/vault-notes/prism-report.md`)
4. Update `settings-example.json` if needed (likely no changes — prism is a command, not a hook)
5. Update `commands/README.md` with new command entry
6. Update `README.md` with prism in command counts and "at a glance"
7. Update `test.sh` expected counts (agents, commands)
8. Wire agents into `install.sh` output message (agent count update)

## Risk Flags

- User-facing behavior change (new command in toolkit distribution)

## Triage

- **Path:** Full
- **Execution preference:** Auto
- **Challenge mode:** Debate
