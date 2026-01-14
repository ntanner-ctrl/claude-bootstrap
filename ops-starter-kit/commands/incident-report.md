---
description: Generate a post-incident report/postmortem from incident notes and timeline
arguments:
  - name: incident_id
    description: Incident identifier or title (optional)
    required: false
---

# Incident Report Generator

Generate a comprehensive post-incident report from the current incident.

## Your Task

Create a blameless post-incident report following industry best practices.

## Steps

1. **Gather incident information**
   - Check git log for recent deploys: `git log --oneline --since="24 hours ago"`
   - Look for incident notes in common locations: `./incidents/`, `./postmortems/`, `./docs/incidents/`
   - Check for timeline files or scratch notes

2. **Interview the user** (if needed)
   Use AskUserQuestion to gather:
   - What was the customer impact?
   - When was it detected? When was it resolved?
   - What was the root cause?
   - What actions were taken?

3. **Generate the report**

Write the report to `incidents/YYYY-MM-DD-{incident_id}.md` using this template:

```markdown
# Incident Report: {Title}

**Date:** {Date}
**Duration:** {Start time} to {End time} ({Total duration})
**Severity:** {P1/P2/P3/P4}
**Author:** {Name}
**Status:** {Resolved/Monitoring/Ongoing}

## Summary

{One paragraph executive summary: What happened, what was the impact, how was it resolved}

## Impact

| Metric | Value |
|--------|-------|
| Users affected | {Number or percentage} |
| Revenue impact | {Estimate if known} |
| SLA impact | {Which SLAs were affected} |
| Duration | {Time from detection to resolution} |

## Timeline (All times in UTC)

| Time | Event |
|------|-------|
| HH:MM | {What happened} |
| HH:MM | {What happened} |
| ... | ... |

## Root Cause

{Detailed technical explanation of what caused the incident. Be specific.}

## Detection

**How was this detected?**
{Alerting system, customer report, manual discovery, etc.}

**Time to detection:**
{How long from incident start to detection}

**Could we have detected this faster?**
{Analysis of detection gaps}

## Response

**What actions were taken?**
1. {First action and who took it}
2. {Second action}
3. {etc.}

**What worked well?**
- {What went right in our response}

**What could have gone better?**
- {Where we struggled or got lucky}

## Lessons Learned

### What went well
- {Good things about our response, infrastructure, or processes}

### What went poorly
- {Things that contributed to the incident or slowed resolution}

### Where we got lucky
- {Things that could have made this worse but didn't}

## Action Items

| Action | Owner | Priority | Due Date | Status |
|--------|-------|----------|----------|--------|
| {Specific action to prevent recurrence} | {Name} | P1/P2 | {Date} | Open |
| {Specific action} | {Name} | P1/P2 | {Date} | Open |

## Supporting Information

### Related Links
- [Dashboard during incident]({link})
- [Relevant logs]({link})
- [Related tickets]({link})

### Appendix

{Any additional technical details, graphs, or data}
```

4. **Review and refine**
   - Ensure the report is blameless (focus on systems, not people)
   - Verify action items are specific and actionable
   - Check that the timeline is complete

## Blameless Postmortem Principles

- **No naming and shaming** - Use roles, not names, in the timeline
- **Focus on systems** - "The deployment pipeline lacked rollback" not "Bob forgot to test"
- **Assume good intent** - Everyone was trying to do the right thing
- **Learn, don't blame** - The goal is prevention, not punishment
- **Be honest** - Acknowledge what went wrong, including our response

## Output

Confirm the report location and offer to:
- Open a PR with the report
- Create JIRA tickets for action items
- Schedule a postmortem review meeting
