# Describe: Anti-Pattern Catalog

## Problem

Across recent sessions, the same kinds of dangerous code idioms have bitten us — most recently `jq … > tmp && mv` (silent file wipe), and historically things like `set +e` without paired exit checks, missing input validation at boundaries, etc. None of the existing review surfaces in claude-sail are calibrated to scan for *known dangerous idioms by language*:

- `quality-reviewer` is a generalist (code quality, not idiom-specific)
- `silent-failure-hunter` (pr-review-toolkit) is analytic — no curated catalog
- The 6 paradigm lenses (DRY/YAGNI/KISS/etc.) are abstract principles, not idiom checklists
- Hookify rules exist but each is a one-off — no shared catalog or hit-tracking

The gap: a **catalog** of dangerous idioms — small, curated, structured — that multiple consumers (hookify, reviewers, future prism lens) can pull from. Without the catalog as a first-class artifact, every new consumer reinvents its own checklist.

## Positioning vs. External Detection Tools

**This is not a detection tool.** Tools like `semgrep`, `ast-grep`, and `shellcheck` already do regex/AST-based detection better than we ever will, with massive community rule libraries. If detection sophistication were the product, the answer would be "install semgrep, write a `.semgrep.yml`, done."

The catalog's actual product is **temporal observability of anti-pattern decay across projects** — bookkeeping that detection tools intentionally don't provide:

- **`recent_hits` over a rolling window** — "are we still making this mistake *lately*?"
- **`locations_remedied`** — "did this fix actually take, or is it creeping back?"
- **`first_seen` / `last_seen`** — when did this pattern enter our project's awareness, and is it active or fossilizing?
- **Cross-project aggregation via vault export** — "this pattern fired in 4 of 7 projects last quarter; it's a portfolio-level concern, not a one-off."

Detection happens once. Bookkeeping accumulates. The catalog is the **bookkeeping layer**; detection is a means, not the end. (See `prior-art.md` for the full external-tool comparison that drove this framing.)

> **Constraint that shaped this choice:** claude-sail ships as bash + curl only. Adopting a detection engine like semgrep (Python) or ast-grep (Rust binary) would violate that constraint. Within the constraint, regex is the strongest detection primitive available — accepting some coarseness on multi-line patterns. A future `detection_kind: regex|semgrep|ast-grep` schema extension could route to better engines while preserving the bookkeeping layer; out of scope for v1.

## Desired Outcome

A living, structured catalog of language-specific anti-patterns, with:

1. **One entry per pattern**, stored as markdown with YAML frontmatter (Obsidian-indexable, jq/yq-queryable on filesystem).
2. **Frontmatter schema** that captures recurrence signal — total hits, recent hits within a window, locations remediated — so "are we making this mistake *lately*" is the load-bearing query.
3. **Counters derived from a session-end sweep**, not maintained incrementally. The sweep is the source of truth; counters can't drift because they're computed, not edited.
4. **Sweep wired into `/end`**, scoped to files touched in the current session. Cheap, automatic, runs every session.
5. **Manual full-sweep escape hatch** (e.g., `/anti-patterns sweep --full` or equivalent) for initial catalog seeding and periodic reconciliation, since session sweeps miss never-touched files.
6. **At least one consumer wired** at delivery — hookify rules referencing catalog entries by ID, so the catalog has an actual job from day one.

## Scope

