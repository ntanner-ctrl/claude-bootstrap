---
description: Use when you want to re-assess confidence in existing vault findings through Empirica's calibration lens. Surfaces stale, contradicted, or low-confidence knowledge for verification.
---

# Review Findings

Periodic re-assessment of Obsidian vault findings through Empirica's epistemic calibration lens. Reads findings from the vault, compares them against current project state, and updates confidence metadata. This is the "is our data still true?" workflow.

## Why This Exists

Findings decay. Code changes, assumptions get invalidated, patterns evolve. Without periodic review, the vault accumulates stale knowledge that misleads future sessions. This command applies Empirica's calibration data to prioritize which findings most need re-verification, then walks through them.

## Process

### Step 1: Source Vault Config

Use the Bash tool to source vault-config.sh and extract config values:

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo "VAULT_ENABLED=$VAULT_ENABLED" && echo "VAULT_PATH=$VAULT_PATH"
```

If vault is unavailable, stop with:
```
Vault not available. /review-findings requires an accessible Obsidian vault.
```

### Step 2: Check for Active Empirica Session

```bash
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
cat "$GIT_ROOT/.empirica/active_session" 2>/dev/null || echo "NO_SESSION"
```

If no session, note: "No Empirica session — review will proceed without calibration data."

### Step 3: Gather Findings

1. Get project name: `basename $(git rev-parse --show-toplevel 2>/dev/null)`
2. Use Grep tool to search `$VAULT_PATH/Engineering/Findings/` for notes with `project: PROJECT_NAME`
3. For each matching file, read its frontmatter to extract:
   - `empirica_confidence` (if present)
   - `empirica_status` (if present)
   - `empirica_assessed` (if present)
   - `date` (creation date)
   - Title and brief description

### Step 4: Triage by Review Priority

Sort findings into priority buckets:

| Priority | Criteria | Why |
|----------|----------|-----|
| **Critical** | `empirica_status: contradicted` | Known to be wrong — needs correction or deletion |
| **High** | `empirica_status: stale` OR `empirica_assessed` > 30 days ago | Knowledge decay — may no longer be true |
| **Medium** | `empirica_confidence` < 0.6 | Low confidence — was uncertain when captured |
| **Low** | No `empirica_*` fields at all | Never assessed — needs initial confidence tagging |
| **Healthy** | `empirica_status: confirmed` AND `empirica_confidence` >= 0.7 AND assessed < 30 days | Good standing — skip unless user requests full review |

If Empirica session is active, query `mcp__empirica__get_calibration_report` and apply calibration adjustments:
- If the user historically overestimates confidence (calibration shows negative adjustment for `know`), discount findings proportionally
- Note: "Calibration adjustment: your confidence estimates tend to be X% high in this domain"

### Step 5: Present Dashboard

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  FINDINGS REVIEW: PROJECT_NAME
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Total: N findings
  Calibration: [adjustment note or "no Empirica session"]

  🔴 Critical (contradicted):     N
  🟠 High (stale):                N
  🟡 Medium (low confidence):     N
  ⚪ Low (unassessed):            N
  🟢 Healthy:                     N

  Reviewing N findings (Critical + High + Medium + Low):

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 6: Walk Through Each Finding

For each non-healthy finding (Critical first, then High, Medium, Low):

1. **Show the finding**: Read and display the full vault note
2. **Show current project context**: Check if the finding is still relevant by:
   - Searching the codebase for related code (Grep for key terms from the finding)
   - Checking recent git history for changes to related files
3. **Assess**: Based on current evidence, propose an updated confidence and status:
   - "This finding appears **still valid** — code at X:Y confirms it. Proposed: confirmed, 0.85"
   - "This finding may be **outdated** — the code it references was refactored in commit abc. Proposed: stale, 0.4"
   - "This finding is **contradicted** — current behavior is the opposite. Proposed: contradicted, 0.1"
4. **Ask for user verdict**:
   ```
   Verdict for "[finding title]":
     [1] Confirm (mark as confirmed, update confidence)
     [2] Contradict (mark as contradicted, add note)
     [3] Stale (needs deeper investigation later)
     [4] Skip (leave as-is for now)
     [5] Delete (remove from vault entirely)
   ```

### Step 7: Apply Updates

For each finding with a verdict:

1. **Update vault note frontmatter** using the Edit tool:
   - `empirica_confidence`: Updated value
   - `empirica_assessed`: Today's date
   - `empirica_status`: From verdict (confirmed/contradicted/stale)
   - `empirica_session`: Current session ID

2. **If contradicted**: Add a note to the Implications section:
   ```markdown
   > ⚠️ Contradicted in session [[SESSION_LINK]] on YYYY-MM-DD — [brief reason]
   ```

3. **If deleted**: Remove the vault note file. Log to Empirica as a dead-end:
   - Call `mcp__empirica__deadend_log` with reason for deletion

4. **Log to Empirica** (if session active): Call `mcp__empirica__finding_log` for each re-assessed finding with updated confidence

### Step 8: Present Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Reviewed: N findings
  Confirmed:    N (updated confidence)
  Contradicted: N (marked with reason)
  Stale:        N (flagged for later)
  Deleted:      N
  Skipped:      N

  Vault knowledge health: N/M findings in good standing (X%)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Arguments

```
/review-findings                    # Review all findings for current project
/review-findings --all              # Review ALL projects in vault
/review-findings --critical-only    # Only Critical + High priority
/review-findings --project NAME     # Review findings for a specific project
```

## Notes

- This command is interactive — each finding gets a user verdict
- For large vaults, use `--critical-only` to focus on the most urgent findings
- Calibration data improves with each review cycle (Empirica tracks the deltas)
- The `/start` command surfaces stale findings automatically — this command does the deeper review
- Pair with `/collect-insights` to ensure all findings are in vault before reviewing
- All operations are fail-soft — if Empirica is unavailable, review still works (just without calibration)
