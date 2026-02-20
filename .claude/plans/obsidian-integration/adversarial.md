# Adversarial Findings: obsidian-integration

## Stage 3 — Challenge (Debate Mode)

### Verdict: REGRESS → Stage 2 (Specify)

**Debate chain:** Challenger (25 findings) → Defender (7 new, classified all) → Judge (final synthesis)

### High Severity (require spec fixes)

| ID | Finding | Convergence | Resolution |
|----|---------|-------------|------------|
| F1/NEW-3 | Marker PID mismatch: `vault-config.sh` defines marker with `$$` (PID-scoped), `session-end-vault.sh` checks without PID. Different processes = different paths. Double-export always fires. | both-agreed | Fix: Use per-UID per-date key without PID: `/tmp/.vault-exported-$(id -u)-$(date +%Y%m%d)` |
| F7 | "This session" artifacts undefined — no mechanism to distinguish current session decisions/findings from pre-existing ones during `/end` export. | both-agreed | Fix: Write session-start timestamp to tempfile in `session-bootstrap.sh`, use as cutoff |
| F10 | `install.sh` overwrites user-customized `vault-config.sh` on reinstall, destroying vault path. | both-agreed | Fix: Ship `vault-config.sh.example`, only install if real file doesn't exist |
| F12/NEW-1 | NTFS-illegal colons in HH:MM timestamps cause silent write failures on Windows vault via WSL. Session-end hook and any title-derived slug affected. | both-agreed | Fix: Use HHMM format (no colons), strip NTFS-illegal chars from all slugs |
| F14 | `vault_is_available()` called throughout spec but never defined. Implementers must guess the contract. | both-agreed | Fix: Add concrete implementation to W2 spec |

### Medium Severity (address in spec or implementation)

| ID | Finding | Convergence |
|----|---------|-------------|
| F3 | GNU `date -d` not portable to macOS. Fix: use `find -mtime -7` | both-agreed |
| F4 | Unsanitized project name in heredoc. Fix: `tr -cd` sanitization | both-agreed |
| F6 | `find -printf` not portable. Fix: use `find -mtime -7` without sort | both-agreed |
| F9 | Parallel session marker collision. Fix: scope marker by session ID | both-agreed |
| F11 | Blueprint update semantics undefined. Fix: define as overwrite (snapshot) | both-agreed |
| F13 | find command lacks timeout/maxdepth despite spec mentioning it. Fix: add to code | both-agreed |
| F15 | Wiki-link generation non-deterministic. Fix: scope to deterministic cross-links | both-agreed |
| F18 | Install prompt for vault path unspecified. Fix: use .example pattern | both-agreed |
| F19 | Session summary content source undefined | both-agreed |
| NEW-2 | git rev-parse fallback to pwd produces useless project names | newly-identified |
| NEW-5 | Personal vault path would be committed to public repo | newly-identified |

### Low Severity (note for implementation)

| ID | Finding | Convergence |
|----|---------|-------------|
| F2 | Path quoting discipline needed | disputed (implementation, not design) |
| F5 | Filename injection not meaningful for single-user vault | disputed (false) |
| F8 | Partial writes acceptable for personal notes | disputed (overstated) |
| F16 | Search ranking adequate for personal tool | disputed (false) |
| F17 | MCP vs direct access boundary unclear | both-agreed |
| F20 | Unresolved wiki-links are standard Obsidian behavior | disputed (false) |
| F21 | Pattern extraction heuristic undefined. Defer to future. | both-agreed |
| F22 | Marker cleanup not needed — aligns with session lifecycle | disputed (overstated) |
| F23 | Templates are Claude-only, not shell-substitutable | both-agreed |
| F24 | CLAUDE.md appears in search results. Fix: add -not -name filter | both-agreed |
| F25 | Wiki-link success criterion not mechanically verifiable | both-agreed |
| NEW-4 | Safety-net notes indistinguishable from /end notes. Fix: generated_by tag | newly-identified |
| NEW-6 | Safety-net only creates Sessions/ dir, not full structure | newly-identified |
| NEW-7 | /end spec mixes shell pseudocode with Claude-executed instructions | newly-identified |

---

## Stage 3 — Revalidation (Debate Mode, Post-Regression)

### Verdict: PASS_WITH_NOTES

**Debate chain:** Challenger (13 findings) → Defender (6 new, classified all) → Judge (final synthesis)

### High Severity (clarification gaps, fixed inline)