### In scope
- `.claude/anti-patterns/` directory structure (or vault location — TBD in spec)
- 3 starter entries seeded from the 2026-04-30 incident and `.epistemic/insights.jsonl`:
  - `bash-unsafe-atomic-write` (this session's incident)
  - `bash-silent-error-suppression` (`set +e` without paired exit checks)
  - One more drawn from insights — TBD which is most reused
- Frontmatter schema (small, deliberately under-engineered)
- `/end` skill integration: session sweep + counter recomputation
- Manual full-sweep command (skeleton — exact name TBD in spec)
- One consumer wire-up: hookify rule that references catalog entry IDs
- Documentation: how to add a new pattern, when sweeps run, how to query

### Out of scope
- A new prism lens that consumes the catalog (deferred — separate consumer, can be added later)
- Auto-generation of patterns from the codebase (rejected — emergent + post-incident is the right curation mode)
- Cross-language patterns beyond bash for v1 (Python/JS/etc. catalogs are future work — start where the pain has been)
- Integration with `quality-reviewer` (deferred until catalog has proven value through hookify)
- Changes to `/prism` (the test-debt-in-prism work is a separate `/blueprint`, intentionally decoupled)

### Will not change
- `quality-reviewer.md` (untouched in v1 — catalog is consumed by hookify only initially)
- The 6 paradigm lens agents (untouched — catalog is a *new* surface, not a refactor)
- `pr-review-toolkit:silent-failure-hunter` (it stays analytic; catalog is complementary)

## Success Criteria

1. **Catalog exists**: `.claude/anti-patterns/bash-*.md` (or chosen location) with frontmatter validated by `jq`/`yq`. At least 3 entries.
2. **Sweep works**: running `/end` on a session that wrote `> "$TMP" && mv "$TMP" "$FILE"` (without validation) increments `recent_hits` for `bash-unsafe-atomic-write`. Verifiable by running `/end` on a fixture.
3. **Counter regeneration is idempotent**: running the sweep twice produces the same counters. This is the "can't drift" property.
4. **At least one hookify rule references a catalog entry by ID**: the rule cites `id: bash-unsafe-atomic-write` (or chosen ID format) so the catalog has an active reader.
5. **Manual full-sweep produces sensible counters**: running it on the claude-sail repo finds the existing instances of seeded patterns and the counters match a hand-grep verification.
6. **Documented add-pattern flow**: a one-page how-to describing where to add a pattern, what frontmatter is required, and what the sweep does with it.

## Constraints

- **No new dependencies** — bash + jq + grep, consistent with the rest of the toolkit
- **Fail-open in `/end` integration** — catalog sweep failures must not block session-end (matches hook discipline)
- **Counters derived, never maintained** — frontmatter writes happen *only* during sweep, never from agent-side detections
- **Small catalog v1** — three entries, deliberately. Catalog stewardship is the long-term concern; starting tiny lets the system prove itself before it bloats
- **Vault-optional** — catalog lives in repo (`.claude/anti-patterns/`) by default; vault export is a separate concern (matches blueprint/finding pattern)

## Triage

| Field | Value |
|-------|-------|
| Path | **Standard** — this is a small focused feature with clear scope, but it touches multiple files (catalog schema, sweep logic, /end integration, one hookify rule, docs) and the schema design is the load-bearing decision. Light is too thin; Full is overkill since the design has been extensively converged in conversation. |
| Execution preference | `auto` — moderate parallelism possible (catalog seeding can run alongside sweep implementation) |
| Risk flags | None of: auth / security-sensitive / data migration / external API contracts / schema changes (the only "schema" is the new catalog frontmatter, which is greenfield) |
| Estimated WUs | 4-6 (schema spec, catalog seed entries, sweep script, /end integration, hookify rule, docs) |

## Unvalidated Assumptions

- **`/end` is the right hook point**, not a separate command. Reasoning: bookkeeping naturally pairs with cleanup ceremonies. Risk: `/end` becomes a god-command. Mitigation: the sweep is implemented as a callable script that `/end` invokes; can be re-pointed elsewhere later.
- **YAML frontmatter is queryable enough** without a structured database. Reasoning: matches existing vault/Obsidian patterns; jq/yq handles filesystem queries fine for catalog sizes <100. Risk: at >100 entries, querying gets slow. Mitigation: write the catalog reader as a function that can be backed by SQLite later if needed.
- **Three entries is the right v1 size**. Risk: too few to prove the consumer integration works generically. Mitigation: use entries from genuinely different shapes — at least one with `recent_hits > 0` (this session's incident) and one with hopefully `recent_hits = 0` (older, less active) so the recency signal can be validated.
- **Hookify is the right first consumer**. Reasoning: most visible feedback loop, runtime enforcement. Risk: hookify rule format may not naturally accept catalog ID references — may require small format extension. Mitigation: confirm format compatibility in Stage 2 (Specify) before committing.

## Known Risks

- **Risk: Catalog stewardship rots** — patterns get added but never reviewed/retired. (operational)
  - Mitigation: schema includes `status: active|retired`; sweep flags entries with no hits in 90 days for review (advisory, not auto-retire).
- **Risk: Sweep logic produces false positives** — grep-style detection over-matches. (technical)
  - Mitigation: each pattern has a `detection_regex` field; sweep tests each pattern against a known-good fixture file and a known-bad fixture file before counting.
- **Risk: `/end` performance regression** — sweep adds latency to session close. (operational)
  - Mitigation: scope to `git diff --name-only` files only (typically <50 per session); time-budget the sweep at 5s with hard cutoff.
- **Risk: Bookkeeping race when multiple sessions end concurrently** — two `/end` invocations write to the same frontmatter. (technical, low likelihood)
  - Mitigation: counters are derived from append-only event log, not edited in place. Frontmatter is regenerated atomically using the same `epistemic_safe_swap` validate-before-swap pattern from this session's bug fix. (Nice symmetry.)
