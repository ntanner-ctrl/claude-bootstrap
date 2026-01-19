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

    # Commands
    echo "  → commands"
    cp "${SCRIPT_DIR}/commands/bootstrap-project.md" "${CLAUDE_HOME}/commands/"
    cp "${SCRIPT_DIR}/commands/check-project-setup.md" "${CLAUDE_HOME}/commands/"
    cp "${SCRIPT_DIR}/commands/security-checklist.md" "${CLAUDE_HOME}/commands/" 2>/dev/null || true

    # Templates
    cp -r "${SCRIPT_DIR}/commands/templates/stock-hooks/"* "${CLAUDE_HOME}/commands/templates/stock-hooks/" 2>/dev/null || true
    cp -r "${SCRIPT_DIR}/commands/templates/stock-agents/"* "${CLAUDE_HOME}/commands/templates/stock-agents/" 2>/dev/null || true
    cp -r "${SCRIPT_DIR}/commands/templates/stock-commands/"* "${CLAUDE_HOME}/commands/templates/stock-commands/" 2>/dev/null || true

    # Plugin
    cp -r "${SCRIPT_DIR}/plugins/bootstrap-toolkit/"* "${CLAUDE_HOME}/plugins/local/bootstrap-toolkit/" 2>/dev/null || true

    # Shell hooks
    if [ -d "${SCRIPT_DIR}/hooks" ]; then
        echo "  → shell hooks"
        cp "${SCRIPT_DIR}/hooks/"*.sh "${CLAUDE_HOME}/hooks/" 2>/dev/null || true
        cp "${SCRIPT_DIR}/hooks/HOOK-PATTERNS-RESEARCH.md" "${CLAUDE_HOME}/hooks/" 2>/dev/null || true
    fi

    # Hookify rules
    if [ -d "${SCRIPT_DIR}/hookify-rules" ]; then
        echo "  → hookify rules"
        cp "${SCRIPT_DIR}/hookify-rules/"*.local.md "${CLAUDE_HOME}/" 2>/dev/null || true
    fi

else
    echo -e "${YELLOW}Downloading from repository...${NC}"

    # Use raw.githubusercontent.com for reliable raw file access
    # github.com/.../raw/... can return 404 in some cases
    BASE_URL="https://raw.githubusercontent.com/ntanner-ctrl/claude-bootstrap/master"

    # Commands
    echo "  → bootstrap-project.md"
    download "${BASE_URL}/commands/bootstrap-project.md" "${CLAUDE_HOME}/commands/bootstrap-project.md"

    echo "  → check-project-setup.md"
    download "${BASE_URL}/commands/check-project-setup.md" "${CLAUDE_HOME}/commands/check-project-setup.md"

    echo "  → security-checklist.md"
    download "${BASE_URL}/commands/security-checklist.md" "${CLAUDE_HOME}/commands/security-checklist.md" || true

    # Stock hooks (prompt-based, for bootstrap)
    echo "  → stock hooks (templates)"
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

    # Shell hooks (deterministic security)
    echo "  → shell hooks (security)"
    download "${BASE_URL}/hooks/notify.sh" "${CLAUDE_HOME}/hooks/notify.sh" || true
    download "${BASE_URL}/hooks/after-edit.sh" "${CLAUDE_HOME}/hooks/after-edit.sh" || true
    download "${BASE_URL}/hooks/dangerous-commands.sh" "${CLAUDE_HOME}/hooks/dangerous-commands.sh" || true
    download "${BASE_URL}/hooks/secret-scanner.sh" "${CLAUDE_HOME}/hooks/secret-scanner.sh" || true
    download "${BASE_URL}/hooks/HOOK-PATTERNS-RESEARCH.md" "${CLAUDE_HOME}/hooks/HOOK-PATTERNS-RESEARCH.md" || true

    # Hookify rules
    echo "  → hookify rules"
    download "${BASE_URL}/hookify-rules/hookify.surgical-rm.local.md" "${CLAUDE_HOME}/hookify.surgical-rm.local.md" || true
    download "${BASE_URL}/hookify-rules/hookify.force-push-protection.local.md" "${CLAUDE_HOME}/hookify.force-push-protection.local.md" || true
    download "${BASE_URL}/hookify-rules/hookify.chmod-777.local.md" "${CLAUDE_HOME}/hookify.chmod-777.local.md" || true
    download "${BASE_URL}/hookify-rules/hookify.remote-exec-protection.local.md" "${CLAUDE_HOME}/hookify.remote-exec-protection.local.md" || true
    download "${BASE_URL}/hookify-rules/hookify.disk-ops-protection.local.md" "${CLAUDE_HOME}/hookify.disk-ops-protection.local.md" || true
    download "${BASE_URL}/hookify-rules/hookify.exfiltration-protection.local.md" "${CLAUDE_HOME}/hookify.exfiltration-protection.local.md" || true
    download "${BASE_URL}/hookify-rules/hookify.env-exposure-protection.local.md" "${CLAUDE_HOME}/hookify.env-exposure-protection.local.md" || true
fi

# Make scripts executable
chmod +x "${CLAUDE_HOME}/plugins/local/bootstrap-toolkit/scripts/"*.sh 2>/dev/null || true
chmod +x "${CLAUDE_HOME}/hooks/"*.sh 2>/dev/null || true

echo ""
echo -e "${GREEN}✓ Installation complete!${NC}"
echo ""
echo "Available commands:"
echo "  /bootstrap-project     - Full project setup"
echo "  /check-project-setup   - Quick drift detection"
echo "  /security-checklist    - 8-point security audit"
echo ""
echo -e "${YELLOW}Shell hooks installed:${NC}"
echo "  ~/.claude/hooks/notify.sh           - Desktop notifications"
echo "  ~/.claude/hooks/after-edit.sh       - Auto-format after edits"
echo "  ~/.claude/hooks/dangerous-commands.sh - Block dangerous commands"
echo "  ~/.claude/hooks/secret-scanner.sh   - Scan for secrets before commits"
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
