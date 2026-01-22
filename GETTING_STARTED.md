# Getting Started with Claude Bootstrap

A complete guide to finding, installing, and using the Claude Code Bootstrap Toolkit.

---

## Table of Contents

1. [What Is This?](#what-is-this)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Your First Bootstrap](#your-first-bootstrap)
5. [Understanding the Output](#understanding-the-output)
6. [Daily Usage](#daily-usage)
7. [Customizing Stock Elements](#customizing-stock-elements)
8. [Troubleshooting](#troubleshooting)

---

## What Is This?

The Claude Bootstrap Toolkit automatically sets up Claude Code extensibility for any project. Instead of manually creating hooks, agents, and documentation, Bootstrap analyzes your project and installs appropriate tooling based on:

- **Project type** (Python, Node, Rust, Docker, etc.)
- **Project maturity** (new project vs. established codebase)
- **Existing setup** (preserves what you already have)

### What You Get

| Component | Purpose |
|-----------|---------|
| **CLAUDE.md** | Project documentation that Claude reads on every session |
| **Hooks** | Automated reminders (test coverage, security warnings) |
| **Agents** | Specialized assistants (troubleshooter, code reviewer) |
| **Commands** | Project-specific shortcuts |

---

## Prerequisites

Before installing, ensure you have:

1. **Claude Code CLI** installed and working
   ```bash
   claude --version
   ```
   If not installed, visit: https://docs.anthropic.com/claude-code

2. **curl** or **wget** available (most systems have these)
   ```bash
   curl --version
   # or
   wget --version
   ```

3. **A terminal** (macOS Terminal, Linux shell, Windows WSL, or Git Bash)

---

## Installation

### Option A: One-Line Install (Recommended)

Open your terminal and run:

```bash
curl -fsSL https://raw.githubusercontent.com/ntanner-ctrl/claude-bootstrap/main/install.sh | bash
```

You'll see output like:
```
╔════════════════════════════════════════════╗
║  Claude Code Bootstrap Toolkit Installer   ║
╚════════════════════════════════════════════╝

Creating directories...
Downloading from repository...
  → bootstrap-project.md
  → check-project-setup.md
  → stock hooks
  → stock agents
  → stock commands
  → session-start plugin

✓ Installation complete!

Available commands:
  /bootstrap-project     - Full project setup
  /check-project-setup   - Quick drift detection
```

### Option B: Inspect Before Installing

If you prefer to review the script first:

```bash
# Download the installer
curl -fsSL https://raw.githubusercontent.com/ntanner-ctrl/claude-bootstrap/main/install.sh -o install.sh

# Review it
cat install.sh

# Run it
bash install.sh
```

### Option C: Clone and Install Locally

```bash
# Clone the repository
git clone https://github.com/ntanner-ctrl/claude-bootstrap.git

# Enter the directory
cd claude-bootstrap

# Run the installer
./install.sh
```

### Verify Installation

Check that the files were installed:

```bash
ls ~/.claude/commands/bootstrap-project.md
ls ~/.claude/commands/check-project-setup.md
ls ~/.claude/commands/templates/
```

---

## Your First Bootstrap

### Step 1: Navigate to Your Project

```bash
cd /path/to/your/project
```

### Step 2: Start Claude Code

```bash
claude
```

### Step 3: Run Bootstrap

In the Claude Code session, type:

```
/bootstrap-project
```

### Step 4: Watch the Magic

Bootstrap will analyze your project through six phases:

```
Phase 1: Project Analysis
├── Scanning structure...
├── Detecting languages: Python, JavaScript
├── Assessing maturity: Growing (score: 6/10)
└── Found existing .claude/ directory

Phase 2: CLAUDE.md Generation
├── Analyzing conventions...
├── Documenting workflows...
└── Generated comprehensive CLAUDE.md

Phase 3: Stock Element Selection
├── Selected: test-coverage-reminder (Python + JS)
├── Selected: security-warning (universal)
├── Selected: troubleshooter (adapted for stack)
└── Skipped: scaffold (established patterns exist)

Phase 4: Installation
├── Installing hooks...
├── Installing agents...
└── Creating manifest...

Phase 5: Manifest Creation
└── Wrote .claude/bootstrap-manifest.json

Phase 6: Recommendations
└── Consider adding: health-check command
```

---

## Understanding the Output

After bootstrapping, your project will have a `.claude/` directory:

```
your-project/
├── .claude/
│   ├── CLAUDE.md                    # Project documentation
│   ├── bootstrap-manifest.json      # Tracks what was installed
│   ├── hooks/
│   │   ├── test-coverage-reminder.md
│   │   └── security-warning.md
│   └── agents/
│       ├── troubleshooter.md
│       └── code-reviewer.md
├── src/
└── ... your project files
```

### The Manifest

The `bootstrap-manifest.json` tracks everything Bootstrap installed:

```json
{
  "version": "1.0.0",
  "bootstrapped_at": "2026-01-08T12:00:00Z",
  "project_type": ["python", "javascript"],
  "maturity_level": "growing",
  "stock_elements": {
    "hooks/test-coverage-reminder.md": {
      "source_version": "1.0.0",
      "installed_hash": "abc123...",
      "customized": false
    }
  }
}
```

This manifest enables:
- **Safe re-runs**: Bootstrap won't overwrite your customizations
- **Drift detection**: `/check-project-setup` knows what should exist
- **Upgrade tracking**: Future versions can update stock elements safely

---

## Daily Usage

### Session Start Check

Every time you start Claude Code in a bootstrapped project, you'll see a quick status:

```
✓ Project setup OK
  - CLAUDE.md: current
  - Hooks: 2 active
  - Agents: 2 available
```

Or if something needs attention:

```
⚠ Project setup drift detected
  - New directory: api/ (not documented)
  - CLAUDE.md may be stale

Run /check-project-setup for details or /bootstrap-project to update.
```

### Available Commands

| Command | When to Use |
|---------|-------------|
| `/bootstrap-project` | First setup, or major project changes |
| `/check-project-setup` | Quick health check anytime |

### Using Installed Agents

After bootstrapping, you can use the installed agents via Claude's Task tool:

```
"Can you troubleshoot why my tests are failing?"
→ Claude uses the troubleshooter agent

"Review the code I just wrote"
→ Claude uses the code-reviewer agent
```

### Using Installed Hooks

Hooks run automatically. For example, after editing a source file:

```
You edited: src/utils/parser.py

💡 Test Coverage Reminder
   Corresponding test file: tests/utils/test_parser.py
   Consider updating tests if you changed behavior.
```

---

## Customizing Stock Elements

Stock elements are **copied to your project** and can be freely edited.

### Example: Customizing a Hook

1. Open the hook file:
   ```bash
   code .claude/hooks/test-coverage-reminder.md
   ```

2. Edit the pattern or message:
   ```markdown
   ---
   hooks:
     - event: PostToolUse
       tools: [Write, Edit]
       pattern: "lib/**/*.py"  # Changed from src/**
   ---
   ```

3. The manifest tracks your customization:
   ```json
   "hooks/test-coverage-reminder.md": {
     "customized": true,
     "customization_note": "Changed pattern to lib/**"
   }
   ```

4. Future `/bootstrap-project` runs will **preserve** your changes.

### Creating Project-Specific Elements

You can add your own hooks, agents, or commands alongside stock ones:

```
.claude/
├── hooks/
│   ├── test-coverage-reminder.md  # Stock (customized)
│   ├── security-warning.md        # Stock
│   └── my-custom-hook.md          # Your own!
└── agents/
    ├── troubleshooter.md          # Stock
    └── domain-expert.md           # Your own!
```

---

## Troubleshooting

### "Command not found: /bootstrap-project"

The commands weren't installed correctly. Re-run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/ntanner-ctrl/claude-bootstrap/main/install.sh | bash
```

### "Permission denied" during install

The installer needs write access to `~/.claude/`. Try:

```bash
mkdir -p ~/.claude/commands
chmod 755 ~/.claude ~/.claude/commands
# Then re-run the installer
```

### Bootstrap runs but nothing happens

Check if you're in a valid project directory:

```bash
pwd          # Should show your project path
ls -la       # Should show project files
```

Bootstrap needs to be run from within a project, not from an empty directory.

### Stock elements not appearing

Verify the templates were installed:

```bash
ls ~/.claude/commands/templates/stock-hooks/
ls ~/.claude/commands/templates/stock-agents/
```

If empty, re-run the installer.

### Session start check not working

The plugin may not be registered. Check:

```bash
ls ~/.claude/plugins/local/bootstrap-toolkit/
```

Should contain:
- `.claude-plugin/plugin.json`
- `hooks/hooks.json`
- `scripts/check-setup-quiet.sh`

### Hooks not triggering

Ensure the hook pattern matches your files. Check the hook's `pattern` field:

```yaml
hooks:
  - event: PostToolUse
    tools: [Write, Edit]
    pattern: "src/**/*.py"  # Must match your file paths
```

---

## Uninstalling

To remove the Bootstrap Toolkit:

```bash
# Remove commands
rm ~/.claude/commands/bootstrap-project.md
rm ~/.claude/commands/check-project-setup.md

# Remove templates
rm -rf ~/.claude/commands/templates/

# Remove plugin
rm -rf ~/.claude/plugins/local/bootstrap-toolkit/
```

Project-level `.claude/` directories are **not removed** - those belong to each project.

---

## Getting Help

- **GitHub Issues**: https://github.com/ntanner-ctrl/claude-bootstrap/issues
- **Claude Code Docs**: https://docs.anthropic.com/claude-code

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────┐
│                 CLAUDE BOOTSTRAP                        │
├─────────────────────────────────────────────────────────┤
│ INSTALL                                                 │
│   curl -fsSL https://raw.githubusercontent.com/         │
│   ntanner-ctrl/claude-bootstrap/main/install.sh|bash   │
├─────────────────────────────────────────────────────────┤
│ COMMANDS                                                │
│   /bootstrap-project    Full setup / update             │
│   /check-project-setup  Quick health check              │
├─────────────────────────────────────────────────────────┤
│ FILES CREATED                                           │
│   .claude/CLAUDE.md           Project docs              │
│   .claude/hooks/*.md          Automated reminders       │
│   .claude/agents/*.md         Specialized assistants    │
│   .claude/bootstrap-manifest  Tracking file             │
├─────────────────────────────────────────────────────────┤
│ MATURITY LEVELS                                         │
│   Nascent  (<4)   Full starter kit installed            │
│   Growing  (4-7)  Selective additions                   │
│   Mature   (>7)   Suggestions only                      │
└─────────────────────────────────────────────────────────┘
```