| ID | Finding | Convergence | Resolution |
|----|---------|-------------|------------|
| R2 | `insights.jsonl` timestamp field name/format/comparison unspecified | both-agreed | Fixed: Spec now defines field=`timestamp`, format=ISO-8601, comparison=lexicographic |
| R3 | Decision record location/schema in `.claude/plans/` undefined | both-agreed | Fixed: Spec now defines `.claude/decisions/` path, filename pattern, `date:` frontmatter field |
| R7 | VAULT_EXPORT_MARKER contains shell subshells that Claude can't evaluate by reading file | both-agreed | Fixed: Step 1 now uses Bash tool to source vault-config.sh and echo resolved values |

### Medium Severity (fixed inline)

| ID | Finding | Convergence | Resolution |
|----|---------|-------------|------------|
| R5 | `\n` escapes in `$VAULT_CONTEXT` are literal inside heredocs | both-agreed | Fixed: Replaced with `printf` for real newlines |
| R9 | `/vault-save` wiki-link instruction contradicts batch-scoping rule | both-agreed | Fixed: Clarified batch rule applies to `/end` only; `/vault-save` links to existing notes |
| R10 | "Timestamps prevent duplicates" in Failure Modes misleading | both-agreed | Fixed: Reworded to explain marker-based dedup |
| R12 | `mkdir -p` for vault subdirs not in `/end` export | both-agreed | Fixed: Added mkdir -p step to W3 |
| NEW-R1 | No fallback if `.empirica/active_session` missing | newly-identified | Fixed: Added fallback to `session-YYYY-MM-DD-HHMM` |
| NEW-R2 | `vault_sanitize_slug()` not explicitly required for all filename construction | newly-identified | Fixed: Added explicit requirement to W3 step 5 |
| NEW-R5 | Session summary doesn't include `/vault-save` captures | newly-identified | Fixed: Added Ideas/ check to artifact collection |

### Low Severity (accepted, no fix needed)

| ID | Finding | Convergence |
|----|---------|-------------|
| R1 | Session-start timestamp UID-only key (parallel session edge case) | disputed — theoretical for single-user |
| R4 | Parallel-session marker collision | disputed — spec reasoning is correct |
| R6 | `vault_sanitize_slug()` UTF-8 truncation | disputed — theoretical for ASCII project names |
| R8 | Blueprint wiki-link unconditional in template | disputed — template placeholders handle this |
| R11 | Session-scoping success criterion could be stronger | disputed — spot-check appropriate for personal tool |
| R13 | spec.diff.md work unit numbering inconsistency | disputed — no implementation impact |
| NEW-R3 | VAULT_ENABLED check ordering (already correct via vault_is_available) | newly-identified |
| NEW-R4 | Session-start timestamp file lifecycle undocumented | newly-identified |
| NEW-R6 | install.sh conditional copy logic prose-only | newly-identified |

---

## Stage 4 — Edge Cases (Debate Mode)

### Verdict: PASS_WITH_NOTES

**Debate chain:** Boundary Explorer (32 edge cases) → Stress Tester (reassessed all) → Synthesizer (14 final findings)

### Fix Before Build (applied to spec)

| ID | Finding | Fix Applied |
|----|---------|-------------|
| E1 | `vault_note_path()` listed in W2 but unimplemented | Removed from feature list; inline quoted path construction is the convention |
| E2 | Session-start timestamp missing after reboot → all-history dump | Added 24-hour fallback cutoff with logged warning |

### Fix During Build (noted in spec)

| ID | Finding | Fix Applied |
|----|---------|-------------|
| E3 | `date -Iseconds` is WSL-specific (GNU) | Noted as WSL assumption |
| E4 | VAULT_EXPORT_MARKER date drift across midnight | Accepted: extra breadcrumb note is harmless |
| E5 | `/vault-query` on non-existent vault dirs → cryptic error | Add vault_is_available() check to /vault-query |
| E6 | Session summary "Work Completed" has no concrete data source | Scoped to artifact evidence (decisions, findings, blueprints, vault-saves) — no git diff |
| E8 | Empty slug produces `YYYY-MM-DD-.md` | Added `${result:-unnamed}` fallback |
| E9 | `/vault-save` missing mkdir -p | Added as step 2 |

### Accepted (no fix needed)

| ID | Finding | Reason |
|----|---------|--------|
| E7 | Crash mid-export leaves partial notes | Marker-last ordering; no data corruption |
| E10 | OneDrive sync interference | Documentation-only; user config fix |
| E11 | Mid-restart timestamp overwrite | Acceptable for personal tool |
| E12 | Same-slug collision within batch | Matches overwrite-as-snapshot philosophy |
| E13 | Parallel `/end` marker sharing | Sequential personal use assumed |
| E14 | Obsidian external-change detection | Works correctly; no silent data loss |
