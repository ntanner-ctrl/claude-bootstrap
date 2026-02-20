# Specification Revision History

## Revision 1 (initial)
- Created: 2026-02-20
- Sections: Overview, Command Signature, YAML Frontmatter, Vault Content Types, Stage 1-6, Quick Mode, Fail-Soft, Deprecation, Work Units, Work Graph
- Work Units: 7

## Revision 1 → Revision 2
- Trigger: Debate challenge (3 rounds) produced 2 critical + 5 high findings
- Date: 2026-02-20

### Sections modified:
- **YAML Frontmatter**: Description upgraded from Utility to note write impact (F19)
- **Stage 1 (Inventory)**: Major rewrite — added bulk bash extraction (F4/H1), archived filtering (F10/M1), anchored date (F18/L4), write-access check (F15/M8), project matching logic (F7/H4), section scoping (F22/NEW-3), malformed YAML handling (F23/NEW-4), scale warning (F6/M6), git rev-parse null guard (F3/L3)
- **Stage 2 (Health Check)**: Added --section scoping (F22), fixed health score formula (F5/H2), clarified superseded detection reasoning requirement (F6/H3)
- **Stage 3 (Triage)**: Added checkpoint/resume mechanism (F8/H5), verdict closure protocol for conversation mode (F9/H6), last_reviewed on skip (F21/NEW-2)
- **Stage 4 (Synthesis)**: Added full-vault-state caveat for partial triage (F13/M4), added Merge Findings subsection with full semantics (F2/C2, F20/NEW-1), inlined meta-finding creation (removed /vault-save coupling, F3/L3)
- **Stage 5 (Prune)**: Fixed Empirica logging — archives use finding_log not deadend_log (F17/L2), added Interruption Recovery section (F1/H1)
- **Stage 6 (Report)**: Conditional health comparison when Stage 2 skipped (F24/NEW-5), fixed frequency metric to use median (F12/M3), inlined one_tier_sooner logic (F14/M7), added never-assessed fraction note
- **Quick Mode**: Removed misleading backwards-compat claim (F16/L1)
- **Fail-Soft**: Updated read-only vault detection to Stage 1 (F15/M8)

### Sections added:
- Triage Checkpoint (Persistence) — new subsection in Stage 3
- Merge Findings — new subsection in Stage 4
- Interruption Recovery — new subsection in Stage 5

### Sections unchanged:
- Overview, Command Signature, Vault Content Types table, Deprecation, Work Units, Work Graph

### Adversarial findings addressed: 24/24
