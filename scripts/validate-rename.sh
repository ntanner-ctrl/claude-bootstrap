#!/usr/bin/env bash
# Validates that no stale /plan or /plans command references remain after rename.
# Excludes: .claude/plans/ paths, --plan flags, English noun usage, blueprint-v2 plan artifacts.
#
# Exit 0 = PASS (no violations)
# Exit 1 = FAIL (stale references found)
#
# Usage: bash scripts/validate-rename.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

# Search for stale /plan command references in source files
# Exclude: plan artifacts, blueprint-v2 spec, git directory, node_modules
VIOLATIONS=$(grep -rn --include='*.md' --include='*.sh' '/plan\b' \
    commands/ hooks/ docs/ README.md templates/ install.sh 2>/dev/null \
  | grep -v '\.claude/plans/' \
  | grep -v '\-\-plan' \
  | grep -v 'plan context' \
  | grep -v 'plan-context' \
  | grep -v 'planName' \
  | grep -v 'execution plan' \
  | grep -v '/blueprint' \
  | grep -v 'validate-rename' \
  | grep -v 'plan\.md.*Rename' \
  | grep -v '# Archive completed plan' \
  | grep -v 'spec\.diff\.md' \
  || true)

if [ -n "$VIOLATIONS" ]; then
    echo "FAIL: Found stale /plan command references:"
    echo ""
    echo "$VIOLATIONS"
    echo ""
    echo "Total violations: $(echo "$VIOLATIONS" | wc -l)"
    exit 1
fi

echo "PASS: No stale command references found."
exit 0
