# Infrastructure-as-Code Validator Hook

Validates Terraform, Ansible, CloudFormation, and Kubernetes manifests for common issues and anti-patterns.

## Hook Configuration

```json
{
  "hooks": [
    {
      "matcher": "Edit|Write",
      "hooks": [
        {
          "type": "prompt",
          "prompt": "Check if this is an infrastructure-as-code file based on extension and content:\n- Terraform: *.tf, *.tfvars\n- Ansible: playbook*.yml, */tasks/*.yml, */roles/*/\n- CloudFormation: *template*.yaml, *cfn*.yaml, AWSTemplateFormatVersion\n- Kubernetes: *deployment*.yaml, *service*.yaml, kind: Deployment/Service/Pod\n- Docker: Dockerfile*, docker-compose*.yml\n- Helm: Chart.yaml, values*.yaml in charts/\n\nFile: $FILE_PATH\n\nIf this IS an IaC file, validate for:\n\n**Terraform:**\n- Hardcoded credentials or secrets\n- Missing provider version constraints\n- Resources without lifecycle blocks for critical infra\n- Public access enabled (0.0.0.0/0) without explicit comment\n- Missing tags (especially for cost allocation)\n\n**Kubernetes:**\n- Containers running as root\n- Missing resource limits (memory/cpu)\n- Latest tag instead of pinned versions\n- Missing health checks (liveness/readiness probes)\n- Privileged containers\n- Missing network policies\n\n**Docker:**\n- Running as root\n- Using :latest tag\n- Secrets in build args or ENV\n- Missing HEALTHCHECK\n- Unnecessary privileged operations\n\n**Ansible:**\n- Plaintext passwords (use ansible-vault)\n- become: yes without justification\n- Shell/command modules where a dedicated module exists\n\nIf issues found, respond WARN with specific findings and fixes.\nIf critical security issue, respond STOP.\nIf no IaC or no issues, respond PROCEED."
        }
      ]
    }
  ]
}
```

## What It Validates

### Terraform

| Issue | Risk | Fix |
|-------|------|-----|
| No provider version | Unexpected breaking changes | `required_providers { aws = { version = \"~> 5.0\" } }` |
| `0.0.0.0/0` ingress | Public exposure | Restrict to known CIDRs or add explicit comment |
| Hardcoded AMI IDs | Region lock-in | Use data sources or variables |
| No state locking | Corruption risk | Configure backend with DynamoDB |
| Missing tags | Cost tracking impossible | Add `default_tags` in provider |

### Kubernetes

| Issue | Risk | Fix |
|-------|------|-----|
| `runAsRoot: true` | Container escape | `runAsNonRoot: true` |
| No resource limits | Node exhaustion | Set `resources.limits` |
| `:latest` tag | Unpredictable deployments | Pin to specific version |
| No probes | Zombie pods | Add `livenessProbe` and `readinessProbe` |
| `privileged: true` | Full host access | Use specific capabilities instead |

### Docker

| Issue | Risk | Fix |
|-------|------|-----|
| No USER instruction | Runs as root | `USER nonroot` |
| `FROM image:latest` | Version drift | Pin to digest or specific tag |
| `ARG PASSWORD` | Leaks in image layers | Use runtime secrets |
| No HEALTHCHECK | Unhealthy containers stay up | Add `HEALTHCHECK CMD` |

### Ansible

| Issue | Risk | Fix |
|-------|------|-----|
| `password: "literal"` | Exposed in playbooks | Use `ansible-vault` |
| `shell:` for packages | Idempotency issues | Use `apt`, `yum` modules |
| Global `become: yes` | Over-privileged | Scope to specific tasks |

## Example Warnings

### Security Issue (STOP)
```
🛑 SECURITY ISSUE IN INFRASTRUCTURE CODE

File: terraform/modules/rds/main.tf

Found: publicly_accessible = true on RDS instance

resource "aws_db_instance" "main" {
  ...
  publicly_accessible = true  # ⚠️ Database exposed to internet!
  ...
}

This allows direct connections from the internet to your database.
Even with security groups, this violates defense-in-depth.

Fix:
  publicly_accessible = false

Access the database through:
- VPN connection
- Bastion host
- AWS Session Manager
```

### Best Practice Warning (WARN)
```
⚠️ INFRASTRUCTURE BEST PRACTICE WARNING

File: k8s/deployments/api.yaml

Issues found:

1. Missing resource limits (Line 24)
   containers:
   - name: api
     image: api:1.2.3
     # No resources specified!

   Fix: Add resource constraints
     resources:
       requests:
         memory: "128Mi"
         cpu: "100m"
       limits:
         memory: "256Mi"
         cpu: "500m"

2. Missing liveness probe
   Without health checks, Kubernetes can't detect hung processes.

   Fix: Add health check
     livenessProbe:
       httpGet:
         path: /health
         port: 8080
       initialDelaySeconds: 10
       periodSeconds: 5

Would you like me to add these fixes?
```

## Philosophy

Infrastructure-as-code is powerful but unforgiving. Unlike application bugs that might cause errors, IaC mistakes can:
- Expose production databases to the internet
- Wipe out entire environments
- Create security vulnerabilities in minutes
- Cost thousands in unexpected cloud charges

This hook acts as a **pre-flight checklist** before changes reach your infrastructure.

## Customization

Extend with your organization's standards:
- Required tags for cost allocation
- Approved instance types
- Mandatory encryption settings
- Network segmentation rules
- Compliance requirements (PCI, HIPAA, SOC2)
