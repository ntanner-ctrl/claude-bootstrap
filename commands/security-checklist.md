---
description: Run a structured 8-point security audit based on OWASP and industry best practices
argument-hint: Optional focus area (e.g., "auth", "api", "deps")
allowed-tools: ["Bash", "Read", "Grep", "Glob", "Task", "TodoWrite", "AskUserQuestion"]
---

# 8-Point Security Audit Checklist

Perform a comprehensive security audit following the structured checklist below. This framework ensures systematic coverage rather than ad-hoc checking.

## Severity Classification

Use these severity levels when reporting findings:

| Severity | Response | Examples |
|----------|----------|----------|
| **CRITICAL** | Block deployment | SQL injection, hardcoded secrets in repo, RCE vulnerabilities |
| **HIGH** | Fix within 7 days | Missing rate limiting, weak password hashing, IDOR |
| **MEDIUM** | Fix within 30 days | Verbose error messages, missing CSRF, permissive CORS |
| **LOW** | Backlog | Minor config improvements, outdated non-vulnerable deps |

## The 8-Point Checklist

Work through each category systematically. For each finding, assign a severity and provide specific remediation steps.

$ARGUMENTS

### 1. SECRETS EXPOSURE

**What to check:**
- Hardcoded credentials in source code
- `.env` files committed to git
- API keys, tokens, passwords in code
- Git history containing secrets
- `.gitignore` coverage for sensitive files

**Commands to run:**
```bash
# Check for common secret patterns in codebase
grep -rE "(api[_-]?key|secret|password|token|credential)\s*[:=]\s*['\"][^'\"]{8,}" --include="*.{js,ts,py,json,yaml,yml,env}" .

# Check git history for secrets (last 100 commits)
git log -p -100 | grep -iE "(password|secret|api.?key|token)\s*[:=]" | head -50

# Verify .gitignore covers sensitive files
cat .gitignore | grep -E "\.env|secret|credential|\.pem|\.key"

# Check for .env files in repo
find . -name "*.env*" -not -path "./node_modules/*" -not -path "./.git/*"
```

**Look for:**
- AWS access keys (`AKIA...`)
- Private keys (`-----BEGIN.*PRIVATE KEY-----`)
- Database connection strings
- OAuth client secrets

---

### 2. DEPENDENCY VULNERABILITIES

**What to check:**
- Known CVEs in dependencies
- Outdated packages with security patches
- Transitive dependency vulnerabilities

**Commands to run (based on project type):**
```bash
# Node.js
npm audit --audit-level=moderate 2>/dev/null || echo "npm audit not available"

# Python
pip-audit 2>/dev/null || pip check 2>/dev/null || echo "pip-audit not available"

# Go
govulncheck ./... 2>/dev/null || echo "govulncheck not available"

# Rust
cargo audit 2>/dev/null || echo "cargo-audit not available"

# Ruby
bundle audit check 2>/dev/null || echo "bundle-audit not available"
```

**Action items:**
- Run the audit tool for your stack
- Prioritize by severity (critical/high first)
- Check if patches are available
- Document unfixable vulnerabilities with mitigations

---

### 3. INPUT VALIDATION

**What to check:**
- SQL injection vulnerabilities
- Command injection vulnerabilities
- Path traversal vulnerabilities
- XSS (Cross-Site Scripting) vulnerabilities
- Template injection

**Code patterns to search:**
```bash
# SQL injection risks (string concatenation in queries)
grep -rE "(\"|').*\+.*(\"|').*SELECT|INSERT|UPDATE|DELETE" --include="*.{js,ts,py,go,java}" .

# Command injection risks
grep -rE "exec\(|spawn\(|system\(|popen\(|eval\(|subprocess\." --include="*.{js,ts,py}" .

# Path traversal risks
grep -rE "\.\.\/|path\.join\(.*req\.|fs\.(read|write).*req\." --include="*.{js,ts}" .

# innerHTML/dangerouslySetInnerHTML (XSS)
grep -rE "innerHTML\s*=|dangerouslySetInnerHTML" --include="*.{js,jsx,ts,tsx}" .
```

**Verify:**
- Parameterized queries used (not string concatenation)
- User input sanitized before shell execution
- Path inputs validated against traversal
- HTML output escaped or using safe rendering

---

### 4. AUTHENTICATION & AUTHORIZATION

**What to check:**
- Password hashing algorithm (bcrypt/argon2 preferred)
- Session management security
- JWT implementation (algorithm, expiry, secrets)
- CSRF protection
- Rate limiting on auth endpoints
- Account lockout mechanisms

