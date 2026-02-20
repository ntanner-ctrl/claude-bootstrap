# Adversarial Findings: vault-data-pipeline

## Debate Chain Results (Stage 3, Round 1)

Challenge mode: debate | Rounds: Challenger → Defender → Judge

### Critical

**F2: WU3 overwrite destroys user annotations in Obsidian** [both-agreed]
- WU3 overwrites entire file on blueprint completion. User annotations, tags, and backlinks added in Obsidian are destroyed.
- **Mitigation required:** Merge-write pattern — read existing content, preserve lines below a sentinel marker (e.g., `<!-- user-content -->`), only overwrite generated frontmatter+body above it.
- **Status:** needs-new-section in spec

### High

**F1: Dedup "80% similarity" unimplementable in bash** [both-agreed]
- Replace with deterministic exact-slug match. Slug exists → skip.
- **Status:** needs-spec-update

**F3: vault_is_available() silent failure** [both-agreed]
- Skipped writes produce no operator signal. Log to vault-skip.log with timestamp.
- **Status:** needs-spec-update

**F4: Hooks exit 0 on write failure** [both-agreed]
- Write failures produce no signal. Add failure log.
- **Status:** needs-spec-update

**FA: No vault note template versioning** [newly-identified]
- Frontmatter lacks schema_version. Future schema changes break Dataview queries and migration.
- **Status:** needs-spec-update

**FB: VAULT_PATH WSL path translation implicit** [newly-identified]
- User might set Windows-style path. Need WSL-native path requirement or auto-translation guard.
- **Status:** needs-new-section

### Medium

**F5: Delta threshold policy undefined** [disputed]
- Define minimum delta to trigger vault note vs suppress.
- **Status:** needs-spec-update

**F8: vault_sanitize_slug() path-length guard missing** [both-agreed]
- Need total path length check after constructing full note path.
- **Status:** needs-spec-update

**F9: /vault-save blueprint detection priority undefined** [both-agreed]
- Define: (1) in_progress state.json, (2) most recent, (3) prompt user.
- **Status:** needs-spec-update

**F11: PostToolUse hook matcher table missing** [both-agreed]
- Need explicit MCP tool name → hook → output file mapping.
- **Status:** needs-new-section

**FC: session_id not written to vault note frontmatter** [newly-identified]
- Need traceability from vault note back to Empirica session.
- **Status:** needs-spec-update

**FD: Obsidian file lock race condition** [newly-identified]
- Recommend retry-with-backoff (3 attempts, 500ms) before logging failure.
- **Status:** needs-spec-update

### Low

**F6: Hardcoded paths** — intentional for local script [already-in-spec]
**F7: NTFS write atomicity** — narrow risk, small files [needs-spec-update: acknowledge]
**F10: Backfill vs WU3 sequencing** — resolved by execution order [needs-spec-update: add note]
**F12: Hook count verification** — verify post-implementation [needs-spec-update]
**F13: No dry-run** — acceptable for one-shot local script [already-in-spec]
**F14: /end JSONL path ambiguity** — display resolved path [needs-spec-update]
**F15: Silent delta skip** — acceptable per fail-open [already-in-spec]
**FE: No MOC maintenance** — defer to follow-on [already-in-spec]
**FF: Leading/trailing hyphens in slug** — strip edges [needs-spec-update]

---

## Edge Case Results (Stage 4)

Challenge mode: debate | Boundary Explorer round

### High Priority (addressed in spec rev 1)

**S-2: Vault subdirectories missing on first run** [newly-identified]
- `vault_is_available()` checks root only. `mkdir -p` needed before every write.
- **Status:** Added to cross-cutting concerns

**T-4: jq not installed — silent total failure** [newly-identified]
- All JSONL hooks depend on jq. Missing binary = no data captured, no error.
- **Status:** Added to cross-cutting concerns (backfill: hard check, hooks: session-start warning)

**CT-3: Finding text with YAML-breaking chars in frontmatter** [newly-identified]
- Multi-line descriptions in frontmatter break Obsidian parsing.
- **Status:** Added to cross-cutting concerns (long text → body, not frontmatter)

### Medium Priority (addressed in spec rev 1)

**CT-1: Cross-project slug collision** [newly-identified]
- Two projects with same blueprint name (e.g., "api-refactor") collide on slug.
- **Status:** Added to cross-cutting concerns (include project name in slug)

**CT-2: Unfilled template placeholders left as raw mustache** [newly-identified]
- Claude leaves `{{session_id}}` literally in output if no value available.
- **Status:** Added to cross-cutting concerns (replace with empty/null)

**I-1: Empty JSONL file passes existence check but fails parse** [newly-identified]
- Guard checks "file missing" but empty file passes check.
- **Status:** Implementation note — check file size > 0 before parsing

**I-4: NaN/null vector values break delta arithmetic** [newly-identified]
- Non-numeric vectors produce jq errors.
- **Status:** Implementation note — display "n/a" for non-numeric vectors

**CT-6: `input.impact` may be string not float** [newly-identified]
- Type contract for empirica_confidence unspecified.
- **Status:** Implementation note — coerce to number or use 0.5 default

### Low Priority (noted, no spec change)

**I-3, I-5, I-6, I-7, I-8, S-1, S-3, S-5, S-6, C-1, C-3, C-4, T-1, T-2, T-3, CT-4, CT-5** — Various low-severity boundaries. Most handled by existing patterns or acceptable as known limitations.

### User-Identified Edge Cases

**JSONL duplication across vault + Empirica + disk** [user-raised]
- Same finding in 3 places. Solved by mark-as-exported lifecycle.
- **Status:** Added to cross-cutting concerns + WU6 step 7

**`/blueprints` command impact** [user-raised]
- `/blueprints` reads `.claude/plans/` — vault summary notes are a different format, not a replacement.
- Vault = long-term record, `.claude/plans/` = working artifacts. No duplication concern.
- **Status:** No change needed. `/blueprints` continues to read local state.json.

**Knowledge triage workflow** [user-raised]
- Expand `/review-findings` into interactive vault curation workflow.
- **Status:** Captured as follow-on idea in vault: Ideas/2026-02-20-review-findings-interactive-knowledge-triage.md
