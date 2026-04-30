# Prior Art Report: anti-pattern-catalog

**Run:** 2026-04-30 (during review stage of blueprint)
**Trigger:** Review Stage 4 (External) — substituted /prior-art for /gpt-review at user request
**Problem:** Catalog of language-specific anti-patterns with regex-based detection, project-local entries, session-end sweep, counter tracking (recent_hits, total_hits, locations_remedied), and vault export for cross-project aggregation.
**Stack constraint:** claude-sail toolkit — pure bash + jq + grep + curl only (per `.claude/CLAUDE.md`: "this toolkit must work with just bash and curl"). No language runtimes.

## Search Scope

| Query | Source |
|---|---|
| `semgrep custom rules bash project-local rule catalog 2026` | semgrep.dev, github.com/semgrep/semgrep-rules |
| `ast-grep bash custom patterns sgconfig.yml project rules` | ast-grep.github.io |
| `shellcheck custom rules bash anti-pattern detection per-project` | shellcheck.net, github.com/koalaman/shellcheck |
| `comby pattern matching catalog rule library bash` | comby.dev, github.com/comby-tools/sample-catalog |

## Candidate Evaluation

### [1] Semgrep — `https://semgrep.dev`

| Dimension | Assessment |
|---|---|
| **Fit** | Medium — solves the *detection* half of the problem better than regex (AST-aware for ~30 languages, multi-line patterns, taint analysis), with project-local custom rules in `.semgrep.yml` and a massive community rule library at `github.com/semgrep/semgrep-rules`. **Does not** solve the *bookkeeping* half: no concept of `recent_hits`, `locations_remedied`, vault export, or temporal decay tracking. |
| **Maturity** | High — established, actively maintained, OSS Community Edition + commercial tier. Standard tool in security audit workflows. |
| **Integration** | Low — Python runtime dependency. Violates claude-sail's "bash + curl only" constraint. Could be wrapped (the catalog calls `semgrep` if installed), but that adds optional-dependency branching to a toolkit that prides itself on dependency-zero. |
| **Risk** | Medium — license (LGPL Community Edition is permissive enough), but adoption changes the toolkit's distribution model. |

**Notes:** Semgrep would replace the *detection* engine. It would NOT replace the catalog *bookkeeping* — counter tracking, vault export, PreToolUse integration would all still be custom. So adoption is partial at best.

---

### [2] ast-grep — `https://ast-grep.github.io`

| Dimension | Assessment |
|---|---|
| **Fit** | Medium — Tree-sitter-based AST matching with project-local rules in `sgconfig.yml` and YAML rule format. Bash supported. Same value proposition as semgrep but newer, leaner, Rust binary. Same gap on bookkeeping. |
| **Maturity** | Medium — newer tool, less ecosystem than semgrep but actively developed. Adoption is growing. |
| **Integration** | Low — same constraint violation. Single Rust binary is lighter than Python+pip but still a non-bash dependency. |
| **Risk** | Medium — smaller ecosystem means fewer pre-built rules to leverage. |

**Notes:** Same partial-adoption story as semgrep. Better as a detection engine than regex; doesn't address the temporal-observability layer that's the blueprint's actual differentiator.

---

### [3] ShellCheck — `https://shellcheck.net`

