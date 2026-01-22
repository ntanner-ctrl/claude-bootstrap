---
description: STOP. You MUST complete this before ANY production deployment. Validates safety conditions that prevent outages.
arguments:
  - name: environment
    description: Target environment (staging, production)
    required: false
    default: production
---

# Pre-Deployment Checklist

Run a comprehensive pre-deployment validation before releasing to {{ environment }}.

## Automated Checks

Run these checks and report results:

### 1. Git Status
```bash
# Check for uncommitted changes
git status --porcelain

# Verify we're on the expected branch
git branch --show-current

# Check if we're up to date with remote
git fetch origin && git status -uno
```

### 2. Tests
```bash
# Run the test suite
npm test 2>&1 || yarn test 2>&1 || pytest 2>&1 || go test ./... 2>&1 || make test 2>&1
```

### 3. Build Verification
```bash
# Verify the build succeeds
npm run build 2>&1 || yarn build 2>&1 || make build 2>&1 || go build ./... 2>&1
```

### 4. Dependency Audit
```bash
# Check for known vulnerabilities
npm audit 2>&1 || yarn audit 2>&1 || pip-audit 2>&1 || safety check 2>&1
```

### 5. Docker Build (if applicable)
```bash
# Verify Docker image builds
if [ -f Dockerfile ]; then
  docker build --no-cache -t deploy-check-test .
fi
```

### 6. Linting
```bash
# Run linters
npm run lint 2>&1 || yarn lint 2>&1 || make lint 2>&1
```

### 7. Terraform Plan (if applicable)
```bash
# Preview infrastructure changes
if [ -d terraform ] || [ -d infra ]; then
  cd terraform 2>/dev/null || cd infra
  terraform plan -out=plan.out 2>&1
fi
```

## Manual Checklist

After automated checks, present this checklist using AskUserQuestion:

```
## Pre-Deployment Verification

Please confirm the following before deploying to {{ environment }}:

### Code Review
- [ ] All code has been reviewed and approved
- [ ] No unresolved comments on the PR

### Testing
- [ ] Feature tested in staging/dev environment
- [ ] Edge cases considered and tested
- [ ] Performance impact assessed

### Documentation
- [ ] README updated if needed
- [ ] API documentation updated
- [ ] Runbooks updated if operational changes

### Monitoring
- [ ] Relevant dashboards identified
- [ ] Alert thresholds appropriate
- [ ] Rollback procedure understood

### Communication
- [ ] Team notified of deployment
- [ ] Stakeholders aware of changes
- [ ] On-call engineer aware (if after hours)

### Rollback Plan
- [ ] Rollback procedure documented
- [ ] Previous version identified
- [ ] Feature flags in place (if applicable)
```

## Output Format

Generate a deployment readiness report:

```markdown
# Deployment Readiness Report

**Target:** {{ environment }}
**Timestamp:** {current datetime}
**Branch:** {current branch}
**Commit:** {short commit hash}

## Automated Checks

| Check | Status | Details |
|-------|--------|---------|
| Git Status | ✅ / ❌ | {details} |
| Tests | ✅ / ❌ | {pass/fail count} |
| Build | ✅ / ❌ | {details} |
| Security Audit | ✅ / ⚠️ / ❌ | {vulnerability count} |
| Lint | ✅ / ❌ | {details} |
| Infra Plan | ✅ / ⚠️ / N/A | {resources changing} |

## Manual Checklist

{Checklist results from user}

## Recommendation

{READY TO DEPLOY / BLOCKERS FOUND / NEEDS REVIEW}

{If blockers: List specific issues that must be resolved}

## Deploy Command

If ready, deploy with:
{Appropriate deploy command for the project}
```

## Severity Levels

- ✅ **Pass** - Check succeeded, no issues
- ⚠️ **Warning** - Issues found but not blocking
- ❌ **Fail** - Blocking issues, do not deploy

## Blocking Conditions

Do NOT recommend deployment if:
- Tests are failing
- Critical/high security vulnerabilities found
- Uncommitted changes exist
- Build fails
- User did not confirm manual checklist items
- Terraform plan shows destructive changes (destroy) without explicit acknowledgment

## Post-Check Actions

Offer to:
1. Fix identified issues automatically (if possible)
2. Create a deployment ticket with the report
3. Notify the team via configured channels
4. Proceed with deployment (if all checks pass)
