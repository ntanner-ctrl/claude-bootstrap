---
type: finding
date: {{date}}
project: {{project}}
category: prism-assessment
severity: info
tags: [prism, code-health, assessment]
---

# Prism Assessment: {{project}}

## Summary
{{theme_count}} themes identified across {{file_count}} files.
{{discrete_count}} discrete fixes, {{nebulous_count}} nebulous patterns.

## High Priority Themes
| Theme | Category | Ease | Impact | Risk |
|-------|----------|------|--------|------|
{{#each high_priority_themes}}
| {{name}} | {{category}} | {{ease}} | {{impact}} | {{risk}} |
{{/each}}

## Recurring Themes (vs prior runs)
{{#if recurring_themes}}
{{#each recurring_themes}}
- {{this}}
{{/each}}
{{else}}
First assessment — no prior runs to compare.
{{/if}}

## Domain Coverage
| Domain | Findings | Status |
|--------|----------|--------|
| Architecture | {{arch_findings}} | {{arch_status}} |
| Security | {{security_findings}} | {{security_status}} |
| Performance | {{perf_findings}} | {{perf_status}} |
| Quality | {{quality_findings}} | {{quality_status}} |
| CloudFormation | {{cf_findings}} | {{cf_status}} |

## Constraint Extraction Audit
{{constraint_audit}}
