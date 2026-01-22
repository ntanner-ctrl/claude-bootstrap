---
description: Use when setting up ANY new project for Claude Code. Creates CLAUDE.md, installs hooks, agents, and commands matched to your stack.
argument-hint: --force to overwrite existing, --skip-claude-md to keep existing docs, --type python|node|docker
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - AskUserQuestion
  - Task
---

# Project Bootstrap

Complete Claude Code extensibility setup for any project. This command:
1. Analyzes your project structure, type, and maturity
2. Generates comprehensive CLAUDE.md documentation
3. Installs appropriate stock hooks, agents, and commands
4. Tracks what's installed for future updates

Think hard before making changes. Take time to understand the project first.

## Arguments

- `--force`: Overwrite existing stock elements (respects customizations by default)
- `--skip-claude-md`: Don't generate/update CLAUDE.md (keep existing)
- `--skip-stock`: Don't install stock elements (documentation only)
- `--type <type>`: Force project type (python, node, rust, go, docker, monorepo)
- `--minimal`: Install only essential elements (hooks only, no agents/commands)

---

# PHASE 1: Project Analysis

## 1.1 Structure Scan

Read the root directory structure (2-3 levels deep):

```
Questions to answer:
- What is the project root layout?
- What are the main source directories?
- What configuration files exist?
- Is there an existing .claude/ directory?
```

## 1.2 Language & Framework Detection

Identify primary technologies:

| Indicator | Language/Framework | Project Type |
|-----------|-------------------|--------------|
| `pyproject.toml`, `setup.py`, `requirements.txt` | Python | python |
| `package.json` | Node.js | node |
| `package.json` + `react` dep | React | react |
| `package.json` + `vue` dep | Vue | vue |
| `package.json` + `next` dep | Next.js | nextjs |
| `Cargo.toml` | Rust | rust |
| `go.mod` | Go | go |
| `Dockerfile`, `docker-compose.yml` | Docker | docker |
| `*.tf`, `terraform/` | Terraform | terraform |
| `serverless.yml` | Serverless | serverless |
| Multiple `package.json` or `pyproject.toml` | Monorepo | monorepo |

Record all detected types (a project can be multiple: python + docker + terraform).

## 1.3 Maturity Assessment

Score the project 0-10 based on these signals:

### Nascent Signals (lower score)
- [ ] <10 source files (-2)
- [ ] <5 git commits (-2)
- [ ] No test directory (-1)
- [ ] No CI/CD config (-1)
- [ ] No documentation beyond README (-1)

### Mature Signals (higher score)
- [ ] >50 source files (+2)
- [ ] >100 git commits (+1)
- [ ] Multiple test directories (+1)
- [ ] CI/CD configuration present (+1)
- [ ] Existing .claude/ directory with content (+2)
- [ ] Custom commands/hooks/agents defined (+2)
- [ ] Comprehensive README/docs (+1)

**Maturity Levels:**
- **Nascent** (0-3): New project, install full starter kit
- **Growing** (4-6): Established patterns, selective installation
- **Mature** (7-10): Complex project, suggest rather than install

## 1.4 Existing Setup Audit

If `.claude/` exists:

1. Read `.claude/bootstrap-manifest.json` if present
2. List existing hooks, agents, commands
3. Identify which are stock vs custom (via manifest or heuristics)
4. Check for customizations (hash comparison if manifest exists)

---

# PHASE 2: CLAUDE.md Generation

Use the assess-project methodology to generate comprehensive documentation.

## 2.1 Exploration

### Structure Analysis
- Read root directory structure (2-3 levels)
- Identify primary language(s) and framework(s)
- Note build system, package manager, dependencies
- Find configuration files (.env.example, docker-compose, CI configs)

### Conventions Detection
- Sample 3-5 representative source files
- Check for linting/formatting configs
- Identify testing framework(s) and patterns
- Note naming conventions (files, functions, classes)

### Documentation Audit
- Read existing README, CONTRIBUTING, architectural docs
- Check for existing CLAUDE.md
- Identify undocumented but important patterns

