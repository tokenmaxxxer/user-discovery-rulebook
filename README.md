# user-discovery-rulebook

Rulebook for the `user-discovery` role (contract v3 role-handoff protocol), split off
per `docs/issue-160/proposals/role-taxonomy.md`'s round-4 promotion and
generated as skeleton scaffolding by issue-167.

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

## Layout

- `user-discovery/.claude-plugin/plugin.json` — plugin manifest
- `user-discovery/hooks/hooks.json` — SessionStart + PreToolUse wiring
- `user-discovery/hooks/directive.sh` — SessionStart role directive
- `user-discovery/hooks/record-fields-gate.sh` — this role's record required-field gate
- `user-discovery/hooks/trailer-gate.sh` — commit `Subject: issue-<n>` trailer gate
- `user-discovery/hooks/handbook-trigger-gate.sh` — s21 handbook-sync gate
- `user-discovery/agents/warrant-hunter.md` — rotating-stance hunt agent
- `docs/specs/approvers.md` — Approve-authority allowlist (see below)

This is scaffolding, not a finished rulebook: fill in doctrine detail,
handoff enforcement, and any role-specific progress gate before treating
it as load-bearing.
