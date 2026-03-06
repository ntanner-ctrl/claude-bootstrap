---
type: pattern
date: {{date}}
project: {{project}}
tags: [pattern]
extracted_from:
{{#each source_findings}}  - "[[{{this}}]]"
{{/each}}applicability: {{applicability}}
---

# {{title}}

## Pattern

{{description}}

## When to Use

{{when_to_use}}

## Example

{{example}}

## Source Findings

{{source_findings_list}}

## Trade-offs

{{tradeoffs}}
