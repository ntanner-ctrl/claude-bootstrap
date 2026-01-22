# Claude Code Bootstrap Toolkit

> Extensibility tools for Claude Code - the CLI-based AI coding assistant.

Give Claude Code the context it needs: **CLAUDE.md documentation**, **safety hooks**, **planning infrastructure**, and **workflow commands**.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/ntanner-ctrl/claude-bootstrap/main/install.sh | bash
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
| [**Commands**](commands/README.md) | 35 workflow commands for planning, adversarial review, testing, security |
| [**Agents**](agents/) | Specialized review agents (spec compliance, code quality) |
| [**Planning Infrastructure**](docs/PLANNING-STORAGE.md) | Staged planning with triage, specs, and adversarial challenge |
| [**Shell Hooks**](hooks/) | Safety guards, session bootstrap, CLAUDE.md protection |
| [**Hookify Rules**](hookify-rules/) | 7 YAML-based security rules |
| [**Ops Starter Kit**](ops-starter-kit/) | Domain-specific extensions for infrastructure work |

### Commands at a Glance

| Category | Commands |
|----------|----------|
| **Start Here** | `/start`, `/describe-change`, `/toolkit` |
| **Workflow Wizards** | `/plan`, `/review`, `/test` |
| **Planning** | `/spec-change`, `/spec-agent`, `/spec-hook`, `/preflight`, `/decision` |
| **Adversarial** | `/devils-advocate`, `/simplify-this`, `/edge-cases`, `/gpt-review` |
| **Quality** | `/tdd`, `/quality-gate`, `/spec-to-tests`, `/security-checklist` |
| **Execution** | `/dispatch`, `/delegate` |
| **Status** | `/status`, `/plans`, `/overrides`, `/approve` |
| **Setup** | `/bootstrap-project`, `/check-project-setup`, `/setup-hooks` |
| **Docs** | `/refresh-claude-md`, `/migrate-docs`, `/process-doc` |

See [commands/README.md](commands/README.md) for full reference.

---

## Planning Infrastructure

The toolkit includes comprehensive planning infrastructure to catch the "unearned confidence" problem—moving faster than your understanding of consequences.

### The Triage Gateway

Every change starts with `/describe-change`, which determines planning depth:

| Steps | Risk Flags | Path |
|-------|------------|------|
| 1-3   | None       | **Light** — `/preflight`, then execute |
| 1-3   | Any        | **Standard** — `/spec-change` required |
| 4-7   | Any        | **Full** — Complete planning protocol |

### The `/plan` Wizard

Guided workflow through all stages:

```
/plan feature-auth

Stage 1: Describe    → Triage the change
Stage 2: Specify     → Full specification
Stage 3: Challenge   → Devil's advocate review
Stage 4: Edge Cases  → Boundary probing
Stage 5: Review      → External perspective (optional)
Stage 6: Test        → Spec-blind test generation
Stage 7: Execute     → Implementation
```

### Adversarial Pipeline

Local-first challenge, then external validation:

```
┌─────────────────────────────────────────────────────────────┐
│                    LOCAL ADVERSARIAL LAYER                  │
│  /devils-advocate  →  /simplify-this  →  /edge-cases       │
└─────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                   EXTERNAL REVIEW LAYER                     │
│                      /gpt-review                            │
│   Receives local findings, finds blind spots               │
└─────────────────────────────────────────────────────────────┘
```

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
| `session-bootstrap.sh` | **Inject command awareness at session start** |
| `protect-claude-md.sh` | Block accidental CLAUDE.md modifications |
| `tdd-guardian.sh` | Block implementation edits during TDD RED phase |
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
curl -fsSL https://raw.githubusercontent.com/ntanner-ctrl/claude-bootstrap/main/install.sh | bash
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

### Plan Before You Build

Speed without understanding leads to confident mistakes. The planning infrastructure forces understanding to catch up with speed before execution proceeds.

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
| [commands/README.md](commands/README.md) | Reference | All 35 commands documented |
| [docs/SECURITY.md](docs/SECURITY.md) | Explanation | Defense-in-depth architecture |
| [docs/ENFORCEMENT-PATTERNS.md](docs/ENFORCEMENT-PATTERNS.md) | Reference | Command description enforcement tiers |
| [docs/PLANNING-STORAGE.md](docs/PLANNING-STORAGE.md) | Reference | Planning state and storage schemas |
| [docs/CREATING-DOMAIN-KITS.md](docs/CREATING-DOMAIN-KITS.md) | How-to | Build your own domain kit |
| [ops-starter-kit/README.md](ops-starter-kit/README.md) | Reference | Ops-specific extensions |

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
