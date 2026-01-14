# Shell Safety Hook

Warns about dangerous shell commands and patterns that could cause data loss or system damage.

## Hook Configuration

```json
{
  "hooks": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "prompt",
          "prompt": "Analyze this shell command for dangerous patterns:\n\nCommand: $INPUT\n\nCheck for:\n1. Destructive commands: rm -rf, rmdir, del /s\n2. Recursive operations on root or home: rm -rf /, rm -rf ~, rm -rf /*\n3. Dangerous permissions: chmod 777, chmod -R 777\n4. Force flags without safeguards: --force, -f with destructive commands\n5. Pipe to shell: curl | sh, wget | bash (supply chain risk)\n6. Disk operations: dd, mkfs, fdisk on real devices\n7. Fork bombs: :(){ :|:& };:\n8. Privilege escalation without context: sudo rm -rf\n9. Variable expansion in dangerous contexts: rm -rf $UNSET_VAR/*\n10. Overwriting important files: > /etc/passwd, > ~/.bashrc\n\nFor DANGEROUS commands, respond with STOP and:\n- Explain what the command does\n- Describe the potential damage\n- Suggest a safer alternative\n\nFor commands that are risky but have legitimate uses (like rm -rf on a specific known path), respond with WARN and ask for confirmation.\n\nFor safe commands, respond with PROCEED."
        }
      ]
    }
  ]
}
```

## What It Catches

### Critical (Always Block)

| Pattern | Why It's Dangerous |
|---------|-------------------|
| `rm -rf /` | Deletes entire filesystem |
| `rm -rf ~` | Deletes home directory |
| `rm -rf /*` | Same as above, different syntax |
| `chmod -R 777 /` | Makes everything world-writable |
| `:(){ :\|:& };:` | Fork bomb, crashes system |
| `dd if=/dev/zero of=/dev/sda` | Wipes disk |
| `mkfs.ext4 /dev/sda` | Formats disk |

### High Risk (Warn)

| Pattern | Risk |
|---------|------|
| `curl \| sh` | Executes remote code without review |
| `wget \| bash` | Same supply chain risk |
| `rm -rf $VAR` | If $VAR is unset, could delete unexpected paths |
| `sudo rm -rf` | Elevated privileges + destruction |
| `> important_file` | Overwrites file with empty content |
| `chmod 777` | Overly permissive |

### Contextual (Depends on Target)

| Pattern | Safe If... |
|---------|-----------|
| `rm -rf ./node_modules` | Known build artifact |
| `rm -rf /tmp/build-*` | Temp files with clear naming |
| `docker system prune -af` | Intentional cleanup |

## Example Warnings

### Critical Block
```
🛑 CRITICAL: DESTRUCTIVE COMMAND BLOCKED

Command: rm -rf /*

This command will DELETE EVERYTHING on your system, including:
- Operating system files
- All user data
- All installed programs

This is almost certainly not what you want.

If you're trying to clean up a directory, be specific:
  rm -rf ./specific-directory/

I cannot proceed with this command.
```

### High Risk Warning
```
⚠️ RISKY COMMAND DETECTED

Command: curl -fsSL https://example.com/install.sh | bash

This pipes remote code directly to your shell without review.
Risks:
- Malicious code execution
- Supply chain attacks
- No audit trail

Safer alternatives:
1. Download first, then review:
   curl -fsSL https://example.com/install.sh -o install.sh
   less install.sh  # Review the script
   bash install.sh

2. Use a package manager if available:
   brew install example
   apt install example

To proceed anyway, confirm you trust this source.
```

## Philosophy

**You can always type the command manually** if you really need to. This hook exists to prevent Claude from inadvertently suggesting or executing commands that could cause irreversible damage.

The goal is not to block legitimate work, but to ensure destructive operations are:
1. Intentional (you confirm you want this)
2. Targeted (specific paths, not wildcards)
3. Reviewed (you understand the impact)

## Escape Hatch

If you need to run a blocked command, you can:
1. Run it manually in your terminal
2. Confirm the specific use case when prompted
3. Temporarily disable the hook for maintenance windows
