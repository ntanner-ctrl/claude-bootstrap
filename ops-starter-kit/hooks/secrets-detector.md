# Secrets Detector Hook

Catches hardcoded secrets, API keys, passwords, and tokens before they get committed.

## Hook Configuration

```json
{
  "hooks": [
    {
      "matcher": "Edit|Write",
      "hooks": [
        {
          "type": "prompt",
          "prompt": "Analyze the content being written for potential secrets or sensitive data.\n\nFile: $FILE_PATH\nContent preview: $INPUT (first 2000 chars)\n\nLook for:\n1. API keys (patterns like 'sk-', 'pk_', 'api_key', 'apikey')\n2. Passwords (password=, passwd=, pwd=, secret=)\n3. Tokens (token=, bearer, jwt, access_token, refresh_token)\n4. Private keys (BEGIN RSA PRIVATE KEY, BEGIN OPENSSH PRIVATE KEY)\n5. AWS credentials (AKIA, aws_secret_access_key)\n6. Database connection strings with embedded passwords\n7. OAuth client secrets\n8. Webhook URLs with tokens\n\nIf you find ANY potential secrets, respond with STOP and:\n- Identify what type of secret it appears to be\n- Explain the risk of committing it\n- Suggest using environment variables or a secrets manager instead\n\nIf the file is clearly a template with placeholders (YOUR_KEY_HERE, <API_KEY>, ${SECRET}), that's acceptable - respond PROCEED.\n\nIf no secrets detected, respond with PROCEED."
        }
      ]
    }
  ]
}
```

## What It Catches

| Secret Type | Patterns | Risk Level |
|-------------|----------|------------|
| AWS Keys | `AKIA*`, `aws_secret_access_key` | Critical |
| API Keys | `sk-*`, `pk_*`, `api_key=` | High |
| Private Keys | `BEGIN RSA PRIVATE KEY` | Critical |
| Passwords | `password=`, `passwd=`, `pwd=` | High |
| Tokens | `token=`, `bearer `, `jwt` | High |
| Connection Strings | `mongodb+srv://user:pass@` | Critical |
| Webhook Secrets | `hooks.slack.com/services/T*/B*/` | Medium |

## Example Warning

```
🚨 POTENTIAL SECRET DETECTED

File: config/database.js
Found: Database connection string with embedded password

  const mongoUri = "mongodb+srv://admin:SuperSecret123@cluster.mongodb.net/prod"
                                        ^^^^^^^^^^^^^^^
                                        Hardcoded password!

This is dangerous because:
- Secrets in code get committed to version control
- Anyone with repo access can see production credentials
- Credentials may leak through logs, error messages, or backups

Instead, use:
  const mongoUri = process.env.MONGO_URI;

And set MONGO_URI in your environment or secrets manager.

To continue anyway, explicitly acknowledge the security risk.
```

## Exceptions

The hook allows these patterns (not secrets):
- Template placeholders: `YOUR_API_KEY_HERE`, `<INSERT_TOKEN>`, `${API_KEY}`
- Documentation examples: Files in `docs/`, `examples/`, `*.md`
- Test fixtures: Clearly fake values like `test-key-12345`, `password123`
- Environment variable references: `process.env.SECRET`, `os.environ['KEY']`

## Integration with .gitignore

This hook complements (doesn't replace) proper `.gitignore` rules:

```gitignore
# Secrets files that should never be committed
.env
.env.local
*.pem
*.key
credentials.json
secrets.yaml
```

## Philosophy

**Defense in depth**: This hook is one layer of protection. Also use:
- Pre-commit hooks (git-secrets, detect-secrets)
- GitHub secret scanning
- Vault/AWS Secrets Manager for production
