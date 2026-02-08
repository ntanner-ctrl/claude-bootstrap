# Adversarial Findings: plugin-enhancers

## Debate Chain Round 1 (Stage 3: Challenge — Rev 0)
Mode: debate | Rounds: 3 (Challenger → Defender → Judge)

### Verdict: REGRESS → Stage 2 (Specify)
Critical count: 2 | Regression target: specify

---

## Critical Findings (Rev 0 — Both RESOLVED in Rev 1)

### F1: Detection mechanism undefined
**Severity:** critical | **Convergence:** both-agreed | **Status:** RESOLVED in Rev 1
Resolved via canonical detection protocol using `~/.claude/plugins/installed_plugins.json`.

### F2: Registry maintenance — hand-maintained, no owner, will desync
**Severity:** critical | **Convergence:** both-agreed | **Status:** RESOLVED for Phase 1 (fragile at scale — Phase 2 prerequisite)
Resolved via bootstrap-owned maintenance model with `tested_with` versions and PR-based updates.

---

## High Findings (Rev 0 — All RESOLVED in Rev 1)

### F4: Backwards compatibility underspecified
**Status:** RESOLVED — Schema versioning with additive optional fields, migration rules, 4 backward compat test cases.

### F6: Failure modes incomplete
**Status:** RESOLVED — Expanded from 6 to 15 scenarios across 4 categories.

### M1: No rollback strategy for failed plugin executions
**Status:** DEFERRED to Phase 2 (correctly scoped — Phase 1 is review-only, no execution).

---

## Medium Findings (Rev 0 — All RESOLVED or DEFERRED)

| ID | Finding | Status |
|----|---------|--------|
| F3 | Context pollution | Already in spec (opt-in design) |
| F5 | "No dependencies" misleading | RESOLVED — renamed to "No Package Dependencies" |
| F7 | Technology detection naive | DEFERRED to Phase 2 |
| F8 | Work units optimistic | RESOLVED — W1-review gate added |
| F9 | Graceful degradation logs undefined | RESOLVED — logging protocol defined |
| F10 | Scope too broad for v1 | RESOLVED — phased rollout |
| F11 | Advisory semantics unclear | RESOLVED — explicit definition |
| M2 | Context handoff undefined | DEFERRED to Phase 2 |
| M3 | Detection synchronous/blocking | RESOLVED — 3-second timeout |
| M4 | Priority/ordering undefined | RESOLVED — alphabetical ordering |

## Low Findings (Rev 0)

| ID | Finding | Status |
|----|---------|--------|
| F12 | Documentation scope underestimated | RESOLVED — 4 files listed |
| M5 | No plugin update notifications | DEFERRED (Phase 2) |
| M6 | Slot naming collisions | DEFERRED (Phase 2) |
| M7 | Per-project plugin disable | DEFERRED (Phase 3) |

---

## Debate Chain Round 2 (Stage 3: Revalidation — Rev 1)
Mode: debate | Rounds: 3 (Challenger → Defender → Judge)

### Verdict: PASS_WITH_NOTES
Critical count: 0 | No regression needed

---

## New Findings from Revalidation

### NEW-4: No circuit breaker for repeated failures
**Severity:** medium | **Convergence:** both-agreed | **Addressed:** needs-spec-update

If a plugin is broken and EVERY agent dispatch fails, the user sees N consecutive "unavailable" messages. After 3 consecutive failures from the same plugin in a single workflow invocation, abort remaining agents for that plugin.

**Required mitigation:** Add circuit breaker rule to Graceful Degradation Rules:
- 3 consecutive failures → skip remaining agents
- Log: "[PLUGIN] Circuit breaker triggered after 3 failures"
- Show user one consolidated message

### NEW-1: Agent-level detection gap
**Severity:** medium | **Convergence:** both-agreed | **Addressed:** already-in-spec (handled by graceful degradation)

Plugin detected but specific agents may be missing if version changed. Current spec handles this via dispatch-failure → skip pattern. Explicit version checking deferred to Phase 2.

**Judge ruling:** Sufficient for Phase 1 — existing graceful degradation covers this. Add to Phase 2 prerequisites.

### M-NEW-1: Unavailability message format not standardized
**Severity:** low | **Convergence:** newly-identified | **Addressed:** needs-spec-update

Spec shows examples but doesn't mandate exact format. Standardize:
- Dispatch failed: "Note: [plugin]:[agent] unavailable (dispatch failed), skipping."
- Timeout: "Note: [plugin]:[agent] unavailable (timeout after 5min), skipping."
- Circuit breaker: "Plugin enhancements temporarily disabled due to repeated failures."

### M-NEW-2: Plugin installation docs reference missing
**Severity:** low | **Convergence:** newly-identified | **Addressed:** needs-spec-update

Documentation should reference how to install plugins for users who don't have them.

### Dismissed/Overstated Findings

| ID | Severity | Ruling | Reason |
|----|----------|--------|--------|
| NEW-2 | low | Overstated | Token limit already enforced via truncation; agents should front-load findings |
| NEW-3 | low | Already addressed | Detection timeout already in spec (3-second) |
| NEW-5 | low | Overstated | Advisory semantics already explicitly defined in spec |
| NEW-6 | false | Dismissed | Task tool handles rate limiting internally |
| NEW-7 | low | Overstated | Multi-perspective overlap is expected; dedup is display-layer concern |
| NEW-8 | low | Deferred | Registry extensibility is Phase 2 concern |
| NEW-9 | low | Trivial | Atomic write is implementation detail, not spec requirement |
| NEW-10 | low | Overstated | `tested_with` is human-readable documentation, not automation target |
| M-NEW-3 | low | Deferred | Plugin version rollback is Phase 2 scope |

---

