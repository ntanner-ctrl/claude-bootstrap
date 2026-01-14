---
name: env-exposure-protection
enabled: true
event: bash
pattern: (cat|less|head|tail|more|bat|grep)\s+.*\.env($|\s)
action: warn
---

**WARNING: Reading .env file**

You're about to read a `.env` file which typically contains sensitive data:
- API keys and tokens
- Database credentials
- Third-party service secrets

**Best practices:**
- Never commit `.env` files to git
- Use `.env.example` for documentation (without real values)
- Consider using a secrets manager for production

**If you need to debug:**
- Check specific variables: `echo $VARIABLE_NAME`
- Use `grep` with specific key names to avoid exposing everything
- Be mindful of terminal history and screen sharing

This is a **warning only** - the operation will proceed.
