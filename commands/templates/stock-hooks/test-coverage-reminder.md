---
name: test-coverage-reminder
description: Reminds to check for corresponding test files when editing source modules
hooks:
  - event: PostToolUse
    tools:
      - Write
      - Edit
    pattern: "src/**/*.{py,ts,js,tsx,jsx,rs,go}|lib/**/*.py|**/*.py"
---

# Test Coverage Reminder

When editing source files, this hook reminds you to check for corresponding tests.

## What This Hook Does

After you create or edit a source file, it will remind you to:
1. Check if a corresponding test file exists
2. Verify the tests cover the functionality you modified
3. Consider edge cases and error paths

## Test File Location Conventions

| Language | Test File Patterns |
|----------|-------------------|
| Python | `tests/test_{module}.py`, `{module}_test.py`, `tests/unit/test_{module}.py` |
| TypeScript/JavaScript | `__tests__/{module}.test.ts`, `{module}.spec.ts`, `{module}.test.tsx` |
| Rust | `tests/{module}.rs`, `mod tests` in same file |
| Go | `{module}_test.go` in same package |

## Verification Checklist

When this hook triggers, consider:

- [ ] Does a test file exist for this module?
- [ ] Do tests cover the function/method I just modified?
- [ ] Are both success and failure paths tested?
- [ ] Are edge cases handled (null, empty, boundary values)?
- [ ] If I added new public API, is it tested?

## When to Ignore

This reminder can be safely ignored when:
- You're making documentation-only changes
- The file is a configuration or data file
- You plan to write tests in a follow-up commit
- The module is explicitly excluded from testing

## Customization

To customize this hook for your project:
1. Adjust the `pattern` to match your source file locations
2. Update the test file conventions to match your project structure
3. Add project-specific testing requirements to the checklist
