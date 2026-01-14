#!/bin/bash
#
# Ops Starter Kit Installer for Claude Code
# One command to set up ops-focused Claude Code extensions
#
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

CLAUDE_HOME="${HOME}/.claude"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Ops Starter Kit for Claude Code            ║${NC}"
echo -e "${BLUE}║     Infrastructure & Operations Extensions     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Get script directory (works even if script is sourced)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if running from the kit directory
if [ ! -f "${SCRIPT_DIR}/hooks/production-safety.md" ]; then
    echo -e "${RED}Error: Cannot find kit files.${NC}"
    echo "Please run this script from the ops-starter-kit directory."
    exit 1
fi

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p "${CLAUDE_HOME}/commands"
mkdir -p "${CLAUDE_HOME}/agents"

# Install hooks
echo -e "${YELLOW}Installing hooks...${NC}"
for hook in "${SCRIPT_DIR}"/hooks/*.md; do
    if [ -f "$hook" ]; then
        name=$(basename "$hook")
        # Check if this is a project-level install or global install
        if [ -d ".claude" ]; then
            mkdir -p ".claude/hooks"
            cp "$hook" ".claude/hooks/"
            echo "  → $name (project)"
        else
            mkdir -p "${CLAUDE_HOME}/hooks"
            cp "$hook" "${CLAUDE_HOME}/hooks/"
            echo "  → $name (global)"
        fi
    fi
done

# Install agents
echo -e "${YELLOW}Installing agents...${NC}"
for agent in "${SCRIPT_DIR}"/agents/*.md; do
    if [ -f "$agent" ]; then
        name=$(basename "$agent")
        cp "$agent" "${CLAUDE_HOME}/agents/"
        echo "  → $name"
    fi
done

# Install commands
echo -e "${YELLOW}Installing commands...${NC}"
for cmd in "${SCRIPT_DIR}"/commands/*.md; do
    if [ -f "$cmd" ]; then
        name=$(basename "$cmd")
        cp "$cmd" "${CLAUDE_HOME}/commands/"
        echo "  → $name"
    fi
done

# Install template
echo -e "${YELLOW}Installing templates...${NC}"
mkdir -p "${CLAUDE_HOME}/templates"
if [ -f "${SCRIPT_DIR}/templates/CLAUDE.md.ops-template" ]; then
    cp "${SCRIPT_DIR}/templates/CLAUDE.md.ops-template" "${CLAUDE_HOME}/templates/"
    echo "  → CLAUDE.md.ops-template"
fi

# Offer to create project CLAUDE.md
echo ""
if [ -d ".git" ] && [ ! -f "CLAUDE.md" ]; then
    echo -e "${YELLOW}This looks like a git repository without a CLAUDE.md.${NC}"
    read -p "Would you like to create one from the ops template? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp "${SCRIPT_DIR}/templates/CLAUDE.md.ops-template" "./CLAUDE.md"
        echo -e "${GREEN}Created CLAUDE.md - please customize it for your project.${NC}"
    fi
fi

echo ""
echo -e "${GREEN}✓ Installation complete!${NC}"
echo ""
echo -e "${BLUE}What's installed:${NC}"
echo ""
echo "  Hooks (safety guards):"
echo "    • production-safety - Warns before editing prod files"
echo "    • secrets-detector  - Catches hardcoded secrets"
echo "    • shell-safety      - Blocks dangerous shell commands"
echo "    • iac-validator     - Validates infrastructure code"
echo ""
echo "  Commands (slash commands):"
echo "    • /deploy-check     - Pre-deployment validation"
echo "    • /incident-report  - Generate postmortems"
echo "    • /runbook          - Create operational runbooks"
echo ""
echo "  Agents (subagents for complex tasks):"
echo "    • incident-responder - Systematic incident handling"
echo "    • infra-analyzer     - Review infrastructure code"
echo "    • runbook-generator  - Create detailed runbooks"
echo ""
echo -e "${YELLOW}Quick start:${NC}"
echo "  cd /your/ops/project"
echo "  claude"
echo "  /deploy-check production"
echo ""
