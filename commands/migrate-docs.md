# Diataxis Documentation Migration

Complete documentation lifecycle management: generate scaffolds for new projects, migrate existing docs to Diataxis framework, validate compliance, and rollback changes.

## Usage

```
/migrate-docs [path] [options]
```

**Examples:**
- `/migrate-docs` — Migrate `docs/` directory (interactive)
- `/migrate-docs docs/ --dry-run` — Preview without writing
- `/migrate-docs --scaffold` — Generate scaffolds for undocumented project
- `/migrate-docs --validate` — Validate existing migration
- `/migrate-docs --rollback` — Restore from archive

---

## Arguments & Options

| Argument/Option | Default | Description |
|-----------------|---------|-------------|
| `path` | `docs/` | Directory to migrate or scaffold |
| `--dry-run` | false | Preview changes without writing |
| `--scaffold` | auto | Force scaffold generation (auto-triggers if no docs) |
| `--confidence N` | 70 | Threshold for auto-classification (0-100) |
| `--no-split` | false | Don't split hybrid documents |
| `--structure TYPE` | categorized | `flat` or `categorized` output |
| `--import` | false | Treat as external docs (add provenance) |
| `--validate` | false | Validate previous migration |
| `--rollback` | false | Restore from archive |
| `--verbose` | false | Show classification signals |

---

## Workflow

Execute these phases in order:

### Phase 1: Discovery & Inventory

1. **Scan the target directory** for `*.md` files
   - Exclude: `CHANGELOG.md`, `LICENSE.md`, `README.md` (in root only), auto-generated files
   - Include all subdirectories

2. **Quick content preview** (first 50 lines of each):
   - Check for existing Diataxis headers (`> **Type:**`)
   - Count H2 sections (`## `)
   - Estimate document size (word count)

3. **Generate inventory summary**:
   ```
   ╔═══════════════════════════════════════════════════════╗
   ║              DOCUMENTATION INVENTORY                   ║
   ╠═══════════════════════════════════════════════════════╣
   ║  Total Files:           47                             ║
   ║  Already Diataxis:       3                             ║
   ║  Need Classification:   44                             ║
   ║  Suspected Hybrids:     12                             ║
   ╚═══════════════════════════════════════════════════════╝
   ```

4. **Decision point**:
   - If `Total Files == 0` OR `--scaffold` flag → **Go to Phase 1.5: Scaffold Generation**
   - Otherwise → Continue to Phase 2: Classification

---

### Phase 1.5: Scaffold Generation (No Docs / --scaffold)

When no documentation exists (or `--scaffold` is explicitly requested), generate structurally-sound scaffolds based on project analysis.

#### 1.5.1 Project Analysis

Scan the project root to detect project type and features:

| Detection | Signals | Scaffolds to Generate |
|-----------|---------|----------------------|
| **Package manager** | `package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod` | Reference: Dependencies |
| **Has CLI** | `bin/`, CLI entry points, `commander`/`clap`/`argparse` imports | Reference: CLI, How-to: Common commands |
| **Has API** | `routes/`, `api/`, OpenAPI spec, REST endpoints | Reference: API, How-to: Authentication |
| **Has tests** | `tests/`, `__tests__/`, `*_test.go`, `*.spec.ts` | How-to: Running tests |
| **Has Docker** | `Dockerfile`, `docker-compose.yml` | How-to: Docker deployment |
| **Has CI/CD** | `.github/workflows/`, `.gitlab-ci.yml` | How-to: CI/CD pipeline |
| **Frontend** | `src/components/`, React/Vue/Svelte imports | Reference: Components |
| **Database** | `migrations/`, `prisma/`, `schema.sql` | How-to: Database migrations |
| **Config files** | `config/`, `.env.example`, YAML configs | Reference: Configuration |

#### 1.5.2 Generate Scaffold Set

Based on analysis, generate the **minimum viable documentation set**:

**Always generated (Core Set):**

