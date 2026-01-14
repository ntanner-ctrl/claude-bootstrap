# Claude Code Bootstrap Toolkit

> Extensibility tools for Claude Code - the CLI-based AI coding assistant.

Automatically set up Claude Code extensibility for any project with appropriate hooks, agents, commands, and CLAUDE.md documentation.

**New to Bootstrap?** See the [Getting Started Guide](GETTING_STARTED.md) for a complete walkthrough.

## What's Included

| Component | Purpose | Audience |
|-----------|---------|----------|
| **Bootstrap Toolkit** | Meta-tool that sets up Claude Code for any project | Everyone |
| **[Ops Starter Kit](ops-starter-kit/)** | Domain-specific extensions for infrastructure/ops work | SREs, DevOps, Platform Engineers |

```
┌─────────────────────────────────────────────────────────────┐
│                    Bootstrap Toolkit                         │
│         (Meta-tool: sets up Claude Code for any project)     │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ can generate domain-specific kits
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Ops Starter Kit                          │
│    (Example: Claude Code extensions for ops/infra work)      │
└─────────────────────────────────────────────────────────────┘
```

The **Ops Starter Kit** demonstrates what the Bootstrap approach can produce when specialized for a domain. It serves as:

1. **A working example** of hooks, agents, and commands in action
2. **A template** for creating your own domain-specific kits
3. **Immediately useful** for anyone doing infrastructure/ops work

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/ntanner-ctrl/claude-bootstrap/master/install.sh | bash
```

## Commands

| Command | Purpose |
|---------|---------|
| `/bootstrap-project` | Full project setup |
| `/check-project-setup` | Quick drift detection |
| `/security-checklist` | 8-point security audit |

## Defense-in-Depth Security

This toolkit implements layered security through multiple mechanisms:

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 1: Shell Hooks (PreToolUse) - Deterministic blocking     │
│  dangerous-commands.sh, secret-scanner.sh                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 2: Hookify Rules - Prompt-based warnings/blocks          │
│  Customizable YAML rules with Claude-readable explanations      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 3: CLAUDE.md - Behavioral guidance (suggestions)         │
└─────────────────────────────────────────────────────────────────┘
```

## Shell Hooks (`hooks/`)

Production-ready shell hooks using best practices:

| Hook | Event | Purpose |
|------|-------|---------|
| `notify.sh` | Notification | Desktop alerts (macOS, Linux, WSL) |
| `after-edit.sh` | PostToolUse | Auto-format files after edits |
| `dangerous-commands.sh` | PreToolUse | Block dangerous bash commands with feedback |
| `secret-scanner.sh` | PreToolUse | Scan staged files before git commits |

### Key Patterns Implemented

- **Fail-open**: Hooks exit 0 on errors (work continues if hook breaks)
- **Exit code 2**: Blocks operation AND sends feedback TO Claude
- **Timeouts**: Prevents runaway processes (10-30s limits)
- **Surgical blocking**: Blocks specific dangerous targets, not blanket patterns

### Installation

