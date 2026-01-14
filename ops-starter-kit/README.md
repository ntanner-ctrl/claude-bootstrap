# Ops Starter Kit for Claude Code

> Claude Code extensions for infrastructure engineers, SREs, DevOps, and platform teams.

**Headcount compression for ops work.** This kit gives Claude Code the context and guardrails to safely help with:

- 🚀 **Deployments** - Pre-flight checks, safe rollouts
- 🔥 **Incidents** - Systematic response, postmortems
- 🏗️ **Infrastructure** - Terraform, Kubernetes, CloudFormation review
- 📝 **Runbooks** - Operational documentation that's actually useful
- 🔒 **Safety** - Guards against dangerous commands and secrets exposure

## Quick Install

```bash
git clone https://github.com/YOUR_USER/ops-starter-kit.git
cd ops-starter-kit
./install.sh
```

## What's Included

### Hooks (Safety Guards)

Hooks intercept actions and warn you before you do something risky.

| Hook | What It Does |
|------|--------------|
| **production-safety** | Warns before editing files with `prod`, `production`, `live` in the path |
| **secrets-detector** | Catches API keys, passwords, tokens, private keys before they're committed |
| **shell-safety** | Blocks `rm -rf /`, `chmod 777`, and other destructive commands |
| **iac-validator** | Validates Terraform, Kubernetes, Docker files for common issues |

### Commands (Slash Commands)

Quick actions you can invoke directly in Claude Code.

| Command | Usage |
|---------|-------|
| `/deploy-check [env]` | Pre-deployment validation checklist |
| `/incident-report [id]` | Generate a blameless post-incident report |
| `/runbook [topic]` | Create an operational runbook |

### Agents (Subagents for Complex Tasks)

Specialized agents for longer, multi-step operations.

| Agent | When to Use |
|-------|-------------|
| **incident-responder** | Production incident: "API is returning 500s" |
| **infra-analyzer** | Review: "Check our Terraform for security issues" |
| **runbook-generator** | Documentation: "Create a runbook for database failover" |

### Template

A ready-to-customize `CLAUDE.md` template for infrastructure/ops projects:

```bash
cp ~/.claude/templates/CLAUDE.md.ops-template ./CLAUDE.md
# Edit to match your project
```

## Usage Examples

### Pre-Deployment Check

```
you: /deploy-check production

Claude: Running pre-deployment checks for production...

✅ Git Status: Clean, on branch main
✅ Tests: 142 passed, 0 failed
✅ Build: Successful
⚠️ Security: 2 low-severity vulnerabilities in dependencies
✅ Lint: No issues

Manual checklist required before proceeding...
```

### Incident Response

```
you: The checkout API is returning 500 errors

Claude: I'll help you respond to this incident systematically.

CURRENT STATUS: Investigating - Checkout API 500 errors

PHASE 1: ASSESS

Let me gather information:
- Checking recent deployments...
- Pulling error logs...
- Checking database health...

[Continues with systematic incident response]
```

### Infrastructure Review

```
you: Review our Terraform for the new VPC

Claude: [Uses infra-analyzer agent]

## Infrastructure Analysis: VPC Module

### Summary
Found 2 critical issues and 5 suggestions for improvement.

#### 🔴 Critical Issues
| Issue | Location | Fix |
|-------|----------|-----|
| Public subnets allow 0.0.0.0/0 ingress | main.tf:45 | Restrict to known CIDRs |
| No flow logs enabled | main.tf | Add VPC flow logs for audit |

[Detailed analysis continues]
```

### Runbook Generation

```
you: /runbook database-failover

Claude: Generating runbook for: database-failover

[Analyzes project structure]
[Identifies database technology]
[Creates step-by-step runbook]

Saved to: docs/runbooks/database-failover.md
```

## Philosophy

### For Ops People, By Ops People

This kit is designed for folks who:
- Get paged at 3 AM and need to think clearly
- Manage infrastructure that can't just be "restarted"
- Know that `rm -rf` is forever
- Write runbooks because documentation saves lives

### Safety First

Every hook exists because someone, somewhere, made that mistake:
- Committed an AWS key to GitHub
- Ran `terraform apply` on production by accident
- `chmod 777`'d a production directory
- Edited `prod.yaml` when they meant `staging.yaml`

### Systematic Over Heroic

The incident-responder agent doesn't try to be clever. It follows a systematic process because:
- Panicking humans skip steps
- Tired humans miss obvious things
- Stressed humans tunnel-vision on wrong hypotheses

A boring checklist beats a brilliant improvisation.

## Customization

### Adding Project-Specific Hooks

Create `.claude/hooks/your-hook.md` in your project:

```markdown
# My Custom Hook

## Hook Configuration

\`\`\`json
{
  "hooks": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "prompt",
          "prompt": "Your validation prompt here..."
        }
      ]
    }
  ]
}
\`\`\`
```

### Extending the CLAUDE.md Template

The template is a starting point. Customize it with:
- Your actual infrastructure architecture
- Your team's escalation procedures
- Your monitoring dashboard links
- Your deployment commands

## Contributing

Found a hook that would have saved you from a mistake? Have an agent idea? PRs welcome!

1. Fork the repo
2. Add your hook/agent/command
3. Document it clearly
4. Open a PR

## License

MIT - Use it, modify it, share it.

---

*Built for the ops community by someone who's been paged at 3 AM too many times.*
