# Verification Tests: toolkit-wiring-matrix

## T1: Zero orphan commands
```bash
# Every command should have at least 1 inbound reference from another command (excluding README and self)
for cmd in vault-query approve; do
  count=$(grep -rl "/$cmd" commands/*.md | grep -v README | grep -v "^commands/${cmd}.md$" | wc -l)
  if [ "$count" -eq 0 ]; then echo "FAIL: /$cmd still orphaned (0 inbound refs)"; else echo "PASS: /$cmd has $count inbound refs"; fi
done
```

## T2: Insight capture on audit commands
```bash
for cmd in security-checklist design-check requirements-discovery; do
  if grep -q "collect-insights" "commands/${cmd}.md"; then echo "PASS: $cmd has collect-insights ref"; else echo "FAIL: $cmd missing collect-insights"; fi
done
```

## T3: Frontend in review Stage 5
```bash
if grep -q "frontend" commands/review.md; then echo "PASS: frontend in review.md"; else echo "FAIL: frontend missing from review.md Stage 5"; fi
```

## T4: Frontend in blueprint Stage 5
```bash
# Check the Stage 5 options section specifically
if grep -q "frontend:reviewer" commands/blueprint.md; then echo "PASS: frontend:reviewer in blueprint.md"; else echo "FAIL: frontend:reviewer missing from blueprint Stage 5"; fi
```

## T5: Delegate extended lens table
```bash
count=$(grep -c "pr-review-toolkit\|security-pro\|performance-optimizer\|superpowers\|feature-dev" commands/delegate.md)
if [ "$count" -ge 5 ]; then echo "PASS: delegate.md has extended lens entries ($count)"; else echo "FAIL: delegate.md missing extended lenses ($count)"; fi
```

## T6: Plugin-enhancers Phase 2 entries
```bash
for plugin in code-analysis testing-suite ralph-wiggum commit-commands git-workflow hookify; do
  if grep -q "$plugin" commands/plugin-enhancers.md; then echo "PASS: $plugin in registry"; else echo "FAIL: $plugin missing from registry"; fi
done
```

## T7: /start references vault-query and toolkit
```bash
if grep -q "vault-query" commands/start.md; then echo "PASS: start.md refs vault-query"; else echo "FAIL: start.md missing vault-query"; fi
if grep -q "toolkit" commands/start.md; then echo "PASS: start.md refs toolkit"; else echo "FAIL: start.md missing toolkit"; fi
```

## T8: /describe-change references requirements-discovery
```bash
if grep -q "requirements-discovery" commands/describe-change.md; then echo "PASS: describe-change refs requirements-discovery"; else echo "FAIL: describe-change missing requirements-discovery"; fi
```

## T9: /status references approve
```bash
if grep -q "approve" commands/status.md; then echo "PASS: status.md refs approve"; else echo "FAIL: status.md missing approve"; fi
```

## T10: process-doc dead links fixed
```bash
# Should NOT reference /tutorial-doc, /reference-doc, /explanation-doc as commands
if grep -q "/tutorial-doc\|/reference-doc\|/explanation-doc" commands/process-doc.md; then echo "FAIL: process-doc still has dead command links"; else echo "PASS: process-doc dead links removed"; fi
```

## T11: Advisory language for plugin suggestions
```bash
# Check that new plugin references use advisory language (spot check)
if grep -q "Also available\|user-initiated" commands/debug.md; then echo "PASS: debug.md uses advisory language"; else echo "FAIL: debug.md missing advisory language"; fi
```

## T12: /end cross-references /collect-insights
```bash
if grep -q "collect-insights" commands/end.md; then echo "PASS: end.md refs collect-insights"; else echo "FAIL: end.md missing collect-insights ref"; fi
```

## T13: /collect-insights cross-references /end
```bash
if grep -q "/end" commands/collect-insights.md; then echo "PASS: collect-insights refs /end"; else echo "FAIL: collect-insights missing /end ref"; fi
```

## T14: Delegate sync comment
```bash
if grep -q "mirrors dispatch" commands/delegate.md; then echo "PASS: delegate.md has sync comment"; else echo "FAIL: delegate.md missing sync comment"; fi
```

## T15: Command count stable
```bash
count=$(ls commands/*.md | grep -v README | wc -l)
if [ "$count" -eq 46 ]; then echo "PASS: command count is 46"; else echo "FAIL: command count is $count (expected 46)"; fi
```

## T16: Max suggestions rule check (spot check blueprint completion)
```bash
# Count plugin suggestions in blueprint completion section — should be ≤3 total new additions
# This is a manual review checkpoint, not automatable with simple grep
echo "MANUAL: Review blueprint.md completion section for suggestion density"
```
