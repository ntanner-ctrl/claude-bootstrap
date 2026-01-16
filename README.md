# Claude Code Bootstrap Toolkit

> Extensibility tools for Claude Code - the CLI-based AI coding assistant.

Give Claude Code the context it needs: **CLAUDE.md documentation**, **safety hooks**, **specialized agents**, and **workflow commands**.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/ntanner-ctrl/claude-bootstrap/master/install.sh | bash
```

Then in any project:

```bash
cd /your/project
claude
/bootstrap-project
```

**New to this?** See the [Getting Started Guide](GETTING_STARTED.md).

---

## What's Included

| Component | Purpose |
|-----------|---------|
| [**Commands**](commands/README.md) | 14 workflow commands for setup, planning, security, documentation |
| [**Shell Hooks**](hooks/) | Production-ready safety guards (dangerous commands, secret scanning) |
| [**Hookify Rules**](hookify-rules/) | 7 YAML-based security rules |
| [**Ops Starter Kit**](ops-starter-kit/) | Domain-specific extensions for infrastructure work |
| [**Bootstrap Plugin**](plugins/bootstrap-toolkit/) | Session-start drift detection |

### Commands at a Glance

| Category | Commands |
|----------|----------|
| **Setup** | `/bootstrap-project`, `/check-project-setup`, `/assess-project` |
| **Workflow** | `/start`, `/brainstorm`, `/delegate`, `/requirements-discovery` |
| **Security** | `/security-checklist`, `/push-safe`, `/gpt-review`, `/setup-hooks` |
| **Docs** | `/refresh-claude-md`, `/migrate-docs`, `/process-doc` |

See [commands/README.md](commands/README.md) for full reference.

---

## Defense-in-Depth Security

Three layers of protection:

```
Layer 1: Shell Hooks      → Deterministic blocking (can't be bypassed)
Layer 2: Hookify Rules    → Claude-aware warnings/blocks
Layer 3: CLAUDE.md        → Behavioral guidance (suggestions)
```

See [docs/SECURITY.md](docs/SECURITY.md) for architecture details.

### Shell Hooks

| Hook | Purpose |
|------|---------|
| `dangerous-commands.sh` | Block `rm -rf /`, `chmod 777`, force push to main |
| `secret-scanner.sh` | Scan for API keys before commits |
| `after-edit.sh` | Auto-format files |
| `notify.sh` | Desktop notifications |

### Hookify Rules

| Rule | What It Blocks |
|------|----------------|
| `surgical-rm` | `rm -rf /`, `~`, `/home` (allows safe targets) |
| `force-push-protection` | Force push to protected branches |
| `chmod-777` | World-writable permissions |
| `remote-exec-protection` | `curl \| bash` patterns |
| `disk-ops-protection` | `dd of=/dev/*`, `mkfs` |
| `exfiltration-protection` | Network transfers of sensitive files |
| `env-exposure-protection` | Reading `.env` files (warns) |

---

## Installation Options

### Full Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/ntanner-ctrl/claude-bootstrap/master/install.sh | bash
```

### Components Only

```bash
# Clone and pick what you need
git clone https://github.com/ntanner-ctrl/claude-bootstrap.git
cd claude-bootstrap

# Shell hooks
cp hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh

# Hookify rules
cp hookify-rules/*.local.md ~/.claude/

# Commands
cp commands/*.md ~/.claude/commands/
```

### Configuration

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [
        { "type": "command", "command": "~/.claude/hooks/dangerous-commands.sh" },
        { "type": "command", "command": "~/.claude/hooks/secret-scanner.sh" }
      ]
    }]
  }
}
```

See `settings-example.json` for complete configuration.

---

## Creating Domain Kits

The [Ops Starter Kit](ops-starter-kit/) demonstrates how to create specialized extensions. Use it as a template:

```bash
cp -r ops-starter-kit my-domain-kit
```

Ideas: Frontend, Data Engineering, ML Ops, Security, Mobile, Game Dev

See [docs/CREATING-DOMAIN-KITS.md](docs/CREATING-DOMAIN-KITS.md) for the full guide.

---

## Project Philosophy

### Context is Everything

Claude Code is powerful, but without project context it's guessing at your conventions, architecture, and workflows. Bootstrap provides that context.

### Safety by Default

Every hook exists because someone made that mistake. The goal isn't to restrict Claude—it's to catch the 3 AM mistakes before they cause damage.

### Evolve, Don't Prescribe

Bootstrap adapts to project maturity:
- **Nascent** → Full starter kit
- **Growing** → Selective additions
- **Mature** → Suggestions only

---

## Documentation

| Document | Type | Purpose |
|----------|------|---------|
| [GETTING_STARTED.md](GETTING_STARTED.md) | Tutorial | Step-by-step first-time setup |
| [commands/README.md](commands/README.md) | Reference | All 14 commands documented |
| [docs/SECURITY.md](docs/SECURITY.md) | Explanation | Defense-in-depth architecture |
| [docs/CREATING-DOMAIN-KITS.md](docs/CREATING-DOMAIN-KITS.md) | How-to | Build your own domain kit |
| [ops-starter-kit/README.md](ops-starter-kit/README.md) | Reference | Ops-specific extensions |
| [hooks/HOOK-PATTERNS-RESEARCH.md](hooks/HOOK-PATTERNS-RESEARCH.md) | Explanation | Hook pattern research |

---

## Acknowledgments

Built with patterns and inspiration from:

- **[TheDecipherist/claude-code-mastery](https://github.com/TheDecipherist/claude-code-mastery)** - Shell hook patterns, exit code conventions, security research
- **[bmad-code-org/BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD)** - Agent orchestration patterns

---

## Contributing

Found a useful hook? Built a great agent? PRs welcome!

## License

MIT - Use it, modify it, share it.

---

*Built by [@flawlesscowboy0](https://reddit.com/u/flawlesscowboy0) after one too many 3 AM mistakes.*