## Implementation Notes

The following should be incorporated during implementation (W1-W5), not via spec regression:

1. **Circuit breaker** (NEW-4): Add rule 7 to Graceful Degradation Rules in `plugin-enhancers.md`
2. **Unavailability messages** (M-NEW-1): Standardize formats in `plugin-enhancers.md`
3. **Installation reference** (M-NEW-2): Add plugin install note in documentation (W5)
4. **Phase 2 prerequisites** (NEW-1, F2 scalability): Note agent-level version checking and registry extensibility

---

## Edge Case Analysis (Stage 4)
Mode: debate | Rounds: 3 (Boundary Explorer → Stress Tester → Synthesizer)

### Verdict: PASS_WITH_NOTES
Critical count: 0 | No regression needed
Boundaries analyzed: 23 (11 fully specified, 3 partially, 9 unspecified)

### Key Insight

Stress Tester over-estimated severity by applying traditional-app security thinking to a markdown-command system. In bootstrap's architecture, Claude is the executor — it serializes writes, Task tool validates agent names server-side, and there's no shell execution from plugin names. Real Phase 1 risks are UX/logging issues, not security vulnerabilities.

### Medium Findings (4 spec updates for implementation)

### EC-4: Plugin installed but not in registry — silently skipped
**Severity:** medium | **Likelihood:** uncommon | **Priority:** P2
Plugin is in `installed_plugins.json` but has no entry in `plugin-enhancers.md`. Current behavior: slot not offered, no indication to user.
**Fix:** Add logging in detection protocol: `[PLUGIN] {name} installed but not in registry; skipping`

### EC-8: Prefix collision in plugin name matching
**Severity:** medium | **Likelihood:** rare | **Priority:** P2
If plugins "pr-review" and "pr-review-toolkit" both exist, substring matching could cause false positive.
**Fix:** Use exact key match on plugin name prefix (match before the `@` delimiter), not substring contains.

### EC-15: Malformed installed_plugins.json — parse error handling
**Severity:** medium | **Likelihood:** uncommon | **Priority:** P2
Already covered by Graceful Degradation rule #5, but error message could be more specific.
**Fix:** Log: `[PLUGIN] installed_plugins.json parse failed: {error}; skipping all enhancements`

### EC-18: Agent name mismatch — cryptic Task tool error
**Severity:** medium | **Likelihood:** uncommon | **Priority:** P2
When registry references an agent that doesn't exist in the installed version, Task tool returns a generic error.
**Fix:** Wrap dispatch in explicit error handling: `Note: {agent} not found; check plugin installation and registry accuracy`

### Low/Dismissed Findings

| Boundary | Finding | Ruling | Reason |
|----------|---------|--------|--------|
| B6 (special chars) | Path traversal in plugin names | Low/theoretical | Names used in string matching and Task tool calls, not shell commands; Task tool validates server-side |
| B12 (concurrent writes) | adversarial.md corruption | Low/theoretical | Claude serializes writes within a session; cross-session collision requires simultaneous blueprint runs |
| B10 (schema migration) | State unreadable after upgrade | Low/rare | Already specified: new fields optional, default to null; no breaking schema changes in Phase 1 |
| B16 (stale cache) | Stale detection data | Low/uncommon | Detection reads file fresh at each seam; no caching mechanism exists to go stale |
| B21 (version mismatch) | tested_with version drift | Low/uncommon | Already handled by graceful degradation on dispatch failure |
| B2 (file size) | Large installed_plugins.json OOM | Low/theoretical | File maintained by Claude Code; would need 10K+ plugins to approach timeout |
| B7 (plugin count) | Excessive plugins slow detection | Low/theoretical | 3-second timeout already bounds detection time |
| B18 (empty results) | Empty agent output unclear | Low/rare | Agent returning empty is indistinguishable from "no issues" — acceptable UX |
| B9 (mid-exec changes) | Plugin uninstalled during workflow | Low/theoretical | Detection happens per-seam; dispatch failure handled gracefully |
| B4 (empty name) | Empty string plugin name | Low/theoretical | installed_plugins.json maintained by Claude Code; won't contain empty keys |
| B5 (prefix collision) | Elevated to EC-8 above | — | — |
| B20 (not in registry) | Elevated to EC-4 above | — | — |

---

## Pre-Mortem (Stage 4.5)
Focus: Operational failures (deployment, maintenance, observability)

### Verdict: No regression needed
NEW findings: 6 | COVERED: 0 | Overlap ratio: 0.0 (low)

### Findings [pre-mortem]

| ID | Finding | Impact | Likelihood | Notes |
|----|---------|--------|------------|-------|
| PM-1 | Registry staleness causes 15-min timeout cascade | high | uncommon | Add fast-fail probe before full dispatch |
| PM-2 | install.sh upgrade silently overwrites customizations | medium | uncommon | Document overwrite behavior; general install.sh concern |
| PM-3 | Circuit breaker has no reset mechanism | medium | rare | Session-scoped (auto-resets); document this |
| PM-4 | Modified commands reference deleted registry file | medium | rare | Add existence check in each plugin integration section |
| PM-5 | No persistent observability for detection failures | low | uncommon | Phase 2: persistent log file |
| PM-6 | Timeout hierarchy mismatch (3s detect vs 15min dispatch) | low | rare | Consider reducing dispatch timeout to 3min |

### Implementation Actions
- PM-1: Add 10-second probe dispatch in W1-review gate before full parallel dispatch
- PM-4: Each modified command (W2, W3, W4) includes "if plugin-enhancers.md not found, skip" check
- PM-3: Document circuit breaker as session-scoped in plugin-enhancers.md (W1)
- PM-2: Add install.sh note in GETTING_STARTED.md (W5)
