# Pre-Mortem: plugin-enhancers

## Premise
This plan was implemented and deployed two weeks ago. It failed. This is the post-mortem.

## Focus
OPERATIONAL failures only — deployment, maintenance, observability, lifecycle. Design failures were caught in Stages 3-4.

---

## Most Likely Single Cause of Failure

**Registry staleness from plugin version drift.** The registry (`plugin-enhancers.md`) is a static file mapping plugin names to agent names. When pr-review-toolkit releases v2.0 with renamed agents, the registry still references v1.x names. Dispatch fails silently → 5-minute timeout × 3 agents → circuit breaker trips → user sees "plugins unavailable" with no explanation of WHY.

**Classification: NEW** — Related to F2 (registry maintenance) but focused on the runtime experience, not the update mechanism.

---

## Findings

### PM-1: Registry staleness causes silent 15-minute timeout cascade [NEW]
**Impact:** high | **Likelihood:** uncommon

When pr-review-toolkit updates agents, the registry references stale names. Each dispatch attempt times out at 5 minutes. With 3 attempts before circuit breaker, that's 15 minutes wasted.

**Spec mitigations:** Graceful degradation handles the individual failures. Circuit breaker (NEW-4) stops the cascade. But user experience is poor — 15 minutes of waiting for a "plugins unavailable" message.

**Recommendation:** Add fast-fail validation before full dispatch. Attempt a 10-second "probe" dispatch for one agent before committing to 6 parallel 5-minute dispatches.

### PM-2: install.sh upgrade silently overwrites user customizations [NEW]
**Impact:** medium | **Likelihood:** uncommon

`install.sh` uses `tar --overwrite` to copy files. If a user has manually customized `blueprint.md` or `review.md`, those changes are silently replaced.

**Not plugin-enhancers-specific** — this is a general install.sh concern. But plugin-enhancers makes it worse because it modifies 3 existing commands (blueprint, review, dispatch).

**Recommendation:** Document in GETTING_STARTED.md that `install.sh` is a destructive overwrite. Phase 2 could add `install.sh --dry-run`.

### PM-3: Circuit breaker has no reset mechanism [NEW]
**Impact:** medium | **Likelihood:** rare

Finding NEW-4 defined the circuit breaker (3 failures → abort). But doesn't define reset.

**In this architecture:** Circuit breaker state lives in Claude's working memory for the current session. It resets automatically when the session ends and a new one begins. This is fine for Phase 1.

**Recommendation:** Document that circuit breaker is session-scoped (resets on session end). If Phase 2 persists it to state.json, add TTL (1 hour).

### PM-4: Modified commands reference plugin-enhancers.md with no existence check [NEW]
**Impact:** medium | **Likelihood:** rare

If user downgrades bootstrap or manually deletes `plugin-enhancers.md`, the modified commands still contain plugin integration sections. These sections try to read the registry file.

**In this architecture:** The commands instruct Claude to "read plugin-enhancers.md." If the file doesn't exist, Claude's Read tool returns an error. The command instructions should include a fallback: "If file not found, skip plugin integration."

**Recommendation:** Add explicit existence check to each modified command's plugin integration section.

### PM-5: No observability for plugin detection failures [NEW]
**Impact:** low | **Likelihood:** uncommon

When detection fails (file missing, timeout, parse error), the user sees nothing. The logging protocol (Finding F9) defines the format but log destinations are ephemeral (Empirica session, stderr).

After the session ends, there's no persistent record of detection failures. A user experiencing repeated failures has no diagnostic trail.

**Recommendation:** Phase 2 consideration — add persistent log file at `~/.claude/logs/plugin-enhancers.log` for detection failures.

### PM-6: Timeout hierarchy mismatch — detection fast-fails but dispatch slow-fails [NEW]
**Impact:** low | **Likelihood:** rare

Detection timeout: 3 seconds (fast-fail, conservative). Agent dispatch timeout: 5 minutes × up to 3 attempts = 15 minutes (slow-fail, expensive).

In environments where detection works but dispatch consistently fails (e.g., broken plugin, rate limiting), the user waits 15 minutes for a failure that was predictable after the first 5-minute timeout.

**Already mitigated by:** Circuit breaker (NEW-4) stops after 3 failures. But user still waits up to 15 minutes.

**Recommendation:** Consider reducing dispatch timeout for Phase 1 from 5 minutes to 3 minutes (review agents shouldn't need more for a spec review).

---

## Overlap Assessment

| Finding | Overlap with Adversarial | Type |
|---------|-------------------------|------|
| PM-1 (registry staleness) | F2 (maintenance) + NEW-4 (circuit breaker) — related but new angle | NEW |
| PM-2 (install overwrite) | None — general install.sh concern | NEW |
| PM-3 (circuit breaker reset) | NEW-4 (defined mechanism) — extends with reset question | NEW |
| PM-4 (orphaned references) | None — downgrade scenario not covered | NEW |
| PM-5 (observability) | F9 (logging protocol) — extends with persistence question | NEW |
| PM-6 (timeout hierarchy) | M3 (detection timeout) — extends with cost analysis | NEW |

**COVERED findings: 0 / NEW findings: 6**
**Overlap ratio: 0.0 (low)** — pre-mortem surfaced genuinely new operational concerns.

---

## Retrospective Recommendations (by phase)

### Phase 1 (implement with current spec):
1. Add fast-fail probe before full dispatch (PM-1) — 10-second test dispatch of one agent
2. Add registry file existence check in each modified command (PM-4)
3. Document circuit breaker is session-scoped (PM-3)
4. Document install.sh overwrite behavior (PM-2)

### Phase 2:
5. Persistent detection failure logging (PM-5)
6. Dispatch timeout tuning based on Phase 1 data (PM-6)
7. install.sh --dry-run mode (PM-2)
8. Circuit breaker TTL if persisted to state.json (PM-3)

---

## Impact on Regression Decision

**No regression needed.** All 6 findings are:
- Operational polish (not architectural gaps)
- Addressable during implementation (W1-W5)
- Mitigated by existing graceful degradation patterns

The most impactful recommendation (PM-1: fast-fail probe) can be added to the W1-review gate instructions without spec changes.
