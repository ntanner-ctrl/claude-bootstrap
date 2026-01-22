#!/bin/bash
#
# Claude Code Bootstrap Toolkit Installer
# One command to install project bootstrapping for Claude Code
#
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
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
mkdir -p "${CLAUDE_HOME}/hooks"
mkdir -p "${CLAUDE_HOME}/agents"

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
# Handle both direct execution and piped execution (curl | bash)
# When piped, BASH_SOURCE is empty, so fall back to empty string (triggers remote install)
SCRIPT_DIR=""
if [[ ${#BASH_SOURCE[@]} -gt 0 && -n "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -f "${SCRIPT_DIR}/commands/bootstrap-project.md" ]; then
    echo -e "${YELLOW}Installing from local files...${NC}"

    # Commands (copy all .md files except README)
    echo "  → commands ($(ls "${SCRIPT_DIR}/commands/"*.md 2>/dev/null | grep -v README.md | wc -l) files)"
    for cmd in "${SCRIPT_DIR}/commands/"*.md; do
        [ -f "$cmd" ] && [[ "$(basename "$cmd")" != "README.md" ]] && cp "$cmd" "${CLAUDE_HOME}/commands/"
    done

    # Templates
    echo "  → templates"
    cp -r "${SCRIPT_DIR}/commands/templates/stock-hooks/"* "${CLAUDE_HOME}/commands/templates/stock-hooks/" 2>/dev/null || true
    cp -r "${SCRIPT_DIR}/commands/templates/stock-agents/"* "${CLAUDE_HOME}/commands/templates/stock-agents/" 2>/dev/null || true
    cp -r "${SCRIPT_DIR}/commands/templates/stock-commands/"* "${CLAUDE_HOME}/commands/templates/stock-commands/" 2>/dev/null || true
    # Documentation templates
    if [ -d "${SCRIPT_DIR}/commands/templates/documentation" ]; then
        mkdir -p "${CLAUDE_HOME}/commands/templates/documentation"
        cp -r "${SCRIPT_DIR}/commands/templates/documentation/"* "${CLAUDE_HOME}/commands/templates/documentation/" 2>/dev/null || true
    fi

    # Plugin
    cp -r "${SCRIPT_DIR}/plugins/bootstrap-toolkit/"* "${CLAUDE_HOME}/plugins/local/bootstrap-toolkit/" 2>/dev/null || true

    # Shell hooks
    if [ -d "${SCRIPT_DIR}/hooks" ]; then
        echo "  → shell hooks"
        cp "${SCRIPT_DIR}/hooks/"*.sh "${CLAUDE_HOME}/hooks/" 2>/dev/null || true
        cp "${SCRIPT_DIR}/hooks/HOOK-PATTERNS-RESEARCH.md" "${CLAUDE_HOME}/hooks/" 2>/dev/null || true
    fi

    # Agents
    if [ -d "${SCRIPT_DIR}/agents" ]; then
        echo "  → agents ($(ls "${SCRIPT_DIR}/agents/"*.md 2>/dev/null | wc -l) files)"
        mkdir -p "${CLAUDE_HOME}/agents"
        cp "${SCRIPT_DIR}/agents/"*.md "${CLAUDE_HOME}/agents/" 2>/dev/null || true
    fi

    # Hookify rules
    if [ -d "${SCRIPT_DIR}/hookify-rules" ]; then
        echo "  → hookify rules"
        cp "${SCRIPT_DIR}/hookify-rules/"*.local.md "${CLAUDE_HOME}/" 2>/dev/null || true
    fi

else
    echo -e "${YELLOW}Downloading from repository...${NC}"

    # Download and extract repository tarball (self-maintaining - no file list to update)
    TEMP_DIR=$(mktemp -d)
    TARBALL_URL="https://github.com/ntanner-ctrl/claude-bootstrap/archive/refs/heads/main.tar.gz"

    echo "  → downloading repository..."
    if command -v curl &> /dev/null; then
        curl -fsSL "$TARBALL_URL" | tar xz -C "$TEMP_DIR"
    else
        wget -qO- "$TARBALL_URL" | tar xz -C "$TEMP_DIR"
    fi

    REPO_DIR="${TEMP_DIR}/claude-bootstrap-main"

    if [ ! -d "$REPO_DIR" ]; then
        echo -e "${RED}Error: Failed to download repository${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Commands (copy all .md files except README)
    CMD_COUNT=$(ls "${REPO_DIR}/commands/"*.md 2>/dev/null | grep -v README.md | wc -l)
    echo "  → commands (${CMD_COUNT} files)"
    for cmd in "${REPO_DIR}/commands/"*.md; do
        [ -f "$cmd" ] && [[ "$(basename "$cmd")" != "README.md" ]] && cp "$cmd" "${CLAUDE_HOME}/commands/"
    done

    # Templates
    echo "  → templates"
    cp -r "${REPO_DIR}/commands/templates/stock-hooks/"* "${CLAUDE_HOME}/commands/templates/stock-hooks/" 2>/dev/null || true
    cp -r "${REPO_DIR}/commands/templates/stock-agents/"* "${CLAUDE_HOME}/commands/templates/stock-agents/" 2>/dev/null || true
    cp -r "${REPO_DIR}/commands/templates/stock-commands/"* "${CLAUDE_HOME}/commands/templates/stock-commands/" 2>/dev/null || true
    # Documentation templates
    if [ -d "${REPO_DIR}/commands/templates/documentation" ]; then
        mkdir -p "${CLAUDE_HOME}/commands/templates/documentation"
        cp -r "${REPO_DIR}/commands/templates/documentation/"* "${CLAUDE_HOME}/commands/templates/documentation/" 2>/dev/null || true
    fi

    # Plugin
    echo "  → session-start plugin"
    cp -r "${REPO_DIR}/plugins/bootstrap-toolkit/"* "${CLAUDE_HOME}/plugins/local/bootstrap-toolkit/" 2>/dev/null || true

    # Shell hooks
    if [ -d "${REPO_DIR}/hooks" ]; then
        echo "  → shell hooks"
        cp "${REPO_DIR}/hooks/"*.sh "${CLAUDE_HOME}/hooks/" 2>/dev/null || true
        cp "${REPO_DIR}/hooks/HOOK-PATTERNS-RESEARCH.md" "${CLAUDE_HOME}/hooks/" 2>/dev/null || true
    fi

    # Agents
    if [ -d "${REPO_DIR}/agents" ]; then
        echo "  → agents ($(ls "${REPO_DIR}/agents/"*.md 2>/dev/null | wc -l) files)"
        mkdir -p "${CLAUDE_HOME}/agents"
        cp "${REPO_DIR}/agents/"*.md "${CLAUDE_HOME}/agents/" 2>/dev/null || true
    fi

    # Hookify rules
    if [ -d "${REPO_DIR}/hookify-rules" ]; then
        echo "  → hookify rules"
        cp "${REPO_DIR}/hookify-rules/"*.local.md "${CLAUDE_HOME}/" 2>/dev/null || true
    fi

    # Cleanup
    rm -rf "$TEMP_DIR"
fi

# Make scripts executable
chmod +x "${CLAUDE_HOME}/plugins/local/bootstrap-toolkit/scripts/"*.sh 2>/dev/null || true
chmod +x "${CLAUDE_HOME}/hooks/"*.sh 2>/dev/null || true

echo ""
echo -e "${GREEN}✓ Installation complete!${NC}"
echo ""
echo "Core commands:"
echo "  /toolkit               - Quick reference for ALL commands"
echo "  /start                 - Assess state, recommend next task"
echo "  /bootstrap-project     - Full project setup"
echo ""
echo "Planning workflow:"
echo "  /plan [name]           - Full planning workflow"
echo "  /describe-change       - Triage change complexity"
echo "  /spec-change           - Complete change specification"
echo ""
echo "Adversarial review:"
echo "  /devils-advocate       - Challenge assumptions"
echo "  /gpt-review            - External model review"
echo ""
echo "Run /toolkit for the complete command reference."
echo ""
echo -e "${YELLOW}Shell hooks installed:${NC}"
echo "  ~/.claude/hooks/session-bootstrap.sh  - Session awareness injection"
echo "  ~/.claude/hooks/notify.sh             - Desktop notifications"
echo "  ~/.claude/hooks/after-edit.sh         - Auto-format after edits"
echo "  ~/.claude/hooks/dangerous-commands.sh - Block dangerous commands"
echo "  ~/.claude/hooks/secret-scanner.sh     - Scan for secrets before commits"
echo "  ~/.claude/hooks/protect-claude-md.sh  - Protect CLAUDE.md from edits"
echo ""
echo -e "${YELLOW}Agents installed:${NC}"
echo "  ~/.claude/agents/spec-reviewer.md     - Spec compliance verification"
echo "  ~/.claude/agents/quality-reviewer.md  - Code quality review"
echo ""
echo -e "${YELLOW}To activate shell hooks, add to ~/.claude/settings.json:${NC}"
echo '  "hooks": { ... }'
echo "  (See settings-example.json in repo for full config)"
echo ""
echo -e "${YELLOW}Hookify rules installed:${NC}"
echo "  surgical-rm, force-push-protection, chmod-777,"
echo "  remote-exec-protection, disk-ops-protection,"
echo "  exfiltration-protection, env-exposure-protection"
echo ""
echo "Try it now in any project:"
echo "  cd /path/to/your/project"
echo "  claude"
echo "  /bootstrap-project"
echo ""
