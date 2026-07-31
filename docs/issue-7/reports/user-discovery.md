loop_state: landed

## What was done

Implemented the approved plugin-set proposal
(`docs/issue-7/proposals/plugin-enforcement-hardening.md`, approved via
`APPROVE issue-7/user-discovery` with the phase-2 correction "포화 기준
~6을 GBJ 원문의 ~12로 정정") as four independent, self-contained Claude
Code plugins, each with its own `.claude-plugin/plugin.json`,
`hooks/hooks.json`, gate script, README, kill switch, and repo-root test
runner — mirroring the shape `core`'s `freelunch`/`scout` plugins already
establish (read directly from `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core`,
nothing copied):

- `user-discovery-proposal-norm/` — phase-1 survey-first norm. Gates
  `docs/issue-<n>/proposals/*.md`; denies a proposal with no cited
  `docs/issue-<n>/reports/user-discovery/` survey path.
  `tests/run-proposal-norm-gate-tests.sh`: 4/4 passing.
- `user-discovery-hypothesis-order/` — Customer Development ordering
  discipline. Gates `docs/issue-<n>/reports/user-discovery.md`; denies a
  verdict marker while no evidence-strength tag has yet been logged
  (branch-durable state at
  `docs/issue-<n>/reports/user-discovery/.state.json`).
  `tests/run-hypothesis-order-gate-tests.sh`: 5/5 passing.
- `user-discovery-evidence-tagging/` — Mom Test tagging discipline.
  Same gate target; denies a record write with no
  `behavioral`/`recounted`/`opinion` tag. `tests/run-evidence-tagging-gate-tests.sh`:
  7/7 passing.
- `user-discovery-saturation/` — prevalence + contradiction +
  Guest/Bunce/Johnson (2006) saturation discipline (~12 interviews,
  corrected from an earlier ~6 draft per the approver's phase-2 comment).
  Same gate target; denies a verdict with no stated prevalence, and,
  when contradicting evidence is named in the content, one with no
  residual/contradiction acknowledgment. `tests/run-saturation-gate-tests.sh`:
  8/8 passing.

All four gates share the frozen contract read directly from
`pricing-rulebook/pricing/hooks/methodology-gate.sh` (fail-closed
trap-at-top, CLAUDE_PROJECT_DIR/git root resolution, Write/Edit/MultiEdit
content reconstruction, `<role>: refused — ...` deny messages) and the
test-runner shape read directly from
`implementation-rulebook/tests/run-gate-tests.sh` (subprocess-invoked
gate, JSON payload on stdin, exit-code assertion). All 24 gate tests
across the four plugins pass. Registered all four as separate entries in
`.claude-plugin/marketplace.json`, alongside the existing `user-discovery`
role plugin. `docs/handbooks/user-discovery/per-interview-checklist.md`
created, holding the two remaining non-gateable procedural rules (no-pitch
timing; the saturation-count checklist trigger) that the proposal
explicitly named as content-judgment rather than substring-checkable.
`README.md` updated with the phase-1/phase-2 plugin-composition mapping
and per-plugin install lines.

## Why

The prior draft (commit 10d997d) proposed one hardened role stub; the
human approver's `요구 정정` comment on issue-7 required restructuring
into an independent plugin set instead, mirroring `core`'s
`freelunch`/`scout` pattern, with phase-1/phase-2 norms each defined as an
explicit plugin composition rather than left implicit in role-stub prose.
This delivery implements that corrected structure, not the original
single-gate draft.

## What did not work

One background build worker (evidence-tagging) hit a transient upstream
API rate-limit mid-run before writing any files; re-dispatched with the
same brief and it completed cleanly on the second attempt with no other
changes needed.

## Open findings

- The saturation gate's contradiction-language heuristic (proposal §4's
  named gap) is a simple substring heuristic, not calibrated against a
  real first-draft record — flagged in
  `user-discovery-saturation/README.md` as needing recalibration once a
  real interview round produces one.
- The `insufficient-evidence` third verdict state (proposal's open
  decision, §"Open decision for phase-2/human review") was implemented
  as valid in `user-discovery-hypothesis-order` and
  `user-discovery-saturation`'s marker lists, defaulting to yes per the
  proposal's own default — this is a live decision point should a human
  reviewer want it removed.
- Packaging mechanics (proposal §0's gap: separate plugin dirs vs. one
  dir with sub-gates) was resolved as separate plugin directories, per
  the proposal's own recommendation to match `core`'s
  `freelunch`/`scout` packaging.