### Workflow Discovery
- Find available scripts (package.json, Makefile, shell scripts)
- Identify how to: build, test, lint, run locally, deploy
- Note multi-service or monorepo patterns

## 2.2 Gap Analysis

Identify:
1. What would need to be rediscovered each session?
2. What ambiguities would slow down development?
3. What areas are error-prone without guidance?
4. What manual steps could be automated?

## 2.3 Generate CLAUDE.md

Create or update `.claude/CLAUDE.md` with:

```markdown
# [Project Name]

[One sentence description]

## Quick Reference
- Build: `[command]`
- Test: `[command]`
- Lint: `[command]`
- Run locally: `[command]`
- Deploy: `[command]` (if applicable)

## Architecture Overview
[2-3 sentences on structure and key patterns]

## Project Structure
- `src/` - [Description]
- `tests/` - [Description]
- [Other key directories]

## Key Conventions
- [Naming conventions]
- [File organization patterns]
- [Import/module patterns]
- [Code style requirements]

## Key Patterns
[Document important architectural patterns used in this codebase]

### [Pattern Name]
```[language]
[Code example showing the pattern]
```

## Important Context
- [Non-obvious dependencies or requirements]
- [Things that look wrong but are intentional]
- [Areas requiring extra care]
- [Environment setup requirements]

## Common Tasks

### How to add a new [X]
1. [Step 1]
2. [Step 2]

### How to modify [Y]
1. [Step 1]
2. [Step 2]

## Testing
- Test command: `[command]`
- Test location: `[directory]`
- [Testing conventions and expectations]

## Do Not
- [Anti-patterns specific to this project]
- [Files/areas to avoid modifying]
- [Common mistakes to avoid]
```

---

# PHASE 3: Stock Element Selection

Based on maturity and project type, select appropriate elements.

## 3.1 Selection Logic

```
IF maturity = nascent (0-3):
    Install ALL universal hooks
    Install troubleshooter + code-reviewer agents
    Skip commands (no established workflows yet)

ELIF maturity = growing (4-6):
    Install universal hooks IF NOT already present
    Install project-type-specific elements
    Suggest commands for detected workflows

ELSE maturity = mature (7-10):
    Only install explicitly requested elements
    Suggest rather than auto-install
    Focus on filling gaps in existing setup
```

## 3.2 Universal Elements (All Projects)

**Hooks:**
- `test-coverage-reminder.md` - Remind about tests when editing source
- `security-warning.md` - Warn when editing sensitive files

**Agents:**
- `troubleshooter.md` - Systematic issue diagnosis
- `code-reviewer.md` - Code review with confidence scoring

## 3.3 Project-Type Specific Elements

### Python Projects
**Additional hooks:**
- Consider: type-checking reminder, docstring validation

**Commands:**
- `test-all.md` configured for pytest

### Node/React Projects
**Additional hooks:**
- Consider: dependency audit reminder

**Commands:**
- `test-all.md` configured for jest/vitest

### Docker Projects
**Additional hooks:**
- Consider: Dockerfile best practices validation

**Agents:**
- Consider: container troubleshooter

### Monorepo Projects
**Additional agents:**
- Consider: workspace navigator

---

# PHASE 4: Installation

## 4.1 Create Directory Structure

```bash
mkdir -p .claude/hooks .claude/agents .claude/commands
```

## 4.2 Copy Stock Elements

For each selected element:

1. Read template from `~/.claude/commands/templates/stock-{type}/{name}.md`
2. Apply any project-specific customizations:
   - Update file patterns to match project structure
   - Adjust tool references to match project
3. Write to `.claude/{type}/{name}.md`
4. Compute SHA-256 hash for tracking

## 4.3 Create/Update Manifest

Create `.claude/bootstrap-manifest.json`:

