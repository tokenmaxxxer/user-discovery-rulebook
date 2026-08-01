#!/usr/bin/env bash
# Runs every gate test suite plus the gate-lib compliance check. Ship-time
# gate for issue-10 (gate A+ upgrade): this must exit 0.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
rc=0
for suite in \
  "$HERE/run-proposal-norm-gate-tests.sh" \
  "$HERE/run-hypothesis-order-gate-tests.sh" \
  "$HERE/run-evidence-tagging-gate-tests.sh" \
  "$HERE/run-saturation-gate-tests.sh" \
  "$HERE/run-gate-lib-compliance-tests.sh"; do
  echo "== $(basename "$suite") =="
  bash "$suite" || rc=1
  echo
done
exit "$rc"
