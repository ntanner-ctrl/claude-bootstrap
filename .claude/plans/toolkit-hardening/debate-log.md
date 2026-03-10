# Debate Log — toolkit-hardening

---

## Stage 4: Edge Cases (Debate Mode)

### Round 1: Boundary Explorer

Mapped boundaries across 4 categories:
- **Input boundaries:** Empty commands, whitespace-only, max-length, malformed JSON stdin
- **State boundaries:** Signal file transitions (warning↔critical↔clean), counter rollover, PPID recycling
- **Concurrency boundaries:** Simultaneous sessions, mid-write signal reads, statusline/guardian race
- **Time boundaries:** TTL edge cases, clock skew (WSL↔NTFS), DST transitions

### Round 2: Stress Tester + Round 3: Synthesizer

**Verdict: PASS_WITH_NOTES** — 0 critical, 2 medium (fixed), 5 low (4 fixed, 1 accepted)

#### Required Spec Updates (Applied)

| ID | Priority | Severity | Finding | Fix |
|----|----------|----------|---------|-----|
| B1 | 1 | Medium | Red gate says "blocks Bash calls" but criterion 6 says "no-op for non-test" — contradiction | Clarified: Red blocks matched test/build commands only |
| B5 | 2 | Medium | /debug reset mechanism reads state-index.json — race conditions, file may not exist | Added signal file `/tmp/.claude-debug-reset-<PPID>` pattern |
| B8 | 3 | Low | "300ms polling" is imprecise — statusline is event-driven, not self-polling | Corrected to "event-driven, invoked per status cycle" |
| B2 | 4 | Low | Cleanup threshold `< 65` leaves stale critical files when context is 65-74% | Changed to `< 75` for cleanup |
| B7 | 7 | Low | Checkpoint JSON partial reads possible if guardian reads mid-write | Added atomic write requirement (write-to-temp-then-rename) |

#### Acceptable Risk (Documented)

| ID | Priority | Finding | Why Acceptable |
|----|----------|---------|----------------|
| B3 | 5 | Compound commands (`cd && npm test`) miss prefix match | Parsing compound shell is fragile; prefix catches common case |
| B4 | 6 | Piped commands may report wrong exit code | Can't control user's pipefail; false-negative is harmless |
| B6 | 8 | First tool call before statusline update — no signal files yet | Sub-second window; guardian no-ops when no files exist |

---

## Stage 3: Challenge (Debate Mode)

# Debate Log — toolkit-hardening (Stage 3: Challenge)

## Round 1: Challenger

### F1 (Critical→High): PPID fallback eliminates session isolation
Two simultaneous sessions share fixed-path signal files. Worst case: one session's guardian blocks on another's checkpoint state.

### F2 (High→Critical): Guardian deadlock — matcher:* blocks ALL tool calls
The subagent dispatch the guardian recommends is itself a tool call, which the guardian blocks. Self-defeating escalation path.

### F3 (High): Failure counter catchall pattern too broad
`test -f`, `build/run.sh` match the catchall. Four false positives trigger Red-level block on all Bash.

### F4 (High→Medium): Ambiguity gate self-scoring uncalibrated
No calibration anchors for mid-range scores. Claude may rationalize in the contested 2.5-3.5 zone.

### F5 (High): Promote-finding evidence trail self-referential
Three "observations" can all be Claude's own notes. No independence check required.

### F6 (Medium): Wonder/Reflect has no consumption path
Empirica logging and vault export are both conditional. reflect.md files accumulate unread.

### F7 (Medium): key_context_summary written under duress
At 75% context, open-ended summary with no length/structure. Written by degraded-context Claude.

### F8 (Medium→Low): Cognitive trap tables unenforceable
Behavioral guidance, not enforcement. Disputed — Defender argues tables complement shell hooks.

### F9 (Medium→Low): blueprint.md coordination across phases
4 components touch same file. Defender: Component 3 is frontmatter, 2+5 are serialized. Needs atomic-pass note.

### F10 (Low): No signal file cleanup after crashes
Stale files persist. Low probability of PPID reuse. TTL check would mitigate.

## Round 2: Defender

Confirmed VALID: F2, F3, F5, F6, F7, F10
Rated OVERSTATED: F1, F4, F8, F9

### New Findings
- M1 (Critical): Subagent dispatch mechanism undefined — same root as F2
- M2 (Medium): statusline.sh CTX_INT availability unverified
- M3 (High): "Recent checkpoint" detection completely unspecified
- M4 (Medium): Phase D has no end-to-end integration test
- M5 (Medium): Light path exemption from ambiguity gate may be counterproductive

## Round 3: Judge Verdict

**REGRESS** — 2 critical findings (F2+M1 are same root cause), spec cannot be implemented as written for Component 1.

### Final Severity Ratings

| ID | Severity | Convergence | Addressed |
|----|----------|-------------|-----------|
| F1 | High | Disputed | Needs spec update |
| F2 | **Critical** | Both agreed | **Needs new section** |
| F3 | High | Both agreed | Needs spec update |
| F4 | Medium | Disputed | Needs spec update |
| F5 | High | Both agreed | Needs spec update |
| F6 | Medium | Both agreed | Needs spec update |
| F7 | Medium | Both agreed | Needs spec update |
| F8 | Low | Disputed | Already in spec |
| F9 | Low | Disputed | Needs spec update |
| F10 | Low | Both agreed | Needs spec update |
| M1 | **Critical** | Newly identified | **Needs new section** |
| M2 | Medium | Newly identified | Needs spec update |
| M3 | High | Newly identified | **Needs new section** |
| M4 | Medium | Newly identified | Needs new section |
| M5 | Medium | Newly identified | Needs spec update |
