# user-discovery-rulebook

Rulebook for the `user-discovery` role (contract v3 role-handoff protocol), split off
per `docs/issue-160/proposals/role-taxonomy.md`'s round-4 promotion.

- **decides**: 이 문제가 실제 사용자의 고통인가
- **use_when**: 가설 검증을 위해 사용자 인터뷰가 필요할 때
- **produces**: interview script, per-interview evidence log, pain-confirmed|not-confirmed verdict
- **write_scope**: []
- **hand-off**: 검증된 가설을 스펙화하면 → requirements-engineering

## Install

```
claude plugin marketplace add tokenmaxxxer/user-discovery-rulebook
claude plugin install user-discovery
claude plugin install user-discovery-proposal-norm
claude plugin install user-discovery-hypothesis-order
claude plugin install user-discovery-evidence-tagging
claude plugin install user-discovery-saturation
```

## Methodology plugin set (issue-7)

Each adopted user-discovery methodology facet (issue-1
`docs/issue-1/proposals/user-discovery-methodology.md`) ships as its own
self-contained plugin — own manifest, own gate, own tests, own kill
switch — rather than one hardened role stub. See
`docs/issue-7/proposals/plugin-enforcement-hardening.md` for the full
roster rationale.

- **Phase-1 (기획서) norm** = `user-discovery-proposal-norm` alone: gates
  `docs/issue-<n>/proposals/*.md`, denies a proposal with no cited
  `docs/issue-<n>/reports/user-discovery/` survey path.
- **Phase-2 (산출물) norm** = the composition of `user-discovery-hypothesis-order`
  + `user-discovery-evidence-tagging` + `user-discovery-saturation`, all
  three independently gating `docs/issue-<n>/reports/user-discovery.md` —
  a phase-2 record must satisfy all three to be written at all:
  - `user-discovery-hypothesis-order` — denies a verdict marker
    (`pain-confirmed`/`not-confirmed`/`insufficient-evidence`) while no
    evidence-strength tag has been logged yet (branch-durable state under
    `docs/issue-<n>/reports/user-discovery/.state.json`).
  - `user-discovery-evidence-tagging` — denies a record write with no
    `behavioral`/`recounted`/`opinion` tag present.
  - `user-discovery-saturation` — denies a verdict with no stated
    prevalence (N of M), and, when contradicting evidence is named,
    denies one with no residual/contradiction acknowledgment.

Each plugin is independently toggleable via its own kill switch
(`USER_DISCOVERY_<PLUGIN>_GATE_OFF=1`) and registered as its own entry in
`.claude-plugin/marketplace.json`.

| Plugin | Kill switch |
|---|---|
| `user-discovery-proposal-norm` | `USER_DISCOVERY_PROPOSAL_NORM_GATE_OFF` |
| `user-discovery-hypothesis-order` | `USER_DISCOVERY_HYPOTHESIS_ORDER_GATE_OFF` |
| `user-discovery-evidence-tagging` | `USER_DISCOVERY_EVIDENCE_TAGGING_GATE_OFF` |
| `user-discovery-saturation` | `USER_DISCOVERY_SATURATION_GATE_OFF` |

An unset, empty, or unrecognized kill-switch value all mean "stay active";
only a recognized on-spelling (`1`/`true`/`yes`/`on`, case-insensitive)
disables a gate (see "Gate implementation" below).

## Layout

- `user-discovery/.claude-plugin/plugin.json` — plugin manifest
- `user-discovery/hooks/hooks.json` — SessionStart wiring
- `user-discovery/hooks/directive.sh` — SessionStart role directive
- `user-discovery/hooks/lib/_semantic.py` — shared structural marker-matching
  helper (hypothesis/evidence/verdict tags), used by all four gates below
- `user-discovery-proposal-norm/hooks/proposal-norm-gate.sh` — phase-1
  survey-citation gate
- `user-discovery-hypothesis-order/hooks/hypothesis-order-gate.sh` +
  `hooks/hypothesis-order-state-sync.sh` — Customer Development ordering
  gate (PreToolUse) and its PostToolUse state-sync counterpart
- `user-discovery-evidence-tagging/hooks/evidence-tagging-gate.sh` —
  evidence-strength tagging gate
- `user-discovery-saturation/hooks/saturation-gate.sh` — verdict
  prevalence/residual gate
- `tests/` — one real-subprocess test suite per gate plus
  `run-gate-lib-compliance-tests.sh` and `run-all-gate-tests.sh`
- `docs/specs/approvers.md` — Approve-authority allowlist (see below)

## Gate implementation (issue-72 / issue-10)

All four gates source `core/hooks/lib/gate-lib.sh` (+ `gate-lib.py`) —
reference only, never vendored, per
`docs/handbooks/canon-scripts.md` — for the fail-closed trap, kill-switch
convention, stderr-only deny protocol, malformed-JSON handling, absolute/
relative/`./`-prefixed path normalization, and full
Write/Edit/MultiEdit/NotebookEdit content reconstruction (`replace_all`
honored per edit). See `docs/handbooks/gate-house-standard.md` for what the
shared library provides and `docs/issue-10/proposals/gate-a-plus-upgrade.md`
for this repo's adoption rationale and semantic-check redesign (substring
match replaced by structural — labeled-field/heading/list-item/bracket-tag
— matching, closing the `'h1'`-inside-`'<h1>'` and bare-`'opinion'`-in-prose
false positives). `tests/run-gate-lib-compliance-tests.sh` runs
`compliance-check.sh` against all four gates' `hooks/` directories.
