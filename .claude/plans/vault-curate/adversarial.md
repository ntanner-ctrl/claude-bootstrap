# Adversarial Review: vault-curate

## Debate Mode — 3 Rounds (Challenger → Defender → Judge)

### Verdict: REGRESS (2 critical findings)

### Critical Findings (must fix)

| ID | Finding | Convergence |
|----|---------|-------------|
| F2 | Merge findings destroys source notes — no backup, no undo, no defined behavior | both-agreed |
| F20 | Merge findings output format/template/destination completely unspecified | both-agreed |

### High Findings (should fix)

| ID | Finding | Convergence |
|----|---------|-------------|
| F1 | No atomicity in Stage 5 Prune — partial apply on crash | disputed (Defender: not corruption, just incomplete) |
| F4 | Reading 500+ notes frontmatter exceeds context window — no batching strategy | both-agreed |
| F5 | Health score formula broken — unassessed notes cause floor at 0 | both-agreed |
| F7 | --project flag has no defined matching logic | both-agreed |
| F8 | Stage 3 triage state not persisted — session crash loses all verdicts | both-agreed |

### Medium Findings (should fix where practical)

| ID | Finding | Convergence |
|----|---------|-------------|
| F6 | Superseded detection for Decisions undefined | disputed |
| F9 | Conversation mode vs structured verdict — no switching protocol | disputed |
| F10 | Archived flag not filtered in Stage 1 scan | both-agreed |
| F11 | Blueprint orphan detection requires unknown project roots | disputed |
| F12 | Frequency recommendation uses bad proxy metric | both-agreed |
| F13 | Synthesis on incomplete triage corpus produces false gaps | both-agreed |
| F14 | one_tier_sooner() undefined pseudocode | both-agreed |
| F15 | Read-only vault detection deferred until Stage 5 | disputed |
| F21 | Skipped notes get no frontmatter tracking | both-agreed |
| F22 | --section flag not integrated into Stage 2 | both-agreed |
| F23 | No handling for malformed YAML frontmatter | both-agreed |
| F24 | Stage 6 before/after requires Stage 2 baseline that may not exist | both-agreed |

### Low Findings (nice to fix)

| ID | Finding | Convergence |
|----|---------|-------------|
| F3 | git rev-parse silent failure outside git repo | disputed |
| F16 | --quick backwards-compat claim misleading | both-agreed |
| F17 | Empirica deadend_log semantically wrong for archives | both-agreed |
| F18 | Age bucket "today" not anchored | both-agreed |
| F19 | Description tier doesn't match command impact | both-agreed |

---

## Edge Cases — Boundary Explorer (42 boundaries mapped)

### Critical Unspecified Boundaries (fixed in Revision 2)

| ID | Boundary | Risk | Fix Applied |
|----|----------|------|-------------|
| B-I-01/B-SC-09 | Division-by-zero in health score and frequency when 0 active notes | High | Zero guard: skip score, display "N/A" |
| B-S-01 | `notes_created_since_last_curation` undefined variable | Medium | Defined as count of notes with `date` after median assessed date |
| B-I-06/B-D-03/B-D-09 | Partial `empirica_*` field presence creates unclassifiable health states | High | Added "Partially assessed" category → treated as Unassessed/neutral |
| B-S-05 | Checkpoint > 24h behavior undefined | Medium | Added stale checkpoint prompt with discard/resume-anyway options |
| B-F-08 | `--section` with zero matching notes — no message | Low | Added zero-match message mirroring --project pattern |
| B-FS-01 | Checkpoint JSONL corrupted by special characters in paths | Medium | Added sed-based JSON escaping for paths |
| B-D-08 | `type` frontmatter vs directory mismatch — no authority defined | Medium | Directory is authoritative; type mismatch logged as warning |
| B-I-04 | No-frontmatter notes produce silent awk empty output | Medium | Extended malformed YAML handling to cover empty/absent frontmatter |

### Accepted Low-Risk Boundaries (not fixed)

- B-I-07: Extremely long note content during Stage 3 reads (bounded by Claude's natural summarization)
- B-D-02: Future dates produce negative ages (classified as "Fresh" — misleading but not harmful)
- B-D-06: Out-of-range confidence values (no validation — LLM will handle reasonably)
- B-FS-02: Very long paths (OS-level concern, not spec-level)
- B-F-05/B-F-06: Redundant flag combinations (no warning — harmless)
