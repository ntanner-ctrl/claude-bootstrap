# Commands Reference

Complete reference for all Claude Bootstrap commands.

---

## Quick Reference

| Command | One-liner |
|---------|-----------|
| `/start` | Assess state, recommend next task |
| `/bootstrap-project` | Full project setup with CLAUDE.md + hooks + agents |
| `/check-project-setup` | Quick drift detection |
| `/brainstorm` | Structured problem analysis before solutioning |
| `/delegate` | Execute tasks using best-fit subagents |
| `/requirements-discovery` | Extract validated requirements before building |
| `/security-checklist` | 8-point OWASP-style security audit |
| `/push-safe` | Commit and push with secret scanning |
| `/gpt-review` | Multi-model adversarial code review |
| `/setup-hooks` | Configure formatting hooks for your stack |
| `/refresh-claude-md` | Update CLAUDE.md with recent changes |
| `/migrate-docs` | Migrate documentation to Diataxis framework |
| `/process-doc` | Generate How-to Guides |
| `/assess-project` | CLAUDE.md generation only (legacy) |

---

## Project Setup

Commands for initializing and maintaining Claude Code configuration.

### `/bootstrap-project`

**Full project setup.** Analyzes your project and installs appropriate CLAUDE.md documentation, hooks, agents, and commands based on your tech stack and project maturity.

```
/bootstrap-project
```

The bootstrap process runs through 6 phases:
1. **Analyze** - Detect languages, frameworks, build systems
2. **Assess Maturity** - Nascent → Growing → Mature
3. **Generate CLAUDE.md** - Comprehensive project documentation
4. **Install Hooks** - Safety guards appropriate to your stack
5. **Install Agents** - Specialized subagents for complex tasks
6. **Install Commands** - Project-specific shortcuts

**When to use:** First time setting up Claude Code in a project, or after major project changes.

---

### `/check-project-setup`

**Quick drift detection.** Checks if your Claude Code setup has drifted from your project's current state.

```
/check-project-setup
```

Detects:
- New directories not documented in CLAUDE.md
- Commands that no longer work
- Missing recommended hooks
- Stale manifest data

**When to use:** Periodically, or when things feel "off."

---

### `/assess-project`

**CLAUDE.md generation only.** Generates project documentation without installing hooks, agents, or commands.

```
/assess-project
```

> **Note:** This command has been superseded by `/bootstrap-project`. Use this only if you specifically want documentation without extensibility setup.

---

## Session & Workflow

Commands for starting sessions and structuring work.

### `/start`

**Session starter.** Quickly assesses project state and recommends the optimal next task.

```
/start
```

Checks (in parallel):
- Uncommitted changes (`git status`)
- Recent commits (`git log`)
- Existing to-do items
- TODO/FIXME comments in recently modified files

Returns a prioritized recommendation with complexity estimate and alternatives.

**When to use:** Beginning of every session. Helps you pick up where you left off.

---

### `/brainstorm`

**Structured problem analysis.** Forces thorough analysis before jumping to solutions.

```
/brainstorm [problem description]
```

Two-phase approach:
1. **Analysis Phase** - Root cause analysis, context review, clarifying questions
2. **Solution Phase** - Only after you've answered the clarifying questions

This prevents the common failure mode of solving the wrong problem efficiently.

**When to use:** Complex problems, unclear requirements, or when you keep solving symptoms instead of root causes.

---

### `/delegate`

**Smart task delegation.** Executes tasks using best-fit subagents, with parallel execution when possible.

```
/delegate [task]
/delegate              # (no args: executes pending to-do items)
```

Selects appropriate agents:
- `Explore` - Codebase exploration, architecture understanding
- `Plan` - Complex implementation requiring architectural decisions
- `general-purpose` - Multi-step research and code search
- Domain-specific agents if available

**When to use:** Multiple independent tasks that can run in parallel, or when you want automatic agent selection.

---

### `/requirements-discovery`

**Extract validated requirements.** Drills past symptoms to find root problems using the "WHY detective" approach.

```
/requirements-discovery
```

Three question categories:
1. **Job to be Done** - What outcome? What stakes? Current workarounds?
2. **The Real Problem** - Symptom vs root cause? Why does this exist?
3. **Success Criteria** - How will you know it's solved? MVP vs stretch?

**When to use:** Before `/feature-dev` for complex features, when requirements are unclear, or when you need stakeholder alignment.

