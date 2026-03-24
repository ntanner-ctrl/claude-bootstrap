# Describe: wizard-standardization

## Change Summary

Upgrade the Workflow Wizards category to ensure all members match the structural rigor of `/blueprint` and `/prism`. Three sub-goals:

1. **Add `/prism` to Workflow Wizards** — it follows the wizard pattern (multi-stage, guided, structured output) but is miscategorized under Quality
2. **Fix pre-mortem skippability** — remove optional labeling, remove overlap-based skip logic, make required on Full path
3. **Audit and upgrade `/review`, `/test`, `/clarify`** — ensure they match the paradigms established by `/blueprint` and `/prism`

## Steps (Decomposed)

1. Audit all 5 wizard commands against blueprint/prism patterns (read-only analysis)
2. Fix pre-mortem skippability in `blueprint.md` (remove optional label, remove overlap detection skip logic, change path rules)
3. Upgrade `/review` to match blueprint/prism structural patterns (conditional on audit)
4. Upgrade `/test` to match blueprint/prism structural patterns (conditional on audit)
5. Upgrade `/clarify` to match blueprint/prism structural patterns (conditional on audit)
6. Update `README.md` — add `/prism` and `/clarify` to Workflow Wizards line
7. Update `commands/README.md` — add `/prism` to Workflow Wizards table
8. Run `bash test.sh` to verify nothing broke

## Risk Flags

None. Internal documentation/command authoring only.

## Triage Result

- **Steps:** 8 (3 conditional on step 1 findings)
- **Risk flags:** None
- **Path:** Full (user preference — "quality in, quality out")
- **Execution preference:** Auto
