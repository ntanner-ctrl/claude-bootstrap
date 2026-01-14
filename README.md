# Claude Code Bootstrap Toolkit

Automatically set up Claude Code extensibility for any project with appropriate hooks, agents, commands, and CLAUDE.md documentation.

**New to Bootstrap?** See the [Getting Started Guide](GETTING_STARTED.md) for a complete walkthrough.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/ntanner-ctrl/claude-bootstrap/master/install.sh | bash
```

## What It Does

When you run `/bootstrap-project` in any project, it will:

1. **Analyze** your project (type, maturity, existing setup)
2. **Generate** comprehensive CLAUDE.md documentation
3. **Install** appropriate stock hooks, agents, and commands
4. **Track** what's installed for safe re-runs

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
| `remote-exec-protection` | block | `curl \| bash` and similar patterns |
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

## License

MIT
