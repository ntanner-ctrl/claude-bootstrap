# Bootstrap Toolkit Installation

## Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/claude-bootstrap/main/install.sh | bash
```

Or if you prefer to inspect first:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/claude-bootstrap/main/install.sh -o install.sh
cat install.sh  # Review it
bash install.sh
```

## What Gets Installed

```
~/.claude/
├── commands/
│   ├── bootstrap-project.md     # Full project setup
│   ├── check-project-setup.md   # Light drift detection
│   └── templates/               # Stock element templates
│       ├── stock-hooks/
│       ├── stock-agents/
│       └── stock-commands/
└── plugins/local/
    └── bootstrap-toolkit/       # Session-start hook
```

## Manual Installation

1. Clone the repo:
   ```bash
   git clone https://github.com/YOUR_USER/claude-bootstrap.git
   cd claude-bootstrap
   ```

2. Run the installer:
   ```bash
   ./install.sh
   ```

## Usage

After installation, in any project:

```bash
# First time setup
/bootstrap-project

# Quick check anytime
/check-project-setup

# Update documentation only
/refresh-claude-md
```

## Uninstall

```bash
rm ~/.claude/commands/bootstrap-project.md
rm ~/.claude/commands/check-project-setup.md
rm -rf ~/.claude/commands/templates/
rm -rf ~/.claude/plugins/local/bootstrap-toolkit/
```
