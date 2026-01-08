---
name: security-warning
description: Warns when editing files that may contain sensitive data or credentials
hooks:
  - event: PostToolUse
    tools:
      - Write
      - Edit
    pattern: "**/.env*|**/credentials*|**/secrets*|**/*.pem|**/*.key|**/*secret*|**/*password*|**/*token*|**/config.json|**/settings.json"
---

# Security Warning

You are editing a file that may contain sensitive data.

## Security Checklist

Before proceeding, verify:

### Credentials & Secrets
- [ ] No hardcoded API keys, tokens, or passwords
- [ ] Using environment variables or secret manager references
- [ ] Placeholder values use obvious fake data (e.g., `YOUR_API_KEY_HERE`)

### File Protection
- [ ] File is listed in `.gitignore` (if it contains real secrets)
- [ ] Permissions are appropriately restricted
- [ ] Not logging sensitive values to console/files

### Best Practices
- [ ] Using a secrets manager (AWS Secrets Manager, HashiCorp Vault, etc.)
- [ ] Rotating credentials regularly
- [ ] Different credentials per environment (dev/staging/prod)

## Never Commit

These should NEVER be committed to version control:
- API keys and tokens
- Private keys (`.pem`, `.key`, `.p12`)
- Database passwords
- OAuth client secrets
- SSH private keys
- AWS access keys
- Encryption keys

## Safe Patterns

**Instead of hardcoding:**
```python
# BAD
API_KEY = "sk-1234567890abcdef"

# GOOD
API_KEY = os.environ.get("API_KEY")
```

**For configuration files:**
```yaml
# BAD - config.yml
database:
  password: "mysecretpassword"

# GOOD - config.yml (with .env)
database:
  password: ${DATABASE_PASSWORD}
```

## If You Must Store Secrets

1. Use `.env.example` with placeholder values (commit this)
2. Use `.env` with real values (gitignore this)
3. Document required environment variables in README

## Customization

Adjust the `pattern` to match your project's sensitive file patterns:
- Add paths to configuration files
- Include credential storage locations
- Match your secrets file naming conventions
