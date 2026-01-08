# Claude Code Bootstrap Toolkit

Automatically set up Claude Code extensibility for any project with appropriate hooks, agents, commands, and CLAUDE.md documentation.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/ntanner-ctrl/claude-bootstrap/main/install.sh | bash
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

## Stock Elements

### Hooks
- **test-coverage-reminder** - Reminds about tests when editing source files
- **security-warning** - Warns when editing sensitive files
- **interface-validation** - Template for project-specific pattern validation

### Agents
- **troubleshooter** - Systematic issue diagnosis
- **code-reviewer** - Code review with confidence scoring
- **architecture-explainer** - Explains how code works

### Commands (installed selectively)
- **test-all** - Run all tests with auto-detection
- **health-check** - Validate project configuration
- **scaffold** - Generate new modules

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

## License

MIT