---

## Code Quality & Security

Commands for maintaining code quality and security posture.

### `/security-checklist`

**8-point security audit.** Comprehensive OWASP-aligned security assessment.

```
/security-checklist
```

Checks:
1. **Secrets Exposure** - Hardcoded creds, .gitignore, git history
2. **Dependencies** - CVEs via npm audit, pip-audit, cargo audit
3. **Input Validation** - SQL injection, command injection, XSS
4. **Auth & AuthZ** - Password hashing, sessions, CSRF, rate limiting
5. **Transport Security** - HSTS, TLS 1.2+, secure cookies
6. **Error Handling** - Stack traces, generic messages
7. **File Uploads** - Server-side validation, size limits
8. **API Security** - Auth required, rate limits, CORS

Severity classification: Critical (block deploy) → High (7 days) → Medium (30 days) → Low (backlog)

**When to use:** Before releases, during security reviews, or as part of CI/CD.

---

### `/push-safe`

**Safe push with secret scanning.** Stages, commits, and pushes with comprehensive safety checks.

```
/push-safe
```

Blocks if detected:
- **Secrets** - `.env*`, `*.key`, `*.pem`, credentials, API keys
- **Large files** - >10MB without Git LFS
- **Build artifacts** - `node_modules/`, `dist/`, `__pycache__/`

**When to use:** Instead of raw `git push` when you want guardrails.

---

### `/gpt-review`

**Multi-model adversarial review.** Collaborative review where Claude and GPT work as a surgical team.

```
/gpt-review [--analyze <pr-url>] [--focus security|performance|architecture|all]
```

Workflow:
1. **Diagnosis** (Claude) - Interview user, explore codebase, identify issues
2. **Surgical Plan** (Claude) - Generate prompt with priorities for GPT
3. **Operation** (GPT via user) - Technical precision, implementation
4. **Post-Op Review** (Claude) - Validate, synthesize, deliver verdict

**When to use:** Critical code requiring multiple perspectives, or when you want adversarial validation.

---

### `/setup-hooks`

**Configure formatting hooks.** Detects your tech stack and configures appropriate PostToolUse formatting hooks.

```
/setup-hooks
```

Auto-detects:
- JavaScript/TypeScript → Prettier, ESLint
- Python → Black, Ruff
- Rust → rustfmt
- Go → gofmt
- PHP → php-cs-fixer

**When to use:** After project setup, or when you add a new language to your project.

---

## Documentation

Commands for creating and maintaining documentation.

### `/refresh-claude-md`

**Update CLAUDE.md.** Scans for drift and suggests updates to keep project documentation current.

```
/refresh-claude-md
```

Checks:
- Do documented commands still work?
- Are there new directories or files not mentioned?
- Have new dependencies been added?
- Are there patterns emerging in recent code?

Returns a diff-style summary of recommended changes.

**When to use:** After significant project changes, or when CLAUDE.md feels stale.

---

### `/migrate-docs`

**Diataxis migration.** Migrates existing documentation to the Diataxis framework (Tutorial, How-to, Reference, Explanation).

```
/migrate-docs [path] [options]
```

Options:
- `--dry-run` - Preview without writing
- `--scaffold` - Generate scaffolds for undocumented project
- `--validate` - Validate existing migration
- `--rollback` - Restore from archive

**When to use:** When restructuring documentation, or starting fresh with Diataxis.

---

### `/process-doc`

**Generate How-to Guides.** Creates task-oriented documentation following Diataxis How-to Guide format.

```
/process-doc [topic]
```

Examples:
- `/process-doc device reboot`
- `/process-doc azure-ad-setup`

**When to use:** When you need to document a specific procedure or workflow.

---

## Stock Elements

The `templates/` directory contains stock elements installed by `/bootstrap-project`:

```
templates/
├── stock-agents/           # Specialized subagents
│   ├── architecture-explainer.md
│   ├── code-reviewer.md
│   └── troubleshooter.md
├── stock-commands/         # Project-specific commands
│   ├── health-check.md
│   ├── scaffold.md
│   └── test-all.md
├── stock-hooks/            # Prompt-based hooks
│   ├── documentation-standards.md
│   ├── interface-validation.md
│   ├── security-warning.md
│   └── test-coverage-reminder.md
└── INSTALL.md              # Installation guide
```

These are selectively installed based on your project type and maturity level.