| Dimension | Assessment |
|---|---|
| **Fit** | Low — bash-specific lint catalog with `.shellcheckrc` per-project config. **But:** custom rules are explicitly NOT supported (issue #1061 has been open for years; maintainer position is "doesn't make sense to include user-defined rules in core"). Only enable/disable of built-in checks. |
| **Maturity** | High — universal default in bash projects, well-tested, wide ecosystem integration. |
| **Integration** | Medium — already standard tooling; claude-sail likely should run shellcheck on its own hooks regardless. |
| **Risk** | Low. |

**Notes:** Disqualifying — extensibility is the catalog's core property. ShellCheck is **complementary** (run it as additional bash linting) rather than substitutable.

---

### [4] Comby — `https://comby.dev`

| Dimension | Assessment |
|---|---|
| **Fit** | Low — structural search-and-rewrite tool. Has a `sample-catalog` format with match/rewrite files per pattern. But Comby is centered on rewrites, not detection-and-bookkeeping. |
| **Maturity** | Medium — established but smaller community than semgrep/ast-grep. |
| **Integration** | Low — OCaml binary dependency. |
| **Risk** | Medium — niche tool, less momentum. |

**Notes:** Wrong primitive — we want detection signal over time, not rewrites. Skip.

---

## Recommendation: **Inform** (Adapt-considered-rejected)

### Rationale

The blueprint's *detection* primitive (regex-on-files) is genuinely weaker than what semgrep/ast-grep provide — these tools could catch the multi-line patterns (F3's `bash-silent-error-suppression`, DA-4's `bash-missing-fail-fast`) that the regex approach can't. **However**, claude-sail's "bash + curl only" constraint forecloses adoption.

More importantly: **none of these tools solve the half of the problem the catalog is actually built for.** Semgrep tells you "this code matches a pattern right now." The catalog tells you "this pattern fired 47 times across 3 projects in the last 60 days, 12 locations were remediated, and the count is decaying." That temporal/cross-project observability is the actual product.

### Patterns worth borrowing into the spec

| From | Pattern | Apply to |
|---|---|---|
| Semgrep | `metadata: { references, cwe, technology, category }` field convention in rule frontmatter | Add optional `references` array to schema (links to incidents/CVEs/PRs); leave room for `cwe` field. Forward-compat with future semgrep-importer if we ever loosen the dep constraint. |
| Semgrep | Rule "packs" — bundle related patterns (e.g., `bash-essentials`) | Document that the 3 starter patterns are claude-sail's `bash-essentials` pack; future packs can be sub-directories. |
| ast-grep | `sgconfig.yml` root config pointing to rule directories | Already in scope as deferred F8/S-4 (`.claude/anti-patterns/.config.json`); confirms the design direction. |
| Semgrep / ast-grep | YAML format with `id`, `severity`, `message`, `languages` fields | Our schema already aligns on `id`, `severity`, `language`. Consider renaming `severity` enum to match semgrep's (`ERROR`/`WARNING`/`INFO`) for cross-tool portability — minor. |

### Findings to fold into review summary

**PA-1 (HIGH) — Value proposition is mis-framed in describe.md.**

Currently the catalog reads as "detect anti-patterns in bash." Semgrep does that better. The actual differentiator is **"temporal observability of anti-pattern decay across projects, integrated with claude-sail's session lifecycle."** Without this reframing, every reviewer (human or AI) will ask "why not semgrep?" and the answer will sound like a constraint excuse rather than a design choice. **Fix:** describe.md gets a paragraph that explicitly contrasts with detection-only tools and names the bookkeeping/temporal layer as the product.

**PA-2 (MEDIUM) — Spec doesn't acknowledge the "bash + curl only" constraint as the reason for choosing regex over AST.**

The spec frames regex as a simplicity choice. It's actually a constraint choice. Honest framing: "We would prefer semgrep/ast-grep for detection, but the toolkit's dependency-zero discipline precludes them. Regex is the strongest detection primitive we can ship within that constraint, with documented coarseness for multi-line patterns (F3 deferred to v2, DA-4 accepted). If a future user installs semgrep, a v2 schema extension `detection_kind: regex|semgrep|ast-grep` could route to the better engine while preserving the bookkeeping layer." This belongs in spec.md's "Decisions" section (which doesn't exist yet — should it?).

**PA-3 (LOW) — Schema field names should pre-align with semgrep where cheap.**

Adding optional `references: []` array to frontmatter (links to incident notes, PRs, CVE IDs) costs nothing now and makes future migration / cross-tool export easier. The vault export already implies linkability — `references` formalizes it.

## Build-vs-Adopt Decision

**Continuing the blueprint** is the right call, with the framing fixes above. The bookkeeping layer is genuine differentiation; adopting any of these tools would lose 80% of the value while solving 20% of the problem (detection sophistication) at the cost of breaking a core toolkit constraint.

If the constraint ever softens: revisit, but as a v2+ schema extension that *adds* AST detection alongside regex, not replaces it.
