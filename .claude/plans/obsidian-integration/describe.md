# Triage: Obsidian Integration — Hybrid Flywheel

## Change Summary

Add a bidirectional integration between the bootstrap toolkit and an Obsidian vault. Hooks automatically export engineering artifacts (decisions, findings, blueprint summaries, session logs) into linked Obsidian notes at session end. Session-start hooks query the vault to surface relevant past knowledge. New commands enable ad-hoc vault interaction.

**Vault location:** `/mnt/c/Users/nickt/Desktop/Work Stuff/Helvault` (WSL path to Windows Obsidian vault)

## Discrete Steps (10)

1. **Set up Obsidian vault directory structure** — Create folder hierarchy (Engineering/, Sessions/, Decisions/, Findings/, Blueprints/) and vault-level CLAUDE.md
2. **Install and configure Obsidian MCP server** — Wire `obsidian-claude-code-mcp` plugin into settings so Claude can read/write the vault
3. **Create note template system** — Markdown templates for each artifact type (Decision, Finding, Blueprint Summary, Session Log) with YAML frontmatter and `[[wiki-link]]` conventions
4. **Extend `/end` command** — Add vault export step alongside existing Empirica postflight: export session decisions, findings, blueprint summaries as linked vault notes
5. **Create SessionEnd vault export hook** — Shell-level safety net (mirrors `session-end-empirica.sh` pattern) that writes minimal session log to vault even if `/end` wasn't used
6. **Extend `session-bootstrap.sh`** — Add vault query at session start, inject relevant past knowledge into Claude's context alongside existing Empirica/command awareness
7. **Create `/vault-save` command** — Manual ad-hoc knowledge capture for ideas, research, notes
8. **Create `/vault-query` command** — Ad-hoc vault search to surface past decisions/patterns/learnings
9. **Update `install.sh` and `settings-example.json`** — Include new hooks, commands, MCP config in distribution
10. **Update documentation** — README counts, CLAUDE.md references, settings template

## Risk Scan

- [x] User-facing behavior change — Sessions now export to vault and query it on start
- All other risk categories: clear

## Triage Result

- **Steps:** 10 discrete actions
- **Risk flags:** 1 (user-facing behavior change)
- **Execution preference:** Auto
- **Recommended path:** Full
- **Challenge mode:** Debate (default)

## Key Design Decisions (from brainstorm)

- **Reuse existing seams:** `/end` command and `session-bootstrap.sh` are the primary integration points, not new standalone hooks
- **Obsidian MCP** for bidirectional access (Claude reads/writes vault)
- **Hook-enforced usage** (proven pattern from Empirica)
- **Engineering-primary but unified** vault — mostly dev artifacts but flexible enough for broader knowledge
- **Dependencies acceptable** — Obsidian + MCP server are opt-in but expected
