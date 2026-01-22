---
description: Use when a project needs auto-formatting hooks. Detects tech stack and configures PostToolUse formatting automatically.
---

# Setup Project Formatting Hooks

Scan project to detect tech stack and configure appropriate PostToolUse formatting hooks.

## Instructions

### Step 1: Detect Tech Stack

Scan for configuration files to identify languages and formatters:

| File | Language | Recommended Formatter |
|------|----------|----------------------|
| `package.json` | JavaScript/TypeScript | prettier, eslint --fix |
| `pyproject.toml`, `setup.py` | Python | black, ruff format |
| `Cargo.toml` | Rust | rustfmt |
| `go.mod` | Go | gofmt |
| `composer.json` | PHP | php-cs-fixer |
| `.prettierrc*` | Already has Prettier | prettier |
| `biome.json` | Already has Biome | biome format |
| `ruff.toml`, `.ruff.toml` | Already has Ruff | ruff format |

### Step 2: Check Installed Tools

Verify which formatters are actually available:
```bash
which prettier || npm list prettier 2>/dev/null
which black || pip show black 2>/dev/null
which ruff || pip show ruff 2>/dev/null
which rustfmt 2>/dev/null
which gofmt 2>/dev/null
```

### Step 3: Generate Hook Configuration

Create `.claude/settings.json` (or merge with existing) with appropriate hooks:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "pattern": "\\.(js|jsx|ts|tsx|json|md)$",
        "command": "npx prettier --write \"$CLAUDE_FILE_PATH\""
      }
    ]
  }
}
```

### Step 4: Present Recommendations

Show the user:
1. Detected stack and recommended formatters
2. Which formatters are already installed vs. need installation
3. The proposed hooks configuration
4. Ask for approval before writing

### Step 5: Offer Installation Commands

If formatters are missing, provide installation commands:
- `npm install -D prettier` / `bun add -D prettier`
- `pip install black ruff`
- `rustup component add rustfmt`

### Common Hook Patterns

**JavaScript/TypeScript (Prettier):**
```json
{
  "matcher": "Edit|Write",
  "pattern": "\\.(js|jsx|ts|tsx|json|css|scss|md)$",
  "command": "npx prettier --write \"$CLAUDE_FILE_PATH\""
}
```

**Python (Black + Ruff):**
```json
{
  "matcher": "Edit|Write",
  "pattern": "\\.py$",
  "command": "black \"$CLAUDE_FILE_PATH\" && ruff check --fix \"$CLAUDE_FILE_PATH\""
}
```

**Rust:**
```json
{
  "matcher": "Edit|Write",
  "pattern": "\\.rs$",
  "command": "rustfmt \"$CLAUDE_FILE_PATH\""
}
```

---

$ARGUMENTS
