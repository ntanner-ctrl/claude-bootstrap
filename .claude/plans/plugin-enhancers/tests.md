# Test Criteria: plugin-enhancers (Phase 1)

> **Generated spec-blind** — tests derived from spec.md and adversarial.md without seeing implementation.
> Some agent/slot names may need alignment during implementation — test structure and coverage patterns are authoritative.

## Priority Summary

| Priority | Count | Description |
|----------|-------|-------------|
| P0 (Blocker) | 14 | Must pass — detection, preservation, zero-plugin behavior |
| P1 (Critical) | 12 | Core functionality — conditional display, circuit breaker, dispatch |
| P2 (Important) | 12 | User experience — timeouts, logging, tip lines, docs |
| P3 (Nice-to-have) | 30 | Edge cases, structural validation |
| **Total** | **68** | |

## P0: Blocker Tests (Must Pass)

### Detection
- **T-REGISTRY-002**: Detection reads `installed_plugins.json` and matches by prefix before `@`
- **T-REGISTRY-003**: Missing `installed_plugins.json` → "no plugins", all features hidden
- **T-REGISTRY-005**: Exact prefix match, not substring (no collision between "pr-review" and "pr-review-toolkit")
- **T-REGISTRY-009**: Circuit breaker defined: 3 consecutive failures → abort remaining

### Zero-Plugin Preservation (Preservation Contract)
- **T-PRESERVE-001**: Blueprint without plugins runs identically to pre-enhancer
- **T-PRESERVE-002**: `/review` without plugins runs identically
- **T-PRESERVE-003**: `/dispatch` without plugins runs identically
- **T-PRESERVE-004**: No new required directories/files (only `plugin-enhancers.md` added)
- **T-PRESERVE-005**: All existing command signatures unchanged
- **T-PRESERVE-006**: adversarial.md format preserved (plugin findings appended, not replacing)
- **T-PRESERVE-007**: Review summary format preserved (Deep Analysis is additive section)
- **T-PRESERVE-008**: No performance regression when plugins absent (<1s detection overhead)

### Results
- **T-BLUEPRINT-003**: Dynamic numbering with zero plugins — only GPT review + Skip shown
- **T-BLUEPRINT-011**: Plugin results appended to adversarial.md under "Plugin Review Findings" with `[plugin-review]` tags

## P1: Critical Tests (Core Functionality)

### Conditional Display
- **T-BLUEPRINT-004**: With pr-review-toolkit → shows plugin option between GPT review and Skip
- **T-REVIEW-002**: Stage 5 NOT shown when `review:specialized` slot unfilled
- **T-REVIEW-003**: Stage 5 shown when slot is filled
- **T-REVIEW-004**: Quick mode (`--quick`) skips plugin stages entirely
- **T-DISPATCH-002**: Extended lenses NOT shown when pr-review-toolkit absent
- **T-DISPATCH-003**: Extended lenses shown when pr-review-toolkit detected

### Dispatch & Circuit Breaker
- **T-BLUEPRINT-008**: Fast-fail probe (10-second test dispatch) before full parallel dispatch
- **T-BLUEPRINT-013**: Circuit breaker aborts remaining after 3 consecutive failures
- **T-BLUEPRINT-014**: Plugin findings are advisory — don't trigger regression logic
- **T-INTEGRATION-003**: Circuit breaker state shared across blueprint/review/dispatch

### Error Handling
- **T-DISPATCH-004**: Missing plugin → clear message, not error
- **T-EDGE-004**: Partial failures (2/6 agents fail) → 4 results collected, circuit breaker NOT triggered

## P2: Important Tests (User Experience)

### Timeouts
- **T-REGISTRY-004**: Detection timeout enforced at 3 seconds
- **T-BLUEPRINT-010**: Agent timeout enforced at 5 minutes per agent
- **T-BLUEPRINT-012**: Results truncated at 2000 tokens with `[truncated]` note

### Logging
- **T-LOGGING-001**: Detection log format: `[PLUGIN] Detection: found <plugin>@<version>`
- **T-LOGGING-002**: Dispatch log format: `[PLUGIN] <plugin>:<agent> dispatched`
- **T-LOGGING-003**: Timeout log format: `[PLUGIN] <plugin>:<agent> timeout: 5m exceeded`
- **T-LOGGING-004**: Circuit breaker log: `[PLUGIN] Circuit breaker: 3 consecutive failures`
- **T-LOGGING-005**: Success log: `[PLUGIN] <plugin>:<agent> completed: <tokens> tokens`
- **T-LOGGING-006**: Failure log: `[PLUGIN] <plugin>:<agent> failed: <reason>`

### Documentation
- **T-DOCS-001**: README command count updated
- **T-DOCS-005**: Documentation clear for zero-plugin users
- **T-DISPATCH-005**: Tip line shown after standard review when pr-review-toolkit detected

## P3: Nice-to-Have Tests (Edge Cases & Structural)

### Edge Cases
- **T-EDGE-001**: Corrupted JSON → falls back to "no plugins", no crash
- **T-EDGE-002**: Empty plugins array → same as missing file
- **T-EDGE-005**: All 6 agents timeout → circuit breaker triggers
- **T-EDGE-006**: Agent returns empty output → treated as success, nothing appended
- **T-EDGE-007**: Duplicate plugin entries → deduplicated by prefix
- **T-EDGE-008**: Two plugins claim same slot → alphabetical ordering per spec

### Structural
- **T-STRUCTURAL-001**: `plugin-enhancers.md` has correct YAML frontmatter
- **T-STRUCTURAL-002**: Modified commands maintain original structure
- **T-STRUCTURAL-003**: All plugin logs use consistent `[PLUGIN]` prefix
- **T-STRUCTURAL-005**: Documentation cross-references resolve

### Integration
- **T-INTEGRATION-001**: Plugin findings from blueprint visible in subsequent review
- **T-INTEGRATION-005**: Mixed availability — some slots filled, others empty, no errors

---

## Verification Method

Since this is a markdown-command system, tests are verified via:
1. **File inspection**: Grep/read commands to verify structural tests (T-STRUCTURAL, T-DOCS)
2. **Live session**: Run commands in Claude Code session to verify behavioral tests (T-BLUEPRINT, T-REVIEW, T-DISPATCH)
3. **Scenario replay**: Set up specific `installed_plugins.json` states and run commands to verify conditional behavior
4. **Diff comparison**: Compare pre/post command output for preservation tests (T-PRESERVE)

## Implementation Notes from Adversarial Stages

These findings should be verified as addressed during testing:

| Source | Finding | Test That Covers It |
|--------|---------|---------------------|
| NEW-4 | Circuit breaker | T-REGISTRY-009, T-BLUEPRINT-013, T-INTEGRATION-003 |
| EC-4 | Unregistered plugin logging | T-LOGGING-001 (detection log should mention unregistered plugins) |
| EC-8 | Prefix collision | T-REGISTRY-005 |
| EC-18 | Agent name mismatch | T-DISPATCH-004, T-EDGE-004 |
| PM-1 | Fast-fail probe | T-BLUEPRINT-008 |
| PM-4 | Registry existence check | T-REGISTRY-003 |
