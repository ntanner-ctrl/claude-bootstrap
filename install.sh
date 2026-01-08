#!/bin/bash
#
# Claude Code Bootstrap Toolkit Installer
# One command to install project bootstrapping for Claude Code
#
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLAUDE_HOME="${HOME}/.claude"
REPO_URL="${BOOTSTRAP_REPO_URL:-https://github.com/ntanner-ctrl/claude-bootstrap}"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Claude Code Bootstrap Toolkit Installer   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
    echo "Error: curl or wget required"
    exit 1
fi

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p "${CLAUDE_HOME}/commands/templates/stock-hooks"
mkdir -p "${CLAUDE_HOME}/commands/templates/stock-agents"
mkdir -p "${CLAUDE_HOME}/commands/templates/stock-commands"
mkdir -p "${CLAUDE_HOME}/plugins/local/bootstrap-toolkit/.claude-plugin"
mkdir -p "${CLAUDE_HOME}/plugins/local/bootstrap-toolkit/hooks"
mkdir -p "${CLAUDE_HOME}/plugins/local/bootstrap-toolkit/scripts"

# Download function
download() {
    local url="$1"
    local dest="$2"
    if command -v curl &> /dev/null; then
        curl -fsSL "$url" -o "$dest"
    else
        wget -q "$url" -O "$dest"
    fi
}

# If running from local install (files already present)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "${SCRIPT_DIR}/commands/bootstrap-project.md" ]; then
    echo -e "${YELLOW}Installing from local files...${NC}"

    # Commands
    cp "${SCRIPT_DIR}/commands/bootstrap-project.md" "${CLAUDE_HOME}/commands/"
    cp "${SCRIPT_DIR}/commands/check-project-setup.md" "${CLAUDE_HOME}/commands/"

    # Templates
    cp -r "${SCRIPT_DIR}/commands/templates/stock-hooks/"* "${CLAUDE_HOME}/commands/templates/stock-hooks/" 2>/dev/null || true
    cp -r "${SCRIPT_DIR}/commands/templates/stock-agents/"* "${CLAUDE_HOME}/commands/templates/stock-agents/" 2>/dev/null || true
    cp -r "${SCRIPT_DIR}/commands/templates/stock-commands/"* "${CLAUDE_HOME}/commands/templates/stock-commands/" 2>/dev/null || true

    # Plugin
    cp -r "${SCRIPT_DIR}/plugins/bootstrap-toolkit/"* "${CLAUDE_HOME}/plugins/local/bootstrap-toolkit/" 2>/dev/null || true

else
    echo -e "${YELLOW}Downloading from repository...${NC}"

    BASE_URL="${REPO_URL}/raw/master"

    # Commands
    echo "  → bootstrap-project.md"
    download "${BASE_URL}/commands/bootstrap-project.md" "${CLAUDE_HOME}/commands/bootstrap-project.md"

    echo "  → check-project-setup.md"
    download "${BASE_URL}/commands/check-project-setup.md" "${CLAUDE_HOME}/commands/check-project-setup.md"

    # Stock hooks
    echo "  → stock hooks"
    download "${BASE_URL}/commands/templates/stock-hooks/test-coverage-reminder.md" "${CLAUDE_HOME}/commands/templates/stock-hooks/test-coverage-reminder.md"
    download "${BASE_URL}/commands/templates/stock-hooks/security-warning.md" "${CLAUDE_HOME}/commands/templates/stock-hooks/security-warning.md"
    download "${BASE_URL}/commands/templates/stock-hooks/interface-validation.md" "${CLAUDE_HOME}/commands/templates/stock-hooks/interface-validation.md"

    # Stock agents
    echo "  → stock agents"
    download "${BASE_URL}/commands/templates/stock-agents/troubleshooter.md" "${CLAUDE_HOME}/commands/templates/stock-agents/troubleshooter.md"
    download "${BASE_URL}/commands/templates/stock-agents/code-reviewer.md" "${CLAUDE_HOME}/commands/templates/stock-agents/code-reviewer.md"
    download "${BASE_URL}/commands/templates/stock-agents/architecture-explainer.md" "${CLAUDE_HOME}/commands/templates/stock-agents/architecture-explainer.md"

    # Stock commands
    echo "  → stock commands"
    download "${BASE_URL}/commands/templates/stock-commands/test-all.md" "${CLAUDE_HOME}/commands/templates/stock-commands/test-all.md"
    download "${BASE_URL}/commands/templates/stock-commands/health-check.md" "${CLAUDE_HOME}/commands/templates/stock-commands/health-check.md"
    download "${BASE_URL}/commands/templates/stock-commands/scaffold.md" "${CLAUDE_HOME}/commands/templates/stock-commands/scaffold.md"

    # Plugin
    echo "  → session-start plugin"
    download "${BASE_URL}/plugins/bootstrap-toolkit/.claude-plugin/plugin.json" "${CLAUDE_HOME}/plugins/local/bootstrap-toolkit/.claude-plugin/plugin.json"
    download "${BASE_URL}/plugins/bootstrap-toolkit/hooks/hooks.json" "${CLAUDE_HOME}/plugins/local/bootstrap-toolkit/hooks/hooks.json"
    download "${BASE_URL}/plugins/bootstrap-toolkit/scripts/check-setup-quiet.sh" "${CLAUDE_HOME}/plugins/local/bootstrap-toolkit/scripts/check-setup-quiet.sh"
fi

# Make scripts executable
chmod +x "${CLAUDE_HOME}/plugins/local/bootstrap-toolkit/scripts/"*.sh 2>/dev/null || true

echo ""
echo -e "${GREEN}✓ Installation complete!${NC}"
echo ""
echo "Available commands:"
echo "  /bootstrap-project     - Full project setup"
echo "  /check-project-setup   - Quick drift detection"
echo ""
echo "Try it now in any project:"
echo "  cd /path/to/your/project"
echo "  claude"
echo "  /bootstrap-project"
echo ""
