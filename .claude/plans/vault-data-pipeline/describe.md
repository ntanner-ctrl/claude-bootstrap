# Describe: vault-data-pipeline

## Change Summary
Unify data flow from project artifacts (blueprints, Empirica findings, preflight assessments) into the Obsidian vault, with backward compatibility for non-vault users.

## Context
- Brainstorm completed: three workstreams identified (backfill, pipeline, preflight capture)
- 19 existing blueprints across 3 project locations need migration
- 24 Empirica disk findings across 3 projects need rescue
- Preflight assessment vectors are submitted to Empirica but never captured to disk/vault
- Vault integration already has feature flag (`VAULT_ENABLED`) and helpers (`vault_is_available()`)

## Steps

1. Write one-time backfill script: migrate 19 existing blueprints to vault notes
2. Write one-time backfill script: migrate 24 Empirica disk findings to vault notes
3. Deduplicate against existing vault notes during backfill
4. Add `blueprint` type routing to `/vault-save` command
5. Add auto-export at blueprint completion (Stage 7) guarded by `vault_is_available()`
6. Create PostToolUse hook to capture `submit_preflight_assessment` vectors to disk
7. Modify `/end` command to pair preflight+postflight vectors and export delta to vault
8. Guard all new pipeline steps with `vault_is_available()` for backward compat

## Risk Flags
- User-facing behavior change (automatic vault note creation)

## Triage
- **Path:** Full (8 steps, 1 risk flag)
- **Execution preference:** Auto
- **Fed by:** /brainstorm (holistic analysis of three workstreams)

## Decisions from Brainstorm
- Backfill is local-only, NOT a distributable feature
- Pipeline uses Approach C (auto at completion + manual via /vault-save)
- Preflight capture uses Approach A (PostToolUse hook, mirrors insight-capture pattern)
- Raw vectors stored (not delta-only) — storage negligible (~1.5KB/session)
- Dedup: skip silently if timestamp+content match existing vault note
