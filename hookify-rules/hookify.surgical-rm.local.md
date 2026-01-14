---
name: surgical-rm-protection
enabled: true
event: bash
pattern: rm\s+-rf\s+(/($|[^a-zA-Z])|~(/|$)|\.\.(/|$)|/\*|~/\*|/home(/|$))
action: block
---

**BLOCKED: Dangerous rm -rf target detected**

You're attempting to delete a critical system location:
- `/` - Root filesystem
- `~` - Home directory
- `..` - Parent directory escape
- `/*` or `~/*` - Wildcard at dangerous level
- `/home` - All user directories

**Safe alternatives:**
- Delete specific subdirectories: `rm -rf ./node_modules`
- Use absolute paths to known safe targets
- List contents first with `ls` to verify

This rule allows `rm -rf` on safe targets like `node_modules`, `dist`, `.cache`, etc.
