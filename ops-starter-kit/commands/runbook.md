---
description: Generate an operational runbook for a service or procedure
arguments:
  - name: topic
    description: What the runbook should cover (e.g., "database failover", "certificate rotation", "service deployment")
    required: true
  - name: type
    description: Runbook type (deployment, incident, maintenance, recovery, onboarding)
    required: false
    default: maintenance
---

# Runbook Generator

Generate a comprehensive operational runbook for: **{{ topic }}**

Type: **{{ type }}**

## Process

### 1. Gather Context

First, understand the environment:

```bash
# Look for existing runbooks
find . -name "*.md" -path "*runbook*" -o -name "*.md" -path "*docs*" 2>/dev/null | head -20

# Check for infrastructure code
ls -la terraform/ infra/ k8s/ kubernetes/ helm/ 2>/dev/null

# Look for CI/CD configuration
ls -la .github/workflows/ .gitlab-ci.yml Jenkinsfile .circleci/ 2>/dev/null

# Check for docker/compose files
ls -la Dockerfile docker-compose*.yml 2>/dev/null

# Look for relevant scripts
ls -la scripts/ bin/ tools/ 2>/dev/null
```

### 2. Analyze the Topic

Based on the topic "{{ topic }}", identify:
- What system/service is involved?
- What actions need to be documented?
- What could go wrong?
- What prerequisites are needed?

### 3. Generate Runbook

Create the runbook at `docs/runbooks/{{ topic | slugify }}.md`:

Use this structure based on runbook type:

{% if type == "deployment" %}
## Deployment Runbook Template

```markdown
# {{ topic }} Deployment Runbook

## Overview
{What is being deployed and why}

## Prerequisites
- [ ] Access to {system}
- [ ] Permissions: {required roles}
- [ ] Tools: {required CLI tools}
- [ ] Approval: {any change management requirements}

## Pre-Deployment Checklist
- [ ] Tests passing in CI
- [ ] Code reviewed and approved
- [ ] Staging deployment successful
- [ ] Rollback procedure reviewed
- [ ] Team notified

## Deployment Steps

### 1. Preparation
{Commands to prepare for deployment}

### 2. Deploy
{Exact deployment commands}

### 3. Verify
{How to verify the deployment succeeded}

### 4. Smoke Tests
{Quick tests to confirm functionality}

## Rollback Procedure
{Step-by-step rollback if something goes wrong}

## Post-Deployment
- [ ] Verify metrics are normal
- [ ] Confirm no new errors in logs
- [ ] Update deployment log
- [ ] Notify stakeholders
```
{% elif type == "incident" %}
## Incident Response Runbook Template

```markdown
# {{ topic }} Incident Runbook

## Detection
**Symptoms:** {What alerts fire, what users report}
**Dashboards:** {Links to relevant monitoring}
**Logs:** {Where to find relevant logs}

## Severity Assessment

| Severity | Criteria | Response Time |
|----------|----------|---------------|
| P1 | Complete outage | Immediate |
| P2 | Major degradation | < 15 min |
| P3 | Minor impact | < 1 hour |

## Immediate Actions

### 1. Assess
{How to quickly assess the situation}

### 2. Communicate
{Who to notify, what channels}

### 3. Mitigate
{Quick actions to reduce impact}

## Diagnosis

### Common Causes
1. {Cause 1 and how to identify it}
2. {Cause 2 and how to identify it}

### Diagnostic Commands
{Commands to gather information}

## Resolution

### Fix for Cause 1
{Step-by-step fix}

### Fix for Cause 2
{Step-by-step fix}

## Post-Incident
- [ ] Verify service restored
- [ ] Notify stakeholders
- [ ] Create incident ticket
- [ ] Schedule postmortem
```
{% elif type == "maintenance" %}
## Maintenance Runbook Template

```markdown
# {{ topic }} Maintenance Runbook

## Overview
{What maintenance is being performed and why}

## Schedule
**Frequency:** {How often}
**Duration:** {Expected time}
**Impact:** {What users will experience}

## Prerequisites
- [ ] Maintenance window scheduled
- [ ] Stakeholders notified
- [ ] Backup verified

## Pre-Maintenance Checks
{Verify system state before starting}

## Procedure

### Step 1: {Action}
{Detailed commands and expected output}

### Step 2: {Action}
{Detailed commands and expected output}

## Verification
{How to confirm maintenance was successful}

## Backout Procedure
{How to undo if something goes wrong}

## Post-Maintenance
- [ ] Verify service functioning
- [ ] Update maintenance log
- [ ] Notify stakeholders of completion
```
{% elif type == "recovery" %}
## Recovery Runbook Template

```markdown
# {{ topic }} Recovery Runbook

## Disaster Scenario
{What situation triggers this recovery}

## Recovery Objectives
- **RPO:** {Maximum acceptable data loss}
- **RTO:** {Maximum acceptable downtime}

## Prerequisites
- [ ] Access to backup systems
- [ ] Recovery credentials available
- [ ] Target environment ready

## Recovery Procedure

### 1. Assess Damage
{Determine extent of failure}

### 2. Prepare Recovery Environment
{Set up for recovery}

### 3. Restore Data
{Data restoration steps}

### 4. Restore Services
{Service restoration steps}

### 5. Validate
{Verify recovery successful}

## Post-Recovery
- [ ] Verify data integrity
- [ ] Confirm all services operational
- [ ] Document recovery
- [ ] Conduct review
```
{% elif type == "onboarding" %}
## Onboarding Runbook Template

```markdown
# {{ topic }} Onboarding Runbook

## Overview
{What this onboarding covers}

## Before Day 1
- [ ] Accounts created
- [ ] Access requests submitted
- [ ] Equipment ordered

## Day 1

### System Access
{How to get required access}

### Tool Setup
{Tools to install and configure}

### Environment Setup
{Local development environment}

## First Week

### Codebase Tour
{Key repositories and their purpose}

### Key Processes
{How deployments work, how to get help}

### First Task
{Suggested first contribution}

## Resources
- Team Slack channel: #team-name
- Documentation: {link}
- On-call rotation: {link}
```
{% endif %}

### 4. Enhance with Project-Specific Details

After generating the template, read relevant project files to fill in:
- Actual commands from scripts or CI/CD
- Real service names and endpoints
- Existing monitoring and dashboard links
- Team-specific processes

### 5. Review and Validate

Present the runbook to the user and ask:
- Are there any missing steps?
- Are the commands correct?
- Should we add troubleshooting sections?
- Who should review this runbook?

## Output

Save the runbook and confirm:
- Location of the saved runbook
- Suggested reviewers
- Recommendation to add to team wiki/docs