Copy to `~/.claude/hooks/` and add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [
        { "type": "command", "command": "~/.claude/hooks/dangerous-commands.sh" },
        { "type": "command", "command": "~/.claude/hooks/secret-scanner.sh" }
      ]
    }],
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{ "type": "command", "command": "~/.claude/hooks/after-edit.sh" }]
    }],
    "Notification": [{
      "matcher": "*",
      "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh" }]
    }]
  }
}
```

See `settings-example.json` for full configuration.

## Hookify Rules (`hookify-rules/`)

Ready-to-use hookify rules for common security patterns:

| Rule | Action | What It Blocks |
|------|--------|----------------|
| `surgical-rm` | block | `rm -rf /`, `~`, `..`, `/home` (allows safe targets like `node_modules`) |
| `force-push-protection` | block | Force push to main/master/production/release/develop |
| `chmod-777` | block | World-writable permissions (`chmod 777`, `chmod a+rwx`) |
| `remote-exec-protection` | block | `curl | bash` and similar patterns |
| `disk-ops-protection` | block | Direct disk writes (`dd of=/dev/*`, `mkfs`) |
| `exfiltration-protection` | block | Network transfers of `.env`, `.pem`, `.key` files |
| `env-exposure-protection` | warn | Reading `.env` files (warns but allows) |

### Installation

Copy to `~/.claude/` (hookify reads `*.local.md` files automatically):

```bash
cp hookify-rules/*.local.md ~/.claude/
```

## Stock Hooks (Prompt-Based)

Template hooks installed via `/bootstrap-project`:

- **test-coverage-reminder** - Reminds about tests when editing source files
- **security-warning** - Warns when editing sensitive files
- **interface-validation** - Template for project-specific pattern validation

## Stock Agents

- **troubleshooter** - Systematic issue diagnosis using 5-step methodology
- **code-reviewer** - Code review with confidence-based filtering
- **architecture-explainer** - Explains how parts of the codebase work

## Stock Commands (installed selectively)

- **test-all** - Run all tests with automatic framework detection
- **health-check** - Validate project configuration and dependencies
- **scaffold** - Generate new modules following project conventions
- **security-checklist** - Comprehensive 8-point security audit

## Security Checklist (`/security-checklist`)

Structured security audit covering:

1. **Secrets Exposure** - Hardcoded creds, .gitignore, git history
2. **Dependencies** - CVEs via npm audit, pip-audit, cargo audit, etc.
3. **Input Validation** - SQL injection, command injection, XSS
4. **Auth & AuthZ** - Password hashing, sessions, CSRF, rate limiting
5. **Transport Security** - HSTS, TLS 1.2+, secure cookies
6. **Error Handling** - Stack traces, generic messages
7. **File Uploads** - Server-side validation, size limits
8. **API Security** - Auth required, rate limits, CORS

Severity classification: Critical (block deploy) → High (7 days) → Medium (30 days) → Low (backlog)

## Philosophy

### Context is Everything

Claude Code is powerful, but without context about your project, it's guessing. These tools provide that context:

- **CLAUDE.md** tells Claude about your conventions, architecture, and workflows
- **Hooks** catch mistakes before they happen
- **Agents** bring specialized expertise to complex tasks
- **Commands** encode your team's best practices

### Safety by Default

Every hook exists because someone, somewhere, made that mistake:
- Committed secrets to git
- Edited production config by accident
- Ran `rm -rf` in the wrong directory
- Forgot to write tests

### Evolve, Don't Prescribe

The bootstrap toolkit adapts to your project's maturity:
- New projects get a full starter kit
- Established projects get suggestions, not overrides
- The goal is enhancement, not enforcement

## Creating Your Own Domain Kit

Use the Ops Starter Kit as a template:

```bash
cp -r ops-starter-kit my-domain-kit
```

Then customize:
1. **Hooks** - What mistakes should be caught?
2. **Agents** - What complex tasks need guidance?
3. **Commands** - What workflows should be encoded?
4. **Template** - What should CLAUDE.md contain?

Ideas for domain kits:
- **Frontend Kit** - Component patterns, accessibility, performance
- **Data Engineering Kit** - Pipeline safety, data validation, schema management
- **ML Ops Kit** - Model versioning, experiment tracking, deployment
- **Security Kit** - Vulnerability scanning, compliance, audit logging

## Maturity-Aware

Bootstrap behaves differently based on project maturity:

| Maturity | Behavior |
|----------|----------|
| Nascent (new) | Full starter kit, generate CLAUDE.md |
| Growing | Selective additions, suggest commands |
| Mature | Preserve existing, suggest only |

## Manual Installation

```bash
git clone https://github.com/ntanner-ctrl/claude-bootstrap.git
cd claude-bootstrap
./install.sh
```

Or install components individually:

```bash
# Shell hooks only
cp hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh

# Hookify rules only
cp hookify-rules/*.local.md ~/.claude/

# Commands only
cp commands/security-checklist.md ~/.claude/commands/
```

## Research

See `hooks/HOOK-PATTERNS-RESEARCH.md` for detailed documentation on:
- Dangerous command patterns (surgical vs blanket blocking)
- Fail-open vs fail-closed patterns
- Exit code conventions (0=allow, 1=error, 2=block with feedback)
- Timeout patterns for quality checks

## Acknowledgments

This toolkit was built with inspiration and patterns from:

- **[TheDecipherist/claude-code-mastery](https://github.com/TheDecipherist/claude-code-mastery)** - Shell hook patterns, dangerous command blocking, fail-open architecture, exit code conventions, and security enforcement research. The defense-in-depth approach and many of the surgical blocking patterns were adapted from their work.

- **[bmad-code-org/BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD)** - Agent orchestration patterns and multi-agent workflow concepts.

Thanks to both projects for sharing their approaches publicly.

## Contributing

Found a useful hook? Built a great agent? PRs welcome!

## License

MIT - Use it, modify it, share it.

---

*Built by [@flawlesscowboy0](https://reddit.com/u/flawlesscowboy0) after one too many 3 AM pages.*