| Document | Type | Purpose |
|----------|------|---------|
| `docs/README.md` | Index | Documentation hub with links |
| `docs/tutorials/getting-started.md` | Tutorial | First-run experience |
| `docs/explanation/architecture.md` | Explanation | System overview |

**Conditionally generated (Feature Set):**

| Condition | Document | Type |
|-----------|----------|------|
| Has CLI | `docs/reference/cli.md` | Reference |
| Has API | `docs/reference/api.md` | Reference |
| Has config | `docs/reference/configuration.md` | Reference |
| Has Docker | `docs/how-to/docker-deployment.md` | How-to |
| Has tests | `docs/how-to/running-tests.md` | How-to |
| Has migrations | `docs/how-to/database-migrations.md` | How-to |

#### 1.5.3 Scaffold Content Strategy

Each scaffold is **structurally complete but content-sparse**:

```markdown
# [Title]

> **Type:** [Type]
> **Last Updated:** YYYY-MM-DD
> **Status:** Scaffold - Needs content
> **Related:** [Links when known]

[One-sentence description of what this document covers.]

---

## [Section from template]

<!-- TODO: Add content for this section -->
<!-- Detected: [What was detected in project that prompted this section] -->

[Placeholder guidance based on what was detected]

---

## [Next section...]
```

**Key principles:**
- Every required section from the Diataxis template is present
- `<!-- TODO -->` comments mark what needs filling
- `<!-- Detected: -->` comments explain WHY this scaffold was generated
- Placeholder text gives hints based on project analysis

#### 1.5.4 Smart Placeholder Content

Generate contextual placeholders based on detected project features:

**Example: `docs/reference/cli.md` for a Node.js project with `commander`:**

```markdown
# CLI Reference

> **Type:** Reference
> **Last Updated:** 2026-01-08
> **Status:** Scaffold - Needs content
> **Related:** [How-to: Common Commands](../how-to/common-commands.md)

Command-line interface reference for [project-name].

---

## Installation

<!-- TODO: Document installation method -->
<!-- Detected: package.json with bin field -->

```bash
npm install -g [package-name]
# or
npx [package-name]
```

---

## Commands

<!-- TODO: Document each command -->
<!-- Detected: commander usage in src/cli.ts -->

### `[command-name]`

**Usage:**
```bash
[project-name] [command] [options]
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--help` | boolean | — | Show help |
| <!-- TODO: Add detected options --> | | | |

---

## Environment Variables

<!-- TODO: Document environment variables -->
<!-- Detected: dotenv usage, .env.example exists -->

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| <!-- TODO: Extract from .env.example --> | | | |

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | General error |
| <!-- TODO: Add specific exit codes --> | |
```

#### 1.5.5 Scaffold Report

After generation, display:

```
╔═══════════════════════════════════════════════════════╗
║            DOCUMENTATION SCAFFOLDS GENERATED           ║
╠═══════════════════════════════════════════════════════╣
║  Project Type:          Node.js + React + Docker       ║
║  Scaffolds Created:     8                              ║
║                                                        ║
║  Core (always):                                        ║
║  ├── docs/README.md                    (index)         ║
║  ├── tutorials/getting-started.md      (tutorial)      ║
║  └── explanation/architecture.md       (explanation)   ║
║                                                        ║
║  Detected features:                                    ║
║  ├── reference/cli.md                  (has CLI)       ║
║  ├── reference/api.md                  (has API)       ║
║  ├── reference/configuration.md        (has config)    ║
║  ├── how-to/docker-deployment.md       (has Docker)    ║
║  └── how-to/running-tests.md           (has tests)     ║
║                                                        ║
║  Next steps:                                           ║
║  1. Review generated scaffolds                         ║
║  2. Fill in TODO sections                              ║
║  3. Run /migrate-docs --validate when complete         ║
╚═══════════════════════════════════════════════════════╝
```

#### 1.5.6 After Scaffolding

