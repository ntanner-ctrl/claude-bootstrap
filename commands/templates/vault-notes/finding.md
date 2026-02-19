---
type: finding
date: {{date}}
project: {{project}}
category: {{category}}
severity: {{severity}}
tags: [finding]
{{#if empirica_confidence}}empirica_confidence: {{empirica_confidence}}{{/if}}
{{#if empirica_assessed}}empirica_assessed: {{empirica_assessed}}{{/if}}
{{#if empirica_session}}empirica_session: {{empirica_session}}{{/if}}
{{#if empirica_status}}empirica_status: {{empirica_status}}{{/if}}
---

# {{title}}

{{description}}

## Source
- Session: [[{{session_link}}]]
{{#if blueprint_link}}- Blueprint: [[{{blueprint_link}}]]{{/if}}

## Implications
{{implications}}
