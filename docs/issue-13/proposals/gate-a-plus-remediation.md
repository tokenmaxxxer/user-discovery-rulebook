# Proposal — issue-13 gate A+ 최종 마감 remediation (phase 1)

Status: PROPOSED. Awaiting approvers.md APPROVE per contract v3 s19. No
execution work in this document or commit.

## Basis
Survey: docs/issue-13/reports/user-discovery/current-state-survey.md.
All fixes below are conservative ports of already-landed, already-reviewed
core canon (core#75) — no new design invented, matching every gate/test
shape 1:1 against the reference implementation in `tokenmaxxxer-core`
(`hooks/lib/gate-lib.sh`, `hooks/tests/compliance-check.sh`,
`hooks/tests/run-gate-lib-tests.sh`, `hooks/lib/gate-lib.py`).

## Fix 1 — source guard on all 5 gate/sync scripts
Replace the unguarded `source`/`.` of `gate-lib.sh` in:
- `user-discovery-hypothesis-order/hooks/hypothesis-order-gate.sh`
- `user-discovery-hypothesis-order/hooks/hypothesis-order-state-sync.sh`
- `user-discovery-saturation/hooks/saturation-gate.sh`
- `user-discovery-proposal-norm/hooks/proposal-norm-gate.sh`
- `user-discovery-evidence-tagging/hooks/evidence-tagging-gate.sh`

with the exact core-canon guarded form (mirroring `hooks/approval-gate.sh:38`):
```sh
. "$GATE_LIB" || { echo "<script-name>.sh: cannot source gate-lib.sh" >&2; exit 2; }
```
so a missing/broken core hard-denies (exit 2) instead of exiting 127
unguarded and being misread as an inert kill-switch-off state.

## Fix 2 — port the compliance-check detector
Extend `tests/run-gate-lib-compliance-tests.sh` with the same grep rule as
core's `hooks/tests/compliance-check.sh` (~L51-60): flag any `gate-lib.sh"`
source line with no trailing `||` guard, across all 5 plugin gate/sync
scripts. This closes the loop so Fix 1's regression is caught mechanically,
not just by this one-time remediation.

## Fix 3 — complete the mandatory 7-group test harness on all 4 enforcement suites
Not just hypothesis-order — the survey found groups missing across
`run-hypothesis-order-gate-tests.sh`, `run-saturation-gate-tests.sh`,
`run-proposal-norm-gate-tests.sh`, and `run-evidence-tagging-gate-tests.sh`.
Bring each to core's 7-group shape (`replace_all-edit`, `multiedit-replace_all`,
`malformed-json`, `kill-switch`, `absolute-path`, `bash-write-coverage`,
`missing-core`):
- add malformed-JSON deny cases where absent, mirroring the existing pattern
  in `run-proposal-norm-gate-tests.sh:61-71` / `run-evidence-tagging-gate-tests.sh:126-136`
- add a kill-switch **dynamic** case per suite: an unrecognized/garbage
  kill-switch value must leave the gate active (deny), not just the existing
  static on/off cases — mirroring `run-saturation-gate-tests.sh:77-79`
- add a missing-core case per suite, mirroring core's group-7 block
  (`run-gate-lib-tests.sh` ~L230-241): point `CLAUDE_PLUGIN_ROOT_CORE` at a
  nonexistent path, assert deny/exit 2 — this is also the direct
  correctness check on Fix 1.
- port core's `groups_seen` / "MANDATORY GROUP MISSING" completeness loop
  into each suite (or a shared harness helper) so a future dropped group
  fails the suite instead of silently shrinking coverage again.
- port the `gate_bash_write_targets` sh/py parity assertion pattern from
  `run-gate-lib-tests.sh` to the plugin suites that carry a Bash-write-target
  gate path, using core's `hooks/lib/gate-lib.py` function as reference.

## Fix 4 — hooks.json / gate-code tool-coverage parity
For all 4 enforcement plugins (hypothesis-order, saturation, proposal-norm,
evidence-tagging): the gate code branches on
`Write|Edit|MultiEdit|NotebookEdit`, but `hooks.json`'s PreToolUse matcher is
`Write|Edit|MultiEdit|Bash`. Resolve per-gate, not by blanket union:
- gates whose logic only inspects file-write payloads (Write/Edit/MultiEdit/
  NotebookEdit) → correct the matcher to
  `"Write|Edit|MultiEdit|NotebookEdit"`, dropping `Bash` (no bash-target
  branch exists in that gate's code, so claiming Bash coverage is false
  advertising) — confirm per gate by re-reading its tool-dispatch branch
  before dropping Bash, in case a gate does have an untested bash path.
- gates that do carry a `gate_bash_write_targets`-style bash-target check →
  keep `Bash` in the matcher and add the NotebookEdit branch/coverage that's
  currently dead code, so the code path becomes reachable and testable.
This requires reading each of the 4 gate scripts' full dispatch logic (not
just the survey's line hits) before deciding matcher content per plugin —
deferred to phase 2 execution, not decided here, to avoid guessing.

## Fix 5 — hard-error ghost-file / stale-role-name guard
No live defect was found (all README/manifest file references resolve, no
stale role-name strings present), but the issue requires the *absence* to be
enforced, not just currently true. Add a lightweight check script (analog of
core's `stub-check.sh` / canon-manifest mechanism, scoped down to what this
repo needs — no need to import core's full stub-check machinery) that:
- greps all `README.md` and `.claude-plugin/*.json` / plugin manifest files
  in this repo for referenced file paths and hard-fails if any path doesn't
  exist on disk
- hard-fails on a maintained deny-list of retired role-name strings (to be
  populated from this repo's own history — old names this plugin set used
  before its current 5-plugin structure), so a future regression is caught
  instead of relying on a clean snapshot.
Wire it into `tests/run-gate-lib-compliance-tests.sh` (or a sibling script
run by the same suite entrypoint) so "green suite" already implies this
check passed, satisfying the issue's requirement 3 (green + compliance-check
recorded) without a separate manual step.

## Delivery record requirement (issue req. 3)
Phase 2 must record, in `docs/issue-13/reports/user-discovery.md`: full
suite pass output (all 4 plugins x 7 groups, including the new missing-core
cases), and the compliance-check pass output (Fix 2 + Fix 5 checks), as the
evidence artifact — not just a claim of green.

## Out of scope for this proposal
- Redesigning gate-lib itself — this is a conformance port, not new gate
  logic.
- on-the-record#182 — already consumed correctly in this repo per survey;
  no action item.
- CLAUDE_PLUGIN_ROOT_CORE injection mechanism itself — lives in
  on-the-record repo, out of this repo's tree.

## Explicitly not an approval
Per contract v3 s19, phase 2 (actual execution of fixes 1-5) opens only on
an approvers.md APPROVE. This document proposes; it does not execute.