- **Exit workflow** (scaffolds are not migrated, they're already Diataxis-compliant)
- Create minimal manifest for tracking:

```json
{
  "version": "1.0.0",
  "action": "scaffold",
  "scaffolded_at": "2026-01-08T15:30:00Z",
  "project_type": ["nodejs", "react", "docker"],
  "detected_features": ["cli", "api", "config", "docker", "tests"],
  "scaffolds_created": [
    {"path": "docs/README.md", "type": "index"},
    {"path": "docs/tutorials/getting-started.md", "type": "tutorial"}
  ]
}
```

---

### Phase 2: Classification Analysis

For each document not already classified:

#### 2.1 Parse Document Structure

Split document by `## ` headings. Each H2 section is a classification unit.

#### 2.2 Apply Classification Heuristics

Score each section against all four types using weighted signals:

**TUTORIAL signals:**
| Signal | Pattern | Weight |
|--------|---------|--------|
| Learning objective | "you will learn", "in this tutorial", "by the end" | +25 |
| Prerequisites section | "## Prerequisites", "Before you begin" | +15 |
| Numbered learning steps | "Step 1:", numbered with outcomes | +20 |
| Verification prompts | "you should see", "verify that", "confirm" | +15 |
| **Anti-signal** | "alternatively", "you can also", choices | -20 |

**HOW-TO GUIDE signals:**
| Signal | Pattern | Weight |
|--------|---------|--------|
| Task-oriented title | "How to X", "Doing X" | +25 |
| Numbered action steps | `1. Do X`, `2. Run Y` (imperative) | +20 |
| Troubleshooting section | "## Troubleshooting", "Common errors" | +20 |
| Verification after steps | "Verify:", "Expected output:" | +10 |
| **Anti-signal** | Extended "why" explanations (>100 words) | -20 |

**REFERENCE signals:**
| Signal | Pattern | Weight |
|--------|---------|--------|
| Parameter/option tables | columns: Name, Type, Default, Description | +30 |
| Function signatures | `def func()`, `function()`, method definitions | +25 |
| Terse descriptions | One-line explanations, no narrative | +15 |
| API/CLI format | `--option`, `GET /endpoint`, `command args` | +20 |
| **Anti-signal** | Extended narrative (>50 words between items) | -25 |

**EXPLANATION signals:**
| Signal | Pattern | Weight |
|--------|---------|--------|
| Conceptual title | "Understanding X", "How X Works", "Why X" | +25 |
| Design decisions | "Why we chose", "Alternatives", "Tradeoffs" | +25 |
| Diagrams/models | ASCII art, `┌─┐`, architecture diagrams | +15 |
| Historical context | "Originally", "evolved", "history" | +10 |
| **Anti-signal** | Imperative instructions ("Run", "Execute") | -20 |

#### 2.3 Calculate Scores

```
For each section:
  scores = {tutorial: 0, howto: 0, reference: 0, explanation: 0}

  For each signal detected:
    scores[type] += signal.weight

  winner = max(scores)
  runner_up = second_highest(scores)
  confidence = normalize(winner - runner_up, 0, 100)
```

#### 2.4 Document-Level Classification

```
section_types = [classify(section) for section in sections]

IF all sections same type:
  → SINGLE-TYPE document
  → confidence = average(section_confidences)

ELIF one type < 20% of content:
  → SINGLE-TYPE (dominant)
  → Note minority type in metadata

ELSE (2+ types each > 20%):
  → HYBRID document
  → Mark for splitting
```

#### 2.5 Handle Low Confidence (< threshold)

For documents with confidence below threshold, batch questions:

```markdown
## Documents Requiring Clarification

I analyzed these documents but confidence is below 70%:

1. **`TESTING.md`** - 65% Reference, 35% How-to
   - Detected: Parameter tables (+30), but also step-by-step instructions (+20)
   - **Recommendation:** Split into Reference + How-to

2. **`ARCHITECTURE.md`** - 60% Explanation, 40% Reference
   - Detected: Design decisions (+25), but also API tables (+30)
   - **Recommendation:** Explanation (tables support the narrative)

For each, choose:
- **[T]** Tutorial | **[H]** How-to | **[R]** Reference | **[E]** Explanation
- **[S]** Split into multiple documents
- **[K]** Keep as-is (skip migration)
```

Use AskUserQuestion tool for batch clarification.

---

### Phase 3: Split Planning

For each HYBRID document:

#### 3.1 Generate Split Plan

```markdown
## Split Plan: DOCKER_DEPLOYMENT.md

Original sections → Target files:

| Section | Type (Confidence) | Target File |
|---------|-------------------|-------------|
| Overview | Explanation (85%) | explanation/docker-architecture.md |
| Quick Start | Tutorial (90%) | tutorials/docker-getting-started.md |
| Configuration | Reference (95%) | reference/docker-config.md |
| Deploying | How-to (88%) | how-to/deploy-docker.md |
| Troubleshooting | How-to (92%) | how-to/deploy-docker.md (append) |

Cross-references will be added to all split files.
```

#### 3.2 User Approval

Present split plan and allow overrides:
- Merge sections into different files
- Change target types
- Keep document as-is

---

### Phase 4: Migration Execution

#### 4.1 Create Archive Directory

```bash
mkdir -p docs/archive/pre-diataxis/
```

#### 4.2 Create Output Structure (if --structure categorized)

```bash
mkdir -p docs/tutorials/
mkdir -p docs/how-to/
mkdir -p docs/reference/
mkdir -p docs/explanation/
```

#### 4.3 Process Each Document

**For SINGLE-TYPE documents:**

1. Add Diataxis header:
   ```markdown
   # [Original Title]

   > **Type:** [Tutorial | How-to Guide | Reference | Explanation]
   > **Last Updated:** [Today's date]
   > **Related:** [Auto-detected links]

   [Original content]
   ```

2. Write to appropriate directory (or in-place if --structure flat)
3. Move original to archive

**For HYBRID documents:**

1. Create each split file with:
   - Diataxis header
   - Extracted sections
   - Cross-reference section:
     ```markdown
     ---

     ## Related Documentation

     This document was created from `DOCKER_DEPLOYMENT.md`:
     - **Tutorial:** [Getting Started](../tutorials/docker-getting-started.md)
     - **How-to:** [Deploy Docker](../how-to/deploy-docker.md)
     - **Reference:** [Configuration](../reference/docker-config.md)
     ```

2. Move original to archive

#### 4.4 Update Cross-References

Scan all migrated documents for internal links. Update paths to new locations.

---

### Phase 5: Validation & Report

#### 5.1 Validate Migration

- [ ] All new files have Diataxis headers
- [ ] No broken internal links
- [ ] Archive contains all originals
- [ ] Manifest is complete

#### 5.2 Generate Migration Report

Display console summary:

```
╔═══════════════════════════════════════════════════════╗
║            DIATAXIS MIGRATION COMPLETE                 ║
╠═══════════════════════════════════════════════════════╣
║  Documents Processed:     47                           ║
║  ├── Single-type:         29  (added headers)          ║
║  ├── Split:               12  (created 31 new files)   ║
║  └── Skipped:              3  (user: keep-as-is)       ║
║                                                        ║
║  New File Count:          63                           ║
║  Cross-references Updated: 127                         ║
║  Archived Files:          44                           ║
║                                                        ║
║  By Type:                                              ║
║  ├── Tutorials:           8                            ║
║  ├── How-to Guides:      24                            ║
║  ├── Reference:          19                            ║
║  └── Explanation:        12                            ║
╚═══════════════════════════════════════════════════════╝

Manifest saved: docs/archive/pre-diataxis/migration-manifest.json
```

#### 5.3 Create Migration Manifest

Save JSON manifest for rollback capability:

```json
{
  "version": "1.0.0",
  "migrated_at": "2026-01-08T15:30:00Z",
  "source_path": "docs/",
  "options": {
    "confidence_threshold": 70,
    "structure": "categorized",
    "split_enabled": true
  },
  "migrations": [
    {
      "original": "docs/DOCKER_DEPLOYMENT.md",
      "archived_to": "docs/archive/pre-diataxis/DOCKER_DEPLOYMENT.md",
      "action": "split",
      "results": [
        {
          "path": "docs/tutorials/docker-getting-started.md",
          "type": "tutorial",
          "confidence": 90,
          "sections": ["Quick Start"]
        },
        {
          "path": "docs/how-to/deploy-docker.md",
          "type": "how-to",
          "confidence": 88,
          "sections": ["Deploying", "Troubleshooting"]
        }
      ]
    },
    {
      "original": "docs/API.md",
      "archived_to": "docs/archive/pre-diataxis/API.md",
      "action": "migrate",
      "results": [
        {
          "path": "docs/reference/api.md",
          "type": "reference",
          "confidence": 95,
          "sections": ["*"]
        }
      ]
    }
  ],
  "statistics": {
    "total_processed": 47,
    "single_type": 29,
    "split": 12,
    "skipped": 3,
    "new_files_created": 63,
    "cross_references_updated": 127
  }
}
```

---

## Edge Cases

| Case | Detection | Handling |
|------|-----------|----------|
| No documentation | 0 files in docs/ | Trigger scaffold generation (Phase 1.5) |
| Empty document | < 100 bytes | Skip, report "too small to classify" |
| All code blocks | > 80% fenced code | Classify as Reference |
| Already Diataxis | Has `> **Type:**` header | Validate header, update if needed |
| Generated docs | "Auto-generated", "DO NOT EDIT" | Skip with warning |
| Large documents | > 5000 words | Force split review regardless of confidence |
| External import | `--import` flag | Add provenance header with source |
| Deeply nested | > 3 directory levels | Preserve relative structure |
| Scaffold exists | Has `Status: Scaffold` header | Prompt to fill or skip |
| Mixed scaffold/real | Some scaffolds, some real docs | Migrate real docs, report unfilled scaffolds |

---

## Rollback

To restore from archive:

```
/migrate-docs --rollback
```

This will:
1. Read `docs/archive/pre-diataxis/migration-manifest.json`
2. Delete all files listed in `results[].path`
3. Move archived originals back to their original locations
4. Delete empty type directories

---

## Validation Mode

To validate a previous migration:

```
/migrate-docs --validate
```

Checks:
- All migrated files still exist
- All files have valid Diataxis headers
- No broken internal links
- Archive is intact
- Manifest matches filesystem state

---

## Override File

For automation, create `.diataxis-overrides.yml` in the target directory:

```yaml
# Skip these files entirely
skip:
  - CHANGELOG.md
  - auto-generated/*.md

# Force classification (bypass heuristics)
overrides:
  docs/TESTING.md:
    type: reference
    split: false

  docs/COMPLEX.md:
    type: split
    sections:
      "Getting Started": tutorial
      "API Reference": reference
      "Architecture": explanation

# Custom output paths
paths:
  tutorials: guides/learn/
  how-to: guides/tasks/
  reference: api/
  explanation: concepts/
```

---

## Templates Used

This skill uses templates from:
- `~/.claude/commands/templates/documentation/tutorial.md`
- `~/.claude/commands/templates/documentation/how-to-guide.md`
- `~/.claude/commands/templates/documentation/reference.md`
- `~/.claude/commands/templates/documentation/explanation.md`

---

## Related

- `/process-doc` — Generate a new How-to Guide
- `~/.claude/commands/templates/documentation/DIATAXIS-QUICK-REFERENCE.md` — Framework reference
- https://diataxis.fr/ — Official Diataxis documentation
