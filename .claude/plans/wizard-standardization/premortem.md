# Pre-Mortem: wizard-standardization

**Premise:** Implemented, installed, and deployed 2 weeks ago. Something failed.

## Findings

### F1: Install Overwrites User Customizations
**Status:** COVERED — install.sh tarball extraction is existing behavior. Users don't customize command files.

### F2: Cognitive Traps Increase Command File Size
**Status:** NEW — Low impact. ~15% size increase for smallest wizard (/clarify), negligible for large ones.
**Impact:** Low. Within normal variance.

### F3: Vault Awareness Adds WSL I/O Latency
**Status:** NEW — Three wizards now Grep against vault path on every invocation. WSL-to-Windows I/O on `/mnt/c/` paths can be slow (1-3 seconds per search).
**Impact:** Medium. Fail-open design means never blocks, but adds perceptible delay.
**Mitigation:** Document in Known Limitations that vault awareness may add latency on WSL mounts.

### F4: Pre-Mortem Regression Warning UX Not Specified
**Status:** NEW — On Full path, skipping pre-mortem now fires a regression warning before Stage 5. The spec defines the mechanism but not the warning text. Poorly worded warning could confuse users.
**Impact:** Medium.
**Mitigation:** Add draft regression warning text to WU-1 spec:
```
⚠️ Pre-mortem was skipped on Full path.
  Stage 4.5 surfaces operational failures that design review (Stages 3-4) doesn't catch.
  Reason logged: "[user's skip reason]"

  Proceed to Stage 5 anyway? (Y/n)
```

### F5: README Cross-Listing Creates Discovery Confusion
**Status:** NEW — /prism in both Workflow Wizards and Quality.
**Impact:** Low. Minor UX — add inline note "(also listed under Quality)".

### F6: Manual Structural Checklist Gets Skipped (CRITICAL)
**Status:** NEW — WU-8's manual structural checklist is the only verification for section presence. In practice, implementers will run test.sh, see green, and skip the manual check. The structural guarantees of this entire sprint rest on a manual process.
**Impact:** HIGH. Most likely operational failure.
**Mitigation:**
  1. Add structural section grep checks to test.sh Category 4 as part of this sprint (not deferred)
  2. Checks: grep each wizard file for `Cognitive Traps`, `Failure Modes`, `Known Limitations`, `vault-config.sh`
  3. This converts the manual checklist into automated enforcement

### F7: Vault Search Returns Stale Prior Art
**Status:** COVERED (edge case 2.2). Advisory only, not gating.

## Summary

| Finding | Status | Impact | Action |
|---------|--------|--------|--------|
| F1 Install overwrites | COVERED | — | None |
| F2 File size increase | NEW | Low | None |
| F3 WSL I/O latency | NEW | Medium | Document in Known Limitations |
| F4 Warning UX missing | NEW | Medium | Add draft warning text to WU-1 |
| F5 Cross-listing confusion | NEW | Low | Add inline note to README |
| F6 Manual checklist skipped | NEW | **HIGH** | **Convert to test.sh checks** |
| F7 Stale vault results | COVERED | Low | None |

## Critical Finding: F6

The pre-mortem identified that the manual structural checklist in WU-8 is the weakest link in the operational chain. This is an operational failure that design review didn't catch because it's not a design flaw — it's a deployment discipline gap.

**Recommendation:** Add a WU-8a that extends test.sh Category 4 with wizard structural section checks. This converts the manual gate into automated enforcement, consistent with the toolkit's principle that deterministic checks beat behavioral guidance.
