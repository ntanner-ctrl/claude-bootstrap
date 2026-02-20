# Specification Revision History

## Revision 1 (initial)
- Created: 2026-02-18T11:30:00Z
- Sections: Summary, What Changes, Architecture, Configuration, Note Templates, Component Specs (W1-W10), Preservation Contract, Success Criteria, Failure Modes, Rollback Plan, Dependencies, Open Questions, Senior Review, Work Units
- Work Units: 10

## Revision 1 → Revision 2
- Trigger: Debate verdict REGRESS — 5 high-severity findings (marker PID mismatch, undefined session scoping, install overwrite, NTFS illegal chars, undefined vault_is_available())
- Date: 2026-02-18T12:00:00Z

### Sections modified:
- **Configuration (vault-config.sh):** Changed export marker from PID-scoped (`$$`) to per-UID per-date (`$(id -u)-$(date +%Y%m%d)`). Added session-start timestamp mechanism. Added `.example` install pattern. Added concrete `vault_is_available()` and `vault_sanitize_slug()` implementations.
- **W3 (/end command):** Clarified as Claude-executed skill (not shell). Added blueprint overwrite semantics (F11). NTFS-safe session summary filenames. Defined session summary content sources (F19). Clarified MCP vs direct access boundary (F17).
- **W4 (session-end-vault.sh):** NTFS-safe timestamps (HHMM, no colons). Project name sanitization via `vault_sanitize_slug()`. Fallback to `unknown-project` instead of pwd. Added `generated_by: safety-net` to frontmatter (NEW-4).
- **W5 (session-bootstrap.sh):** Session-start timestamp write. Portable `find` (no GNU `date -d`, no `-printf`). Added `timeout 2` and `-maxdepth 3`. Added `-not -name "CLAUDE.md"` exclusion (F24).
- **Note Templates:** Added deterministic wiki-link generation rules (F15). Links scoped to same export batch only.
- **Open Questions:** Pattern extraction changed to manual-only for v1 (F21 deferred).

### Sections unchanged:
- Summary, What Changes table, Vault Structure, Data Flow diagram, Preservation Contract, Success Criteria, Failure Modes, Rollback Plan, Dependencies, Senior Review, Work Units table

### Adversarial findings addressed: 17/32
- High: F1/NEW-3, F7, F10/F18/NEW-5, F12/NEW-1, F14 (all 5)
- Medium: F3, F4, F6, F9, F11, F13, F15, F19, F24, NEW-4 (10 of 11)
- Low: F17 (1, clarified MCP boundary)
- Deferred: F21 (pattern extraction to future)

### Work units affected:
- W2: Added `vault_is_available()`, `vault_sanitize_slug()`, `.example` pattern
- W3 (renumbered as W4 in spec): Clarified execution model, added content definitions
- W4 (renumbered as W5 in spec): NTFS safety, generated_by tag
- W5 (renumbered as W6 in spec): Portable find, session timestamp
- No structural changes to work unit dependencies