**Code patterns to search:**
```bash
# Password hashing (should use bcrypt, argon2, or scrypt)
grep -rE "md5|sha1|sha256.*password" --include="*.{js,ts,py,go}" .

# Session configuration
grep -rE "session|cookie|httpOnly|secure|sameSite" --include="*.{js,ts,py,json}" .

# JWT configuration
grep -rE "jwt|jsonwebtoken|jose" --include="*.{js,ts,py}" .

# Rate limiting
grep -rE "rate.?limit|throttle|express-rate" --include="*.{js,ts,py,json}" .
```

**Verify:**
- Strong hashing (bcrypt rounds >= 10, argon2 preferred)
- Session cookies: `httpOnly: true`, `secure: true`, `sameSite: strict/lax`
- JWT: RS256 or ES256 (not HS256 with weak secret), reasonable expiry
- Rate limiting on `/login`, `/register`, `/password-reset`

---

### 5. TRANSPORT SECURITY

**What to check:**
- HTTPS enforcement
- HSTS headers
- Secure cookie flags
- TLS version (1.2+ required)
- Certificate validity

**Code patterns to search:**
```bash
# HSTS configuration
grep -rE "Strict-Transport-Security|hsts" --include="*.{js,ts,py,json,yaml}" .

# Secure cookie configuration
grep -rE "secure.*true|Secure" --include="*.{js,ts,py}" .

# HTTP redirects to HTTPS
grep -rE "redirect.*https|force.*ssl" --include="*.{js,ts,nginx,conf}" .
```

**Verify:**
- HSTS header present with reasonable max-age (31536000 recommended)
- All cookies marked `Secure` in production
- HTTP requests redirect to HTTPS
- No mixed content (HTTP resources on HTTPS pages)

---

### 6. ERROR HANDLING

**What to check:**
- Stack traces not exposed in production
- Generic error messages for users
- Detailed logging for developers (not users)
- Sensitive data not in error messages

**Code patterns to search:**
```bash
# Stack trace exposure
grep -rE "stack|stackTrace|traceback" --include="*.{js,ts,py}" .

# Error handlers
grep -rE "catch|except|error.*handler|onError" --include="*.{js,ts,py}" .

# Environment checks for error detail
grep -rE "NODE_ENV|FLASK_ENV|DEBUG.*=.*True" --include="*.{js,ts,py,json}" .
```

**Verify:**
- Production error responses are generic ("An error occurred")
- Stack traces only logged server-side
- No database errors exposed to users
- Sensitive data (passwords, tokens) not in logs

---

### 7. FILE UPLOAD SECURITY

**What to check:**
- Server-side file type validation
- File size limits
- Uploaded file storage location
- Filename sanitization
- Malware scanning (if applicable)

**Code patterns to search:**
```bash
# File upload handling
grep -rE "upload|multer|formidable|multipart" --include="*.{js,ts,py}" .

# File type checking
grep -rE "mimetype|content-type|file.*type|magic" --include="*.{js,ts,py}" .

# File size limits
grep -rE "maxFileSize|limit.*size|max.*bytes" --include="*.{js,ts,py,json}" .
```

**Verify:**
- File type validated server-side (not just client extension)
- Reasonable size limits enforced
- Files stored outside web root or with non-executable permissions
- Filenames sanitized (no path traversal)
- Consider antivirus scanning for user uploads

---

### 8. API SECURITY

**What to check:**
- Authentication required on endpoints
- Authorization checks (user can only access own data)
- Rate limiting
- CORS configuration
- Input validation on all endpoints

**Code patterns to search:**
```bash
# CORS configuration
grep -rE "cors|Access-Control-Allow" --include="*.{js,ts,py,json}" .

# Auth middleware
grep -rE "auth|authenticate|authorize|middleware" --include="*.{js,ts,py}" .

# Rate limiting
grep -rE "rate.?limit|throttle" --include="*.{js,ts,py}" .
```

**Verify:**
- All sensitive endpoints require authentication
- CORS not set to `*` (wildcard) in production
- Rate limiting on all public endpoints
- Authorization checks prevent horizontal privilege escalation (IDOR)

---

## Output Format

After completing the audit, produce a report in this format:

```markdown
# Security Audit Report - [Project Name]
Date: [Date]

## Executive Summary
- Total findings: X
- Critical: X | High: X | Medium: X | Low: X

## Findings

### [SEVERITY] Finding Title
**Category:** [1-8 from checklist]
**Location:** [File:line or component]
**Description:** [What's wrong]
**Impact:** [What could happen]
**Remediation:** [How to fix]
**Timeline:** [When to fix based on severity]

[Repeat for each finding]

## Recommendations
[Prioritized action items]
```

---

## Execution Instructions

1. Use TodoWrite to track progress through each of the 8 categories
2. Run relevant commands for each category
3. Search code patterns for each category
4. Document all findings with severity ratings
5. Produce final report

If `$ARGUMENTS` specifies a focus area (e.g., "auth", "deps"), prioritize that category but still do a quick check of others.

Start by detecting the project type and running the initial scans.