```json
{
  "version": "1.0.0",
  "bootstrapped_at": "2026-01-08T12:00:00Z",
  "project_type": ["python", "docker"],
  "maturity_score": 5,
  "stock_elements": {
    "hooks/test-coverage-reminder.md": {
      "source_version": "1.0.0",
      "installed_hash": "sha256:abc123...",
      "customized": false
    },
    "hooks/security-warning.md": {
      "source_version": "1.0.0",
      "installed_hash": "sha256:def456...",
      "customized": false
    },
    "agents/troubleshooter.md": {
      "source_version": "1.0.0",
      "installed_hash": "sha256:ghi789...",
      "customized": false
    }
  },
  "custom_elements": [
    "hooks/custom-validation.md",
    "agents/domain-expert.md"
  ]
}
```

## 4.4 Handle Re-runs

When bootstrap has already run:

1. Read existing manifest
2. For each stock element:
   - Compute current file hash
   - Compare to `installed_hash` in manifest
   - If different: Mark as customized, DO NOT overwrite (unless --force)
   - If same: Safe to update if newer template available
3. Preserve custom elements (not in stock list)
4. Update manifest with new timestamp

---

# PHASE 5: Recommendations

After installation, provide additional recommendations:

## 5.1 Custom Elements

Based on project analysis, suggest project-specific:

### Custom Hooks
If patterns detected that would benefit from validation hooks:
```
Consider creating: .claude/hooks/[pattern]-validation.md
- Purpose: [Why this would help]
- Pattern: [File glob to match]
```

### Custom Agents
If domain complexity detected:
```
Consider creating: .claude/agents/[domain]-expert.md
- Purpose: [What domain knowledge would help]
- Use case: [When to invoke]
```

### Custom Commands
If repetitive workflows detected:
```
Consider creating: .claude/commands/[workflow].md
- Purpose: [What it automates]
- Trigger: [When users would run this]
```

## 5.2 MCP Integrations

If project would benefit:
- Database MCP for data-heavy projects
- GitHub MCP for PR-heavy workflows
- Cloud provider MCPs for infrastructure projects

## 5.3 Priority Ranking

Rank all recommendations:
1. **Immediate** - Will improve next session significantly
2. **Soon** - Worth setting up this week
3. **Eventually** - Nice to have as project matures

---

# PHASE 6: Summary Report

Output a complete summary:

```markdown
## Bootstrap Complete

### Project Profile
- **Type:** Python + Docker
- **Maturity:** Growing (score: 5/10)
- **Existing setup:** None (fresh bootstrap)

### What Was Installed

#### CLAUDE.md
Created `.claude/CLAUDE.md` with:
- Quick Reference (5 commands)
- Architecture Overview
- Key Patterns (3 documented)
- Common Tasks (4 how-tos)

#### Hooks (2)
- `test-coverage-reminder.md` - Reminds about tests
- `security-warning.md` - Warns on sensitive files

#### Agents (2)
- `troubleshooter.md` - Systematic debugging
- `code-reviewer.md` - Code review

#### Commands (0)
Skipped - project is nascent, run `/bootstrap-project` again when workflows are established

### Recommendations

#### High Priority
1. Create interface validation hook for your `*_service.py` pattern
2. Consider domain-specific troubleshooter for [detected domain]

#### Medium Priority
3. Add scaffold command when you establish module patterns
4. Consider pytest coverage hook after test suite grows

### Next Steps
1. Review generated CLAUDE.md and refine
2. Test the installed hooks by editing a source file
3. Try `/troubleshooter` agent on your next bug

### Maintenance
- Run `/check-project-setup` periodically to detect drift
- Run `/refresh-claude-md` to update documentation
- Re-run `/bootstrap-project` after major architectural changes
```

---

# Templates Location

Stock element templates are stored at:
```
~/.claude/commands/templates/
├── stock-hooks/
│   ├── test-coverage-reminder.md
│   ├── security-warning.md
│   └── interface-validation.md
├── stock-agents/
│   ├── troubleshooter.md
│   ├── code-reviewer.md
│   └── architecture-explainer.md
└── stock-commands/
    ├── test-all.md
    ├── health-check.md
    └── scaffold.md
```

---

$ARGUMENTS
