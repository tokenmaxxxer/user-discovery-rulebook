# Current-state survey — issue-13 gate A+ re-audit remediation

## Scope
Re-audit residual defects on the user-discovery plugin set (`user-discovery`,
`user-discovery-proposal-norm`, `user-discovery-saturation`,
`user-discovery-hypothesis-order`, `user-discovery-evidence-tagging`), against
core canon landed in core#75 (`52bdc15`) and on-the-record#182.

## Scout skip record
Skipped. Spec condition 2 applies: the issue is a conformance remediation
against an already-frozen external canon (core#75's gate-lib guard, missing-core
test group, compliance detector) — there is no open design decision to steer
with external product research; the correct shape is dictated by the core
reference implementation itself, surveyed below.

## Preconditions verified landed
- core#75 (`52bdc15` deliver, `24eb5ed` propose) confirmed on core main
  (tokenmaxxxer/tokenmaxxxer-core), containing:
  - source-guard doc-comment mandate in `hooks/lib/gate-lib.sh`, applied to all
    core gates, e.g. `hooks/approval-gate.sh:38`
    (`. ".../gate-lib.sh" || { echo "<gate>.sh: cannot source gate-lib.sh" >&2; exit 2; }`)
  - compliance-check detector in `hooks/tests/compliance-check.sh` (~L51-60):
    greps for `gate-lib\.sh"$` with no trailing `||` guard and fails the check.
  - mandatory 7-group test harness in `hooks/tests/run-gate-lib-tests.sh`:
    groups `replace_all-edit multiedit-replace_all malformed-json kill-switch
    absolute-path bash-write-coverage missing-core`; missing-core group
    (~L230-241) points `CLAUDE_PLUGIN_ROOT_CORE` at a nonexistent path and
    asserts deny/exit 2.
  - `gate_bash_write_targets` ported to `hooks/lib/gate-lib.py`, with an
    sh/py parity assertion in `run-gate-lib-tests.sh`.
- on-the-record#182 (CLAUDE_PLUGIN_ROOT_CORE injection): already consumed in
  this repo — present in all 5 gate/sync scripts' source lines and in
  `tests/resolve-core.sh` / `tests/run-gate-lib-compliance-tests.sh`. Nothing
  to remediate on this item.

## Defects found (this repo, against core canon)

1. **Source guard not applied.** All 5 gate/sync scripts source
   `gate-lib.sh` unguarded — a missing/broken core would exit 127 (fail-open,
   misreadable as kill-switch-off) instead of a hard deny:
   - `user-discovery-hypothesis-order/hooks/hypothesis-order-gate.sh:2`
   - `user-discovery-hypothesis-order/hooks/hypothesis-order-state-sync.sh:2`
   - `user-discovery-saturation/hooks/saturation-gate.sh:2`
   - `user-discovery-proposal-norm/hooks/proposal-norm-gate.sh:2`
   - `user-discovery-evidence-tagging/hooks/evidence-tagging-gate.sh:2`

2. **No compliance-check detector ported.** `tests/run-gate-lib-compliance-tests.sh`
   (32 lines) predates core's unguarded-source grep rule; does not catch
   defect 1.

3. **hypothesis-order suite: 6 of 7 mandatory groups.** Missing:
   - malformed-JSON deny case (present as a pattern in
     `tests/run-proposal-norm-gate-tests.sh:61-71` and
     `tests/run-evidence-tagging-gate-tests.sh:126-136`; absent from
     `tests/run-hypothesis-order-gate-tests.sh`)
   - kill-switch **dynamic** case — unrecognized/garbage kill-switch value
     must still gate active (present in
     `tests/run-saturation-gate-tests.sh:77-79`,
     `tests/run-proposal-norm-gate-tests.sh:39`,
     `tests/run-evidence-tagging-gate-tests.sh:139-140`; hypothesis-order only
     has the static allow-when-on case)
   - missing-core case (core group 7) — absent from **all four** enforcement
     suites (hypothesis-order, saturation, proposal-norm, evidence-tagging),
     not just hypothesis-order.
   - No group-completeness enforcement mechanism (core's `groups_seen` /
     "MANDATORY GROUP MISSING" loop) exists anywhere in this repo's harnesses.

4. **hooks.json / gate-code tool-coverage mismatch, all 4 enforcement plugins.**
   Gate scripts branch on `tool in ("Write","Edit","MultiEdit","NotebookEdit")`
   (e.g. `evidence-tagging-gate.sh:124`, `proposal-norm-gate.sh:118`,
   `saturation-gate.sh:129`, `hypothesis-order-gate.sh:135`), but every
   plugin's `hooks.json` PreToolUse matcher is `"Write|Edit|MultiEdit|Bash"` —
   NotebookEdit is never registered, so that branch is dead, and the matcher
   claims Bash coverage that (for non-bash-write-targets gates) is unused.
   Files: `user-discovery-hypothesis-order/hooks/hooks.json:5`,
   `user-discovery-saturation/hooks/hooks.json:5`,
   `user-discovery-proposal-norm/hooks/hooks.json` (same pattern),
   `user-discovery-evidence-tagging/hooks/hooks.json` (same pattern).

5. **README/manifest ghost-file or stale-role-name check: no defect found,
   but no hard-error mechanism exists.** All READMEs, `.claude-plugin/marketplace.json`,
   and plugin.json files reference only files present on disk; no stale role
   name string was found. However this repo has no analog of core's
   `stub-check.sh` / canon-manifest hard-error mechanism that would *catch*
   such drift automatically — the issue's requirement ("옛 이름은 하드 에러")
   is not yet a standing guard, only an accidentally-clean snapshot.
