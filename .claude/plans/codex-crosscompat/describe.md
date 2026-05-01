# Describe: codex-crosscompat

## Change Summary

Build a conversion script (`scripts/convert-to-codex.sh`) that compiles claude-sail's 120+ Claude Code extension files into a parallel `codex/` distribution for OpenAI's Codex CLI, plus supporting infrastructure (adapter scripts, AGENTS.md generation, Codex installer, divergence tracking).

## Discrete Steps (11)

1. **Mechanical command adapter** — Strip YAML frontmatter from 65 commands, emit as plain markdown prompts to `codex/commands/`
2. **Mechanical agent adapter** — Convert 12 agents from YAML frontmatter `.md` to TOML frontmatter format for Codex
3. **Hook adapter shell wrapper** — Create `_codex-adapter.sh` that translates exit-code conventions to Codex JSON-stdout format
4. **Hook wiring generator** — Generate `codex/hooks.json` from `settings-example.json`, mapping 6 direct-port hooks + 3 adapted hooks
5. **Edit/Write gap compensation** — Write AGENTS.md instruction rules for the 7 hooks blocked by Codex's Bash-only matcher, plus Stop-hook post-hoc verifier
6. **AGENTS.md generator** — Extract CLAUDE.md content into AGENTS.md format (dual instruction pathway)
7. **Codex installer** — Create `codex/install-codex.sh` that deploys the converted distribution
8. **Behavioral adapter layer** — Tune enforcement language (MUST/STOP → GPT-4.1 patterns), strip Claude-specific references
9. **Test extension** — Add `test.sh --codex` path validating file counts, format correctness, schema validity, idempotency
10. **Divergence tracking infrastructure** — Create `.claude/divergence/` with structured finding format (compliance/interpretation/capability/format)
11. **Master conversion script** — Wire steps 1-8 into `scripts/convert-to-codex.sh` with `--target codex` flag and extensible architecture

## Risk Flags

- **User-facing behavior change** — entire Codex distribution is user-facing
- **Security-sensitive operations** — hook portability degrades defense-in-depth from 3 layers to 2 in Codex mode

## Triage Result

- **Steps:** 11 discrete actions
- **Risk flags:** 2 (user-facing, security)
- **Execution preference:** Speed (parallelize aggressively)
- **Recommended path:** Full
- **Research brief:** consumed (gate score 4.3/5.0, brainstorm ✓, prior-art ✓, requirements ✓)
