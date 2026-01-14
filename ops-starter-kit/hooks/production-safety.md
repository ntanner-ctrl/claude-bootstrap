# Production Safety Hook

Prevents accidental modifications to production configuration files and infrastructure.

## Hook Configuration

```json
{
  "hooks": [
    {
      "matcher": "Edit|Write",
      "hooks": [
        {
          "type": "prompt",
          "prompt": "Check if the file path contains production indicators: 'prod', 'production', 'live', 'prd', or is in a production directory. Also check for critical infrastructure files like 'main.tf', 'values.yaml' in prod paths, or files with '.prod.' in the name.\n\nFile: $FILE_PATH\n\nIf this appears to be a production file, respond with STOP and explain the risk. Suggest using a staging/dev environment first, or getting explicit confirmation.\n\nIf NOT a production file, respond with PROCEED.\n\nBe conservative - when in doubt, warn."
        }
      ]
    }
  ]
}
```

## What It Catches

| Pattern | Example | Risk |
|---------|---------|------|
| `prod` in path | `envs/prod/main.tf` | Direct production infrastructure |
| `production` in path | `config/production.yaml` | Production configuration |
| `live` in path | `deployments/live/` | Live environment resources |
| `.prod.` in filename | `database.prod.env` | Production-specific settings |
| `prd` abbreviation | `clusters/prd-east/` | Common production shorthand |

## Example Warnings

```
⚠️ PRODUCTION FILE DETECTED

You are about to edit: envs/prod/main.tf

This file appears to control production infrastructure. Modifications here
could affect live systems and customers.

Before proceeding:
1. Have you tested this change in staging/dev?
2. Is there a change management ticket?
3. Do you have rollback procedures ready?

To continue, explicitly confirm you understand the production impact.
```

## Philosophy

This hook follows the principle of **making production changes intentional, not accidental**. It doesn't block you—it makes you pause and confirm you really mean it.

## Customization

Adjust the patterns for your organization:
- Add your specific environment names (`uat`, `stg`, `preprod`)
- Include cloud-specific paths (`s3://prod-*`, `gs://production-*`)
- Add critical service names (`auth-service`, `payment-gateway`)
