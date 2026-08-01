#!/usr/bin/env bash
# Runs core/hooks/tests/compliance-check.sh (issue-72 gate-house standard)
# against each of the four gate-owning plugin hooks/ directories in this
# repo, per docs/handbooks/gate-house-standard.md's migration checklist
# step 4. A clean run here is the ship-time evidence this repo's gates
# migrated onto gate-lib.sh/gate-lib.py rather than re-deriving their own
# kill-switch/replace_all logic.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$HERE/resolve-core.sh"

[ -n "${CLAUDE_PLUGIN_ROOT_CORE:-}" ] || {
  echo "run-gate-lib-compliance-tests: could not resolve CLAUDE_PLUGIN_ROOT_CORE (no local core checkout, no network); skipping" >&2
  exit 0
}

COMPLIANCE_CHECK="$CLAUDE_PLUGIN_ROOT_CORE/hooks/tests/compliance-check.sh"
[ -f "$COMPLIANCE_CHECK" ] || {
  echo "run-gate-lib-compliance-tests: $COMPLIANCE_CHECK not found; skipping" >&2
  exit 0
}

rc=0
for dir in \
  "$HERE/../user-discovery-proposal-norm/hooks" \
  "$HERE/../user-discovery-hypothesis-order/hooks" \
  "$HERE/../user-discovery-evidence-tagging/hooks" \
  "$HERE/../user-discovery-saturation/hooks"; do
  bash "$COMPLIANCE_CHECK" "$dir" || rc=1
done

exit "$rc"
