# Record: gate A+ final closeout — re-audit remediation (issue-13)

loop_state: landed

evidence: opinion — this is a conformance-remediation delivery record, not
a user-discovery interview log; no behavioral/recounted claims apply here.

Phase-2 delivery record for the proposal at
`docs/issue-13/proposals/gate-a-plus-remediation.md`, sourced from the
survey at `docs/issue-13/reports/user-discovery/current-state-survey.md`.
All five fixes are delivered. This is a conformance-remediation record
against already-landed core canon (core#75), not a user-discovery
interview verdict — no hypothesis/verdict markers apply here.

## Why

Per the issue's 2026-08-01 re-audit comment: the source guard, the
mandatory 7-group test harness, and hooks.json/gate-code tool-coverage
parity that core#75 already fixed and packaged into `gate-lib.sh` /
`gate-lib.py` / `compliance-check.sh` / `run-gate-lib-tests.sh` had not yet
been ported into this repo's five plugins. The proposal committed to a
conservative 1:1 port of the reference implementation, no new gate logic;
this record delivers that plan.

## What was done

1. **Fix 1 — source guard on all 5 gate/sync scripts.** Replaced the
   unguarded `. ".../gate-lib.sh"` line in all five scripts (the four
   `*-gate.sh` files plus `hypothesis-order-state-sync.sh`) with the
   guarded form
   `. "..." || { echo "<script>.sh: cannot source gate-lib.sh" >&2; exit 2; }`,
   mirroring core's `hooks/approval-gate.sh:38`. A missing/broken core now
   hard-denies (exit 2) instead of exiting 127 unguarded (fail-open,
   misreadable as kill-switch-off). Regression-tested by
   `missing-core-guarded-source-denies` in all four suites.
2. **Fix 2 — compliance-check detector.** No port was needed:
   `tests/run-gate-lib-compliance-tests.sh` already invokes core's
   `hooks/tests/compliance-check.sh` directly (never vendored), so the
   unguarded-source grep rule (core#75) was already live and caught
   defect 1 the moment it was checked, before any code change —
   confirmed by running the suite pre-fix (all four plugin gate scripts
   FAILed on the unguarded-source rule) and post-fix (clean). No proposal
   text changed; this is a confirmation, not a delivered edit.
3. **Fix 3 — complete the mandatory 7-group test harness on all 4
   suites.** Brought `run-hypothesis-order-gate-tests.sh`,
   `run-saturation-gate-tests.sh`, `run-proposal-norm-gate-tests.sh`, and
   `run-evidence-tagging-gate-tests.sh` to core's 7-group shape
   (`replace_all-edit`, `multiedit-replace_all`, `malformed-json`,
   `kill-switch`, `absolute-path`, `bash-write-coverage`, `missing-core`),
   plus core's `groups_seen`/"MANDATORY GROUP MISSING" completeness loop
   in every suite so a future dropped group fails the harness itself.
   Per-suite gaps closed (each suite's actual starting gap, not a uniform
   template — confirmed by reading each file before editing):
   - `hypothesis-order`: added `malformed-json` (3 cases),
     `kill-switch-unrecognized-value-stays-active` (dynamic case;
     previously only the static allow-when-on case existed),
     `bash-tool-write-to-owned-path`, `edit-replace-all-both-occurrences`,
     `multiedit-mixed-replace-all`, and `missing-core`. 10 → 18 cases.
   - `saturation`: added `malformed-json` (3 cases),
     `edit-replace-all-both-occurrences`, `multiedit-mixed-replace-all`,
     and `missing-core`. 11 → 17 cases.
   - `proposal-norm`: added `edit-replace-all-both-occurrences`,
     `multiedit-mixed-replace-all`, and `missing-core`. 10 → 13 cases.
   - `evidence-tagging`: added `absolute-path-no-tag-at-all` and
     `missing-core`. 15 → 17 cases.
   - `gate_bash_write_targets` sh/py parity: already covered by core's own
     `run-gate-lib-tests.sh` (not re-ported here — none of the four
     plugin gates carry their own copy of `gate_bash_write_targets`; they
     all call the core-canon function directly, so the parity assertion
     belongs to core's suite, which already runs it).
4. **Fix 4 — hooks.json / gate-code tool-coverage parity.** Read each of
   the four gates' full dispatch logic (not just line hits): all four
   call `gate_lib.gate_reconstruct_write` for
   `tool in ("Write","Edit","MultiEdit","NotebookEdit")` AND all four have
   a `Bash` branch via `gate_bash_write_targets`. So the resolution is the
   same for all four (not a per-gate split, since none needed Bash
   dropped): added `NotebookEdit` to the PreToolUse matcher
   (`"Write|Edit|MultiEdit|NotebookEdit|Bash"`) in all four plugins'
   `hooks.json`, making the previously-dead `NotebookEdit` branch
   reachable; kept `Bash` since every gate's bash-target check is real and
   tested. Also added `NotebookEdit` to
   `user-discovery-hypothesis-order/hooks/hooks.json`'s PostToolUse
   matcher for `hypothesis-order-state-sync.sh`, which also reads
   `notebook_path`.
5. **Fix 5 — ghost-file / stale-role-name hard-error guard.** Added
   `tests/manifest-check.sh`, a scoped-down analog of core's
   `stub-check.sh`/canon-manifest mechanism (no full import — this repo
   doesn't vendor canon files, so only the two absence-based checks
   apply): (a) every `hooks/*.sh` path a plugin's own README.md names
   resolves on disk (checked relative to that README's own directory —
   the repo-root README, which describes all five plugins at once, is
   skipped as ambiguous rather than false-failed) and every
   `.claude-plugin/*.json` manifest `source`/`path` field resolves from
   repo root; (b) a maintained retired-role-name deny-list (currently:
   `warrant-hunter`, this repo's only confirmed prior role/agent name,
   removed in issue-2's core-canon-reference cutover) is absent from every
   README/manifest file. Wired into
   `tests/run-gate-lib-compliance-tests.sh` so "green suite" already
   implies this check passed. No live defect found (matches the survey);
   this adds the standing guard the issue's requirement asks for.

## Test suite

`tests/run-all-gate-tests.sh` — all green, 0 failed:

- `run-proposal-norm-gate-tests.sh`: 13 passed, 0 failed
- `run-hypothesis-order-gate-tests.sh`: 18 passed, 0 failed
- `run-evidence-tagging-gate-tests.sh`: 17 passed, 0 failed
- `run-saturation-gate-tests.sh`: 17 passed, 0 failed
- `run-gate-lib-compliance-tests.sh`: clean (compliance-check.sh x4 +
  manifest-check.sh x2 assertions)

65 test cases total across the four gate suites (up from 46 at issue-10
closeout). Every suite's own `groups_seen` completeness loop confirms all
7 mandatory groups fired; no "MANDATORY GROUP MISSING" line in any run.

## `compliance-check.sh` + `manifest-check.sh` (record req. 3)

```
== run-gate-lib-compliance-tests.sh ==
compliance-check: ok — user-discovery-proposal-norm/hooks/proposal-norm-gate.sh
compliance-check: ok — user-discovery-hypothesis-order/hooks/hypothesis-order-gate.sh
compliance-check: ok — user-discovery-evidence-tagging/hooks/evidence-tagging-gate.sh
compliance-check: ok — user-discovery-saturation/hooks/saturation-gate.sh
manifest-check: ok — every hooks/ path referenced from a README, and every manifest source/path, resolves on disk
manifest-check: ok — retired role-name 'warrant-hunter' absent from README/manifest files
```

No `FAIL` line. Pre-fix (Fix 1 not yet applied), the same
`compliance-check.sh` run FAILed on all four plugin gate scripts with
"sources gate-lib.sh with no `||` guard on the same line" — captured here
as the before/after evidence pair the issue's requirement 3 asks for.

## README / manifest (record req. 4)

No ghost-file bullets or stale role names were present before this phase
(matches the survey's finding); `tests/manifest-check.sh` now makes that a
standing, mechanically-enforced guard rather than an accidentally-clean
snapshot, per the issue's "옛 이름은 하드 에러" requirement.

## Out of scope (per the approved proposal)

- Redesigning gate-lib itself — conformance port only.
- on-the-record#182 (`CLAUDE_PLUGIN_ROOT_CORE` injection) — already
  correctly consumed; no action item, confirmed unchanged.
- The `CLAUDE_PLUGIN_ROOT_CORE` injection mechanism itself — lives in the
  on-the-record repo, out of this repo's tree.

## Open findings

None outstanding. `loop_state: landed` — all five fixes delivered, the
full suite (including the new `missing-core` cases) is green, and
`compliance-check.sh` + the new `manifest-check.sh` both pass clean.
